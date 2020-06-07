FROM buildpack-deps:stretch-scm

MAINTAINER Gerard Bartolome (gerard.bartolome@sweetgreen.com)

ARG USER_HOME_DIR="/root"
ARG AWS_ACCESS_KEY_ID
ARG AWS_SECRET_ACCESS_KEY
ARG UBER_ACCESS_KEY_ID
ARG UBER_SECRET_ACCESS_KEY
ARG AWS_REGION=us-west-2
ARG GitToken
ARG GitHash

RUN git config --global url."https://${GitToken}:@github.com/".insteadOf "https://github.com/"

# gcc for cgo
RUN apt-get update && apt-get install -y --no-install-recommends \
		g++ \
		gcc \
		libc6-dev \
		make \
		pkg-config \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get update && apt-get -y install python-pip python-yaml python-dev \
  && apt-get install -y unzip \
  && pip install awscli \
  && curl -o /usr/local/bin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest \
  && chmod +x /usr/local/bin/ecs-cli \
  && apt-get -y install vim \
  && aws --version \
  && aws configure set aws_access_key_id ${AWS_ACCESS_KEY_ID} --profile default \
  && aws configure set aws_secret_access_key ${AWS_SECRET_ACCESS_KEY} --profile default \
  && aws configure set region ${AWS_REGION}

ENV GOLANG_VERSION 1.12.8

RUN set -eux; \
	\
# this "case" statement is generated via "update.sh"
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
		amd64) goRelArch='linux-amd64'; goRelSha256='bd26cd4962a362ed3c11835bca32c2e131c2ae050304f2c4df9fa6ded8db85d2' ;; \
		armhf) goRelArch='linux-armv6l'; goRelSha256='b6b057e7b5c740894132ce30e70503d7d36988dcd61a00f0865d1e7d6dcc74ca' ;; \
		arm64) goRelArch='linux-arm64'; goRelSha256='15e9e0b5b414d1a0322896368c0050af6ab1cd82d050e93f8eceb38ef2626652' ;; \
		i386) goRelArch='linux-386'; goRelSha256='be164c4e04205c4fc713e81594bc2fdd4c94dff3d567ec8e0072223dd0778287' ;; \
		ppc64el) goRelArch='linux-ppc64le'; goRelSha256='24a65f8a702ade1854f86ddf96eda554a8abd89c8a54ddc32788769419e90232' ;; \
		s390x) goRelArch='linux-s390x'; goRelSha256='db78fc8f9610cb27ac35aab55cb11698f4daa2101acdf46f0ba64e1db16323e5' ;; \
		*) goRelArch='src'; goRelSha256='11ad2e2e31ff63fcf8a2bdffbe9bfa2e1845653358daed593c8c2d03453c9898'; \
			echo >&2; echo >&2 "warning: current architecture ($dpkgArch) does not have a corresponding Go binary release; will be building from source"; echo >&2 ;; \
	esac; \
	\
	url="https://golang.org/dl/go${GOLANG_VERSION}.${goRelArch}.tar.gz"; \
	wget -O go.tgz "$url"; \
	echo "${goRelSha256} *go.tgz" | sha256sum -c -; \
	tar -C /usr/local -xzf go.tgz; \
	rm go.tgz; \
	\
	if [ "$goRelArch" = 'src' ]; then \
		echo >&2; \
		echo >&2 'error: UNIMPLEMENTED'; \
		echo >&2 'TODO install golang-any from jessie-backports for GOROOT_BOOTSTRAP (and uninstall after build)'; \
		echo >&2; \
		exit 1; \
	fi; \
	\
	export PATH="/usr/local/go/bin:$PATH"; \
	go version

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH" \
&& curl https://raw.githubusercontent.com/golang/dep/master/install.sh | sh

#install protobuf compiler
RUN curl -OL https://github.com/google/protobuf/releases/download/v3.11.2/protoc-3.11.2-linux-x86_64.zip \
    && unzip protoc-3.11.2-linux-x86_64.zip -d protoc3 \
    && mv protoc3/bin/* /usr/local/bin/ \
    && mv protoc3/include/* /usr/local/include/ \
    && go get -u github.com/golang/protobuf/protoc-gen-go \
    && go get -u github.com/golang/protobuf/proto \
    && echo $PATH

RUN git clone -b master https://github.com/polyglotDataNerd/poly-gRPC-orderhistory.git \
    && cd sg-gRPC-orderhistory \
    && curl https://www.amazontrust.com/repository/AmazonRootCA1.pem -O \
    && go get -d -v ./... \
    && go get -u all \
    #run to compile protobuf message into a go object
    && protoc -I definiton/ definiton/orderhistory.proto --go_out=plugins=grpc:definiton \
    && go mod tidy


WORKDIR /sg-gRPC-orderhistory/server
# builds grpc Server
RUN go build HistoryServer.go
ENTRYPOINT ["./HistoryServer"]
