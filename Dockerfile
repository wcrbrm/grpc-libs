# Copyright 2017-2021 Digital Asset Exchange Limited. All rights reserved.
# Use of this source code is governed by Microsoft Reference Source
# License (MS-RSL) that can be found in the LICENSE file.

FROM golang:1.16 as deps

ENV PROTOC_VERSION=3.15.4
ENV PROTOC_ZIP=protoc-${PROTOC_VERSION}-linux-x86_64.zip
ENV PROTOC_PLUGINS=grpc
ENV GOBIN=/usr/local/bin

RUN apt-get update && apt-get install -yf --no-install-recommends \
    unzip

# Install protoc
RUN curl -OLqs https://github.com/google/protobuf/releases/download/v${PROTOC_VERSION}/${PROTOC_ZIP} && \
    unzip -o ${PROTOC_ZIP} -d /usr/local bin/protoc && \
    unzip -o ${PROTOC_ZIP} -d /usr/local include/* && \
    rm -f ${PROTOC_ZIP}

WORKDIR /deps

RUN GO111MODULE=auto go get -u github.com/golang/protobuf/protoc-gen-go
RUN GO111MODULE=auto go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-grpc-gateway
RUN GO111MODULE=auto go get -u github.com/grpc-ecosystem/grpc-gateway/protoc-gen-openapiv2
RUN GO111MODULE=auto go get -u google.golang.org/grpc
RUN GO111MODULE=auto go get -u github.com/novalagung/gorep
RUN GO111MODULE=auto go get -u github.com/amsokol/protoc-gen-gotag

RUN mkdir -p /proto/ && \
    cd /usr/local/include && \
    find . -name "*.proto" -type f -exec cp --parents '{}' /proto/ \; && \
    find /proto/ -type f | grep \.proto$

RUN cd /go && \
    git clone --depth=1 https://github.com/googleapis/googleapis && \
    cd /go/googleapis/ && \
    find google/api -name "*.proto" -type f -exec cp --parents '{}' /proto/ \; && \
    rm -fR /go/googleapis

RUN cd /go/src/github.com/grpc-ecosystem/grpc-gateway/ && \
    find ./protoc-gen-openapiv2/ -name "*.proto" -type f -exec cp --parents '{}' /proto/ \; && \
    find /proto/ -type f | grep \.proto$

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
