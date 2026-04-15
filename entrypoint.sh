#!/bin/sh
set -eu

bool_to_json() {
	value=$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')

	case "$value" in
		1|true|yes|on)
			printf 'true'
			;;
		0|false|no|off|'')
			printf 'false'
			;;
		*)
			echo "error: invalid boolean value: ${1:-}" >&2
			exit 1
			;;
	esac
}

int_or_default() {
	value="${1:-}"
	fallback="$2"

	case "$value" in
		''|0)
			printf '%s' "$fallback"
			;;
		*[!0-9]*)
			echo "error: invalid integer value: $value" >&2
			exit 1
			;;
		*)
			printf '%s' "$value"
			;;
	esac
}

copy_runtime_binaries() {
	mkdir -p /home/container

	for bin in mt-multiserver-proxy mt-auth-convert mt-build-plugin; do
		install -m 0755 "/usr/local/mt-multiserver-proxy/$bin" "/home/container/$bin"
	done

	mkdir -p /home/container/plugins /home/container/auth /home/container/ban /home/container/cache
	: > /home/container/latest.log

	if [ "$(id -u)" -eq 0 ]; then
		chown container:container \
			/home/container \
			/home/container/auth \
			/home/container/ban \
			/home/container/cache \
			/home/container/plugins \
			/home/container/latest.log \
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

config_has_placeholders() {
	[ -f /home/container/config.json ] || return 1
	grep -Eq '__[A-Z0-9_]+__' /home/container/config.json
}

ensure_proxy_config() {
	manage_config=$(bool_to_json "${PROXY_MANAGE_CONFIG:-true}")
	should_render=0

	if [ "$manage_config" = "true" ] || [ ! -f /home/container/config.json ] || config_has_placeholders; then
		should_render=1
	fi

	if [ "$should_render" -ne 1 ]; then
		return 0
	fi

	server_port=$(int_or_default "${SERVER_PORT:-}" "40000")
	user_limit=$(int_or_default "${PROXY_USER_LIMIT:-}" "100")
	require_passwd=$(bool_to_json "${PROXY_REQUIRE_PASSWD:-false}")
	force_default_srv=$(bool_to_json "${PROXY_FORCE_DEFAULT_SRV:-true}")
	no_auto_plugins=$(bool_to_json "${PROXY_NO_AUTO_PLUGINS:-false}")
	no_plugins=$(bool_to_json "${PROXY_NO_PLUGINS:-false}")
	list_enable=$(bool_to_json "${PROXY_LIST_ENABLE:-false}")

	auth_backend="${PROXY_AUTH_BACKEND:-files}"
	auth_postgres_conn="${PROXY_AUTH_POSTGRES_CONN:-}"
	default_server="${PROXY_DEFAULT_SERVER:-lobby}"
	server_selector="${PROXY_SERVER_SELECTOR:-}"
	static_server_name="${PROXY_STATIC_SERVER_NAME:-lobby}"
	static_server_addr="${PROXY_STATIC_SERVER_ADDR:-lobby:30000}"
	static_media_pool="${PROXY_STATIC_MEDIA_POOL:-$static_server_name}"
	static_fallback="${PROXY_STATIC_FALLBACK:-}"
	list_name="${PROXY_LIST_NAME:-Pelican Luanti Proxy}"
	list_desc="${PROXY_LIST_DESC:-}"
	list_url="${PROXY_LIST_URL:-}"
	admin_users="${PROXY_ADMIN_USERS:-}"

	# Build UserGroups and Groups JSON from PROXY_ADMIN_USERS (comma-separated)
	user_groups="{}"
	groups='{"admin":["server","*"],"default":[]}'
	if [ -n "$admin_users" ]; then
		user_groups=$(printf '%s' "$admin_users" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R -s 'split("\n") | map(select(length > 0)) | map({(.): "admin"}) | add // {}')
	fi

	tmp_config=/home/container/config.json.tmp

	jq -n \
		--arg bind_addr ":$server_port" \
		--arg auth_backend "$auth_backend" \
		--arg auth_postgres_conn "$auth_postgres_conn" \
		--arg default_server "$default_server" \
		--arg server_selector "$server_selector" \
		--arg static_server_name "$static_server_name" \
		--arg static_server_addr "$static_server_addr" \
		--arg static_media_pool "$static_media_pool" \
		--arg static_fallback "$static_fallback" \
		--arg list_name "$list_name" \
		--arg list_desc "$list_desc" \
		--arg list_url "$list_url" \
		--argjson require_passwd "$require_passwd" \
		--argjson force_default_srv "$force_default_srv" \
		--argjson no_auto_plugins "$no_auto_plugins" \
		--argjson no_plugins "$no_plugins" \
		--argjson user_limit "$user_limit" \
		--argjson list_enable "$list_enable" \
		--argjson user_groups "$user_groups" \
		--argjson groups "$groups" \
		'{
			BindAddr: $bind_addr,
			AuthBackend: $auth_backend,
			AuthPostgresConn: $auth_postgres_conn,
			RequirePasswd: $require_passwd,
			DefaultSrv: $default_server,
			ForceDefaultSrv: $force_default_srv,
			SrvSelector: $server_selector,
			NoAutoPlugins: $no_auto_plugins,
			NoPlugins: $no_plugins,
			UserLimit: $user_limit,
			UserGroups: $user_groups,
			Groups: $groups,
			Servers: {
				($static_server_name): {
					Addr: $static_server_addr,
					MediaPool: $static_media_pool,
					Fallback: $static_fallback,
					Groups: []
				}
			},
			List: {
				Enable: $list_enable,
				Addr: "https://servers.luanti.org",
				Interval: 300,
				Name: $list_name,
				Desc: $list_desc,
				URL: $list_url,
				Creative: false,
				Dmg: true,
				PvP: false,
				Game: "luanti",
				FarNames: true,
				Mods: []
			}
		}' > "$tmp_config"

	mv "$tmp_config" /home/container/config.json

	if [ "$(id -u)" -eq 0 ]; then
		chown container:container /home/container/config.json 2>/dev/null || true
	fi
}

copy_runtime_binaries
ensure_startup_command
ensure_proxy_config

cd /home/container || exit 1

PARSED=$(echo "$STARTUP" | sed -e 's/{{/${/g' -e 's/}}/}/g')

echo "container~ $PARSED"

if [ "$(id -u)" -eq 0 ]; then
	exec gosu container sh -c "$PARSED"
fi

exec sh -c "$PARSED"
