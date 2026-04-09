# mt-multiserver-proxy Server for Pelican Panel

A custom [mt-multiserver-proxy](https://github.com/HimbeerserverDE/mt-multiserver-proxy) Docker image built for use with the [Pelican](https://pelican.dev/) game server panel.

## Why does this exist?

The upstream proxy image is not a great fit for Pelican as-is:

1. Pelican passes startup commands through the `STARTUP` environment variable, so we want the same startup-aware entrypoint behavior used by Pelican yolks.
2. `mt-multiserver-proxy` stores `config.json`, `latest.log`, `plugins`, `auth`, `ban`, and `cache` next to the running executable. Under Pelican, the writable server volume is `/home/container`, while the image filesystem is effectively immutable for server state.
3. Proxy plugins are Go plugins, so the runtime image should keep the Go toolchain available for `mt-build-plugin` and automatic plugin builds.

This image solves that by:

- building the upstream proxy binaries from source
- keeping the Go toolchain in the runtime image
- copying `mt-multiserver-proxy`, `mt-auth-convert`, and `mt-build-plugin` into `/home/container` at startup
- running the proxy from `/home/container`, so all proxy-managed state lands on the writable Pelican volume
- using a Pelican-compatible entrypoint that reads `STARTUP`

## Image

```text
ghcr.io/fondazione-golinelli/mt-multiserver-proxy-pelican:latest
```

If your repository or package name differs, update:

- `docker_images` in [egg-mt-multiserver-proxy.json](egg-mt-multiserver-proxy.json)
- the published package name in the workflow if you do not want to use `${{ github.repository }}`

## Tags

Because upstream does not publish GitHub releases for this project, the workflow watches the upstream `main` branch and publishes:

- `latest`
- `main`
- `<yyyyMMddHHmmss>-<12 char sha>`
- `<12 char sha>`

## Pelican Egg

An egg configuration file is included in this repo: [egg-mt-multiserver-proxy.json](egg-mt-multiserver-proxy.json)

The egg points the server startup command at `/home/container/mt-multiserver-proxy`. By default, the entrypoint now renders `config.json` from Pelican environment variables on each boot. Set `PROXY_MANAGE_CONFIG=false` if you want to maintain `config.json` manually.

## Automatic builds

A GitHub Action checks daily for a new upstream commit on `HimbeerserverDE/mt-multiserver-proxy:main`. When the commit changes, the image is rebuilt and pushed to GHCR. You can also trigger the workflow manually.

## Notes for your setup

For your minigame architecture, the most important bootstrap config values are:

- one static backend server entry, because dynamic servers in `mt-multiserver-proxy` require an existing static media-pool member
- plugin support enabled, because the proxy still needs a plugin or companion process to call `AddServer` / `RmServer`
- shared container networking between this proxy container and Pelican-managed Luanti server containers

A good default bootstrap backend is your lobby server.
