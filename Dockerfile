# syntax=docker/dockerfile:1
# check=error=true

ARG GO_IMAGE=golang:1.25.6-bookworm
ARG MT_MULTISERVER_PROXY_REPO=fondazione-golinelli/mt-multiserver-proxy

FROM $GO_IMAGE AS runtime

RUN apt-get update && \
	apt-get install -y --no-install-recommends tini gosu ca-certificates git jq && \
	rm -rf /var/lib/apt/lists/* && \
	useradd -m -d /home/container -u 1000 container && \
	chown -R container:container /home/container

WORKDIR /home/container

ARG MT_MULTISERVER_PROXY_REPO

ENV GONOSUMCHECK=github.com/HimbeerserverDE/mt-multiserver-proxy
ENV GONOSUMDB=github.com/HimbeerserverDE/mt-multiserver-proxy

RUN git config --system url."https://github.com/${MT_MULTISERVER_PROXY_REPO}".insteadOf "https://github.com/HimbeerserverDE/mt-multiserver-proxy"

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 40000/udp

ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/entrypoint.sh"]
