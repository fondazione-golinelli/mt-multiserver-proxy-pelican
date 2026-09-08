#!/usr/bin/env bash
set -euo pipefail
: "${GH_TOKEN:?}" "${GITHUB_ACTOR:?}" "${GITHUB_SHA:?}" "${GITHUB_OUTPUT:?}" "${IMAGE_NAME:?}"
proxy_sha=$(gh api repos/fondazione-golinelli/mt-multiserver-proxy/commits/main --jq .sha)
[[ "$proxy_sha" =~ ^[a-f0-9]{40}$ ]] || { echo 'Invalid upstream SHA' >&2; exit 1; }
identity=$(printf '%s\n' "$proxy_sha" "$GITHUB_SHA" | sha256sum | cut -d' ' -f1)
marker="build-$identity"
registry_token=$(curl --fail --silent --show-error --retry 3 --get \
  --user "$GITHUB_ACTOR:$GH_TOKEN" --data-urlencode service=ghcr.io \
  --data-urlencode "scope=repository:$IMAGE_NAME:pull" \
  https://ghcr.io/token | jq -er '.token // .access_token')
status=$(curl --silent --show-error --retry 3 -o /dev/null -w '%{http_code}' \
  -H "Authorization: Bearer $registry_token" \
  -H 'Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.v2+json' \
  "https://ghcr.io/v2/$IMAGE_NAME/manifests/$marker")
case "$status" in
  200) should_build=false ;;
  404) should_build=true ;;
  *) echo "Registry returned HTTP $status; refusing to assume a missing image" >&2; exit 1 ;;
esac
if [[ "${FORCE_BUILD:-false}" == true ]]; then should_build=true; fi
{
  echo "proxy_sha=$proxy_sha"
  echo "proxy_short_sha=${proxy_sha:0:12}"
  echo "marker=$marker"
  echo "should_build=$should_build"
} >> "$GITHUB_OUTPUT"
echo "Proxy $proxy_sha: build=$should_build"
