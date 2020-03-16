package utils

import (
	"context"
	"google.golang.org/grpc"
	"time"
	sgutils "github.com/polyglotDataNerd/zib-Go-utils/utils"

)
//https://medium.com/@shijuvar/writing-grpc-interceptors-in-go-bf3e7671fe48

func LoggingMiddleWareClient(ctx context.Context, method string, req interface{}, reply interface{}, cc *grpc.ClientConn, invoker grpc.UnaryInvoker, opts ...grpc.CallOption) error {
	start := time.Now()
	sgutils.Trace.Println("rpc start", "method", method)
	err := invoker(ctx, method, req, reply, cc, opts...)
	sgutils.Trace.Println("rpc end", "method", method, "duration", time.Since(start), "error", err)
	return err
}

func LoggingMiddleWareServer(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
	start := time.Now()
	h, err := handler(ctx, req)
	sgutils.Trace.Printf("Request - Method:%s\tDuration:%s\tError:%v", info.FullMethod, time.Since(start), err)
	return h, err
}
