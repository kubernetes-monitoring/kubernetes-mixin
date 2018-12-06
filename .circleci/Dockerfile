# Dockerfile for image used to run CI.

FROM alpine:3.7
RUN apk --no-cache add alpine-sdk git openssl-dev

RUN git clone https://github.com/google/jsonnet && \
    git  -C jsonnet checkout v0.10.0 && \
    make -C jsonnet LDFLAGS=-static

FROM circleci/golang:1.10.3-stretch
COPY --from=0 jsonnet/jsonnet /usr/bin
