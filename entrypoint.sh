#!/bin/sh
set -eu

copy_runtime_binaries() {
	mkdir -p /home/container

	for bin in mt-multiserver-proxy mt-auth-convert mt-build-plugin; do
		install -m 0755 "/usr/local/mt-multiserver-proxy/$bin" "/home/container/$bin"
	done

	mkdir -p /home/container/plugins

	if [ "$(id -u)" -eq 0 ]; then
		chown container:container \
			/home/container \
			/home/container/plugins \
			/home/container/mt-multiserver-proxy \
			/home/container/mt-auth-convert \
			/home/container/mt-build-plugin 2>/dev/null || true
	fi
}

ensure_startup_command() {
	if [ -z "${STARTUP:-}" ]; then
		STARTUP="/home/container/mt-multiserver-proxy"
		export STARTUP
	fi
}

copy_runtime_binaries
ensure_startup_command

cd /home/container || exit 1

PARSED=$(echo "$STARTUP" | sed -e 's/{{/${/g' -e 's/}}/}/g')

echo "container~ $PARSED"

if [ "$(id -u)" -eq 0 ]; then
	exec gosu container sh -c "$PARSED"
fi

exec sh -c "$PARSED"
