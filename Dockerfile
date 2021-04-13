ARG GO_VERSION=1.16
FROM golang:${GO_VERSION} as deps

ENV GOBIN=/usr/local/bin

RUN apt-get update && apt-get install -yf --no-install-recommends \
    unzip

# protoc
RUN VER=`curl -sI https://github.com/protocolbuffers/protobuf/releases/latest | \
    grep -i '^location: ' | sed -E 's/^.*v([0-9.]+)\r$/\1/'` && \
    echo "INFO: protoc [$VER] version" && \
    ZIP=protoc-${VER}-linux-x86_64.zip && \
    curl -OLqs https://github.com/google/protobuf/releases/download/v${VER}/${ZIP} && \
    unzip -o ${ZIP} -d /usr/local bin/protoc && \
    unzip -o ${ZIP} -d /usr/local include/* && \
    rm -f ${ZIP}

# protoc-gen-grpc-gateway, protoc-gen-openapiv2
RUN VER=`curl -sI https://github.com/grpc-ecosystem/grpc-gateway/releases/latest | \
    grep -i '^location: ' | sed -E 's/^.*v([0-9.]+)\r$/\1/'` && \
    echo "INFO: grpc-gateway [$VER] version" && \
    mkdir -p /go/src/github.com/grpc-ecosystem/grpc-gateway && \
    curl -sL https://github.com/grpc-ecosystem/grpc-gateway/archive/refs/tags/v${VER}.tar.gz | tar -zxC /go/src/github.com/grpc-ecosystem/grpc-gateway --strip-components=1 && \
    curl -sL https://github.com/grpc-ecosystem/grpc-gateway/releases/download/v${VER}/protoc-gen-grpc-gateway-v${VER}-linux-x86_64 -o /usr/local/bin/protoc-gen-grpc-gateway && \
    curl -sL https://github.com/grpc-ecosystem/grpc-gateway/releases/download/v${VER}/protoc-gen-openapiv2-v${VER}-linux-x86_64 -o /usr/local/bin/protoc-gen-openapiv2 && \
    chmod 0755 /usr/local/bin/protoc-gen-grpc-gateway && \
    chmod 0755 /usr/local/bin/protoc-gen-openapiv2

RUN go get -u google.golang.org/protobuf/cmd/protoc-gen-go
RUN go get -u google.golang.org/grpc/cmd/protoc-gen-go-grpc
RUN go get -u github.com/amsokol/protoc-gen-gotag

WORKDIR /deps

RUN mkdir -p /proto/ && \
    cd /usr/local/include && \
    find . -name "*.proto" -type f -exec cp --parents '{}' /proto/ \;

RUN REPO=github.com/googleapis/googleapis && \
    git clone --depth=1 https://${REPO} /go/src/${REPO} && \
    cd /go/src/${REPO} && \
    find google/api -name "*.proto" -type f -exec cp --parents '{}' /proto/ \; && \
    rm -fR /go/src/${REPO}

RUN REPO=github.com/grpc-ecosystem/grpc-gateway && \
    cd /go/src/${REPO} && \
    find ./protoc-gen-openapiv2/ -name "*.proto" -type f -exec cp --parents '{}' /proto/ \; && \
    rm -fR /go/src/${REPO}

RUN mkdir -p /chroot && \
    find /proto > chroot.list && \
    find /usr/local/bin/ -exec bash -c "ldd '{}' 2>/dev/null | grep -oE '/lib.*.so.[0-9]+'" \; >> chroot.list && \
    find /usr/local/bin/ >> chroot.list && \
    tar -cvhf - -T chroot.list | tar -xvf - -C /chroot && \
    chmod -R a+w /chroot

FROM bash:4.4
VOLUME /app
WORKDIR /app
COPY --from=deps /chroot/ /
CMD ["bash"]
