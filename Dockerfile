# syntax=docker/dockerfile:1
# check=error=true

ARG GO_IMAGE=golang:1.25.6-bookworm
ARG MT_MULTISERVER_PROXY_REPO=fondazione-golinelli/mt-multiserver-proxy
ARG MT_MULTISERVER_PROXY_VERSION=main

FROM $GO_IMAGE AS builder

ARG MT_MULTISERVER_PROXY_REPO
ARG MT_MULTISERVER_PROXY_VERSION
ENV GOBIN=/opt/mt-multiserver-proxy

RUN apt-get update && \
	apt-get install -y --no-install-recommends ca-certificates curl && \
	rm -rf /var/lib/apt/lists/*

RUN mkdir -p "$GOBIN" /tmp/mt-multiserver-proxy && \
	curl -fsSL "https://codeload.github.com/${MT_MULTISERVER_PROXY_REPO}/tar.gz/${MT_MULTISERVER_PROXY_VERSION}" \
		-o /tmp/mt-multiserver-proxy/source.tar.gz && \
	tar -xzf /tmp/mt-multiserver-proxy/source.tar.gz -C /tmp/mt-multiserver-proxy --strip-components=1 && \
	cd /tmp/mt-multiserver-proxy && \
	go install -buildvcs=false ./cmd/...

FROM $GO_IMAGE AS runtime

RUN apt-get update && \
	apt-get install -y --no-install-recommends tini gosu ca-certificates git jq && \
	rm -rf /var/lib/apt/lists/* && \
	useradd -m -d /home/container -u 1000 container && \
	chown -R container:container /home/container

WORKDIR /home/container

COPY --from=builder /opt/mt-multiserver-proxy /usr/local/mt-multiserver-proxy
COPY --from=builder /go/pkg/sumdb /go/pkg/sumdb
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 40000/udp

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]
