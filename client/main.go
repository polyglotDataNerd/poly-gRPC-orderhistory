package main

import (
	//"encoding/json"
	"fmt"
	"github.com/gin-gonic/gin"
	"github.com/golang/protobuf/proto"
	p "github.com/polyglotDataNerd/poly-Go-utils/utils"
	"github.com/polyglotDataNerd/poly-gRPC-orderhistory/client/objects"
	pb "github.com/polyglotDataNerd/poly-gRPC-orderhistory/definition"
	"net/http"
	"os"
)

func init() {
	gin.SetMode(gin.ReleaseMode)

}
func main() {
	//traceroute -T -p 9092 sg-client.sg.grpc-production
	serverhost := fmt.Sprintf("%s%s%v", os.Args[1], ":", 50051)
	cli := objects.ClientProperties{
		Host: serverhost,
	}
	g := gin.Default()
	g.GET("/gid/:uuid", func(ctx *gin.Context) {
		uuid := ctx.Param("uuid")
		uERR := cli.GetUsers(uuid)
		if uERR != nil {
			ctx.JSON(http.StatusInternalServerError, gin.H{"error": uERR.Error()})
			p.Error.Println("JSON Response ERROR:", gin.H{"error": ctx.Errors.JSON()})
		}
		newCollection := pb.HistoryResponse{}
		jsonArray, jERR := proto.Marshal(cli.Users)
		if jERR != nil {
			ctx.JSON(http.StatusInternalServerError, gin.H{"error": jERR.Error()})
			p.Error.Println("JSON Response ERROR:", gin.H{"error": ctx.Errors.JSON()})
		}
		proto.Unmarshal(jsonArray, &newCollection)
		ctx.JSON(http.StatusOK, gin.H{"result": newCollection.GetCollection()})
	})

	if serr := g.Run(":9092"); serr != nil {
		p.Error.Println("could not run server: ", serr)
	}

	/* endpoint REST call
	** http://localhost:9092/gid/d29f0e57-f44e-11e9-97e1-0d091e77f50e
	** curl http://localhost:9092/gid/d1b4eefa-f44e-11e9-96fe-3f89f8cd854a;
	** curl http://orderhistory-client.sg.orderhistory-production:9092/gid/d23f3eb8-f44e-11e9-a192-e3237ed58e10
	 */

}
