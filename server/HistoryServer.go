package main

import (
	"github.com/gocql/gocql"
	types "github.com/golang/protobuf/ptypes"
	aws "github.com/polyglotDataNerd/poly-Go-utils/aws"
	c "github.com/polyglotDataNerd/poly-Go-utils/database"
	p "github.com/polyglotDataNerd/poly-Go-utils/utils"
	pb "github.com/polyglotDataNerd/poly-gRPC-orderhistory/definiton"
	"github.com/polyglotDataNerd/poly-gRPC-orderhistory/utils"
	"google.golang.org/grpc"
	"google.golang.org/grpc/keepalive"
	"net"
	"sync"
	"time"
)

const (
	port = ":50051"
)

type server struct {
	getServer *pb.SGHistoryServer
}

var (
	wg      sync.WaitGroup
	Session *gocql.Session
)

func init() {
	Props := p.Mutator{
		SetterKeyEnv:    "host",
		SetterValueEnv:  "cassandra.us-east-1.amazonaws.com",
		SetterKeyUser:   "user",
		SetterValueUser: aws.SSMParams("/cassandra/mcs/ServiceUserName", 0),
		SetterKeyPW:     "pw",
		SetterValuePW:   aws.SSMParams("/cassandra/mcs/ServicePassword", 0),
	}
	ClientConfig := c.CQLProps{
		Mutator: Props,
	}
	Client := c.CQL{
		CQLProps: ClientConfig,
		Wg:       wg,
		SSLPath:  "/sg-gRPC-orderhistory/AmazonRootCA1.pem",
		//SSLPath: "/Users/gerardbartolome/.mac-ca-roots",
	}
	/* we want to persist the session once for the server to always connect without closing */
	Session = Client.CassandraSession()
}

func collect(uuid string) *pb.HistoryResponse {

	client := c.CQL{}
	start := time.Now()
	collection := &pb.HistoryResponse{}
	var userorders []*pb.HistoryMap

	resultSet, rerr := client.CassReadOrderHistory("SELECT * FROM sg_cass.order_history where gid ="+"'"+uuid+"'", Session)
	if rerr != nil {
		p.Error.Println(rerr)
	}
	for _, v := range resultSet {
		wg.Add(1)
		go func() {
			defer wg.Done()
			timeConvert, _ := types.TimestampProto(v.OrderDate)
			userorders = append(userorders, &pb.HistoryMap{
				Gid:        v.Gid,
				OrderDate:  timeConvert,
				OrderID:    v.OrderId,
				Entree:     v.Entree,
				CustomerId: v.CustomerID,
			})
		}()
		wg.Wait()
	}
	collection.Collection = userorders
	p.Info.Println("collection response time: ", time.Since(start))
	return collection
}

/*SGID_GetUserServer is the protoc translation of GetUser rpc method in the SGID service defined in the .proto implementation*/
func (s *server) GetUserHistory(request *pb.HistoryRequest, stream pb.SGHistory_GetUserHistoryServer) error {

	p.Info.Println("uuid:", request.Gid)
	streamerr := stream.Send(collect(request.Gid))
	if streamerr != nil {
		p.Error.Println("error on server", streamerr)
		return streamerr
	}
	p.Info.Println("Success Stream Send", request.Gid)
	return nil
}

func main() {
	p.Info.Println("gRPC Server Entry Point")
	listener, err := net.Listen("tcp", port)
	if err != nil {
		p.Error.Fatalf("failed to listen: %v", err)
	}
	p.Info.Println("Starting a new gRPC server")
	orderhistory := grpc.NewServer(grpc.KeepaliveParams(keepalive.ServerParameters{
		MaxConnectionIdle: 5 * time.Minute,
	}), grpc.UnaryInterceptor(utils.LoggingMiddleWareServer))
	pb.RegisterSGHistoryServer(orderhistory, &server{})
	p.Info.Println("gRPC Server Started")
	orderhistory.Serve(listener)
}
