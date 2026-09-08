#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
image=${1:?Image required}
container_id=$(docker run -d --user 1000:1000 \
  --mount "type=bind,src=$PWD/tests/abi-smoke,dst=/abi-source,readonly" \
  -e STARTUP='mkdir -p /home/container/plugins/abi-smoke && cp -R /abi-source/. /home/container/plugins/abi-smoke/ && exec /home/container/mt-multiserver-proxy' \
  "$image")
trap 'docker rm -fv "$container_id" >/dev/null' EXIT
for attempt in {1..180}; do
  logs=$(docker logs "$container_id" 2>&1)
  if [[ "$logs" == *'load auto plugin abi-smoke'* ]]; then
    echo 'Runtime plugin build and load passed'
    exit 0
  fi
  if [[ "$logs" == *'different version of package'* ]] || \
     [[ $(docker inspect -f '{{.State.Running}}' "$container_id") != true ]]; then
    printf '%s\n' "$logs" >&2
    exit 1
  fi
  sleep 1
done
docker logs "$container_id" >&2
echo 'Timed out waiting for plugin load' >&2
exit 1
