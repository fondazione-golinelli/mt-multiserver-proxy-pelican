# syntax=docker/dockerfile:1
# check=error=true

ARG GO_IMAGE=golang:1.26.6-bookworm
ARG MT_MULTISERVER_PROXY_REPO=fondazione-golinelli/mt-multiserver-proxy
ARG MT_MULTISERVER_PROXY_VERSION=latest

FROM $GO_IMAGE AS runtime

RUN apt-get update && \
	apt-get install -y --no-install-recommends tini gosu ca-certificates git jq && \
	rm -rf /var/lib/apt/lists/* && \
	useradd -m -d /home/container -u 1000 container && \
	chown -R container:container /home/container

WORKDIR /home/container

ARG MT_MULTISERVER_PROXY_REPO
ARG MT_MULTISERVER_PROXY_VERSION

ENV GONOSUMCHECK=github.com/HimbeerserverDE/mt-multiserver-proxy
ENV GONOSUMDB=github.com/HimbeerserverDE/mt-multiserver-proxy
ENV GOPRIVATE=github.com/HimbeerserverDE/mt-multiserver-proxy
ENV PROXY_PROXY_VERSION=${MT_MULTISERVER_PROXY_VERSION}
ENV GOFLAGS=-trimpath

RUN git config --system url."https://github.com/${MT_MULTISERVER_PROXY_REPO}".insteadOf "https://github.com/HimbeerserverDE/mt-multiserver-proxy"

# Compile during CI, so an image cannot publish with an unbuildable proxy.
RUN GOBIN=/opt/proxy/bin go install \
    github.com/HimbeerserverDE/mt-multiserver-proxy/cmd/...@${MT_MULTISERVER_PROXY_VERSION} && \
    printf '%s' "${MT_MULTISERVER_PROXY_VERSION}" > /opt/proxy/version

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 40000/udp

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]
