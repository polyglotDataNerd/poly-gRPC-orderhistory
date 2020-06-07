package objects

import (
	"context"
	sgutils "github.com/polyglotDataNerd/poly-Go-utils/utils"
	pb "github.com/polyglotDataNerd/poly-gRPC-orderhistory/definiton"
	"github.com/polyglotDataNerd/poly-gRPC-orderhistory/utils"
	"google.golang.org/grpc"
	"io"
)

/* sets client for production use */
type Client interface {
	getUsers() error
	getClient()
}

type ClientProperties struct {
	Users *pb.HistoryResponse
	Host  string
}

func (c *ClientProperties) GetUsers(uuid string) (usererr error) {

	conn, _ := c.getConnection()
	defer conn.Close()
	cli := pb.NewSGHistoryClient(&conn)

	stream, err := cli.GetUserHistory(context.Background(), &pb.HistoryRequest{Gid: uuid})
	if err != nil {
		usererr = err
		sgutils.Error.Fatalln("stream error", usererr)
	}
	users, serr := stream.Recv()
	if serr == io.EOF {
		usererr = serr
		sgutils.Error.Println("Stream Empty", usererr)
	}
	if serr != nil {
		usererr = serr
		sgutils.Error.Printf("%v.GetUser(_) = _, %v", cli, usererr)
	}
	c.Users = users
	return usererr
}

func (c *ClientProperties) getConnection() (grpc.ClientConn, error) {
	//conn, connerr := grpc.Dial(c.Host, grpc.WithInsecure(), grpc.WithUnaryInterceptor(utils.LoggingMiddleWareClient))
	conn, connerr := grpc.Dial(c.Host, grpc.WithInsecure(), grpc.WithUnaryInterceptor(utils.LoggingMiddleWareClient))
	if connerr != nil {
		sgutils.Error.Println("Connection Error", connerr)
	}
	return *conn, connerr
}
