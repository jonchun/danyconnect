#!/bin/sh

# set -e

script=$(readlink -f "$0")
script_path=$(dirname "$script")
# # shellcheck disable=SC1091
# . "${SCRIPT_PATH}/env"
. "./env"

# automatically add all local public keys to the container for ssh auth
authorizedKeys=$(echo "${authorizedKeys}$(find "${HOME}/.ssh" -type f -name '*.pub' -exec cat {} \;)")

docker run -d \
--restart=always \
--cap-add NET_ADMIN \
--name "${CONTAINER_NAME}" \
-e URL="${URL}" \
-e USER="${USER}" \
-e AUTH_GROUP="${AUTH_GROUP}" \
-e PASSWORD="${PASSWORD}" \
-e TOTP_SECRET="${TOTP_SECRET}" \
-e AUTHORIZED_KEYS="${authorizedKeys}" \
-e EXTRA_ARGS="${EXTRA_ARGS}" \
--publish ${SSH_PORT}:22/tcp \
--publish ${SOCKS_PORT}:1080/tcp \
danyconnect