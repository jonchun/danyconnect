#!/bin/sh
#
# Jonathan Chun

OPENCONNECT_ARGS="-i tun0 --user=${USER} --passwd-on-stdin --non-inter"

setup_openconnect() {
    # ===== START REQUIRED VARS =====
    if [ -z "${URL}" ]; then
        printf "\e[31m\$URL is not set\n\e[0m"
        exit 1
    fi
    printf "\e[33mURL:\e[0m %s \n" "${URL}"

    if [ -z "${USER}" ]; then
        printf "\e[31m\$USER is not set\e[0m\n"
        exit 1
    fi
    printf "\e[33mUsername:\e[0m %s\n" "${USER}"

    if [ -z "${PASSWORD}" ]; then
        printf "\e[31m\$PASSWORD is not set\e[0m\n"
        exit 1
    fi
    printf "\e[33mPassword:\e[0m [REDACTED]\n\n"
    # ===== END REQUIRED VARS =====

    # ===== START OPTIONAL VARS =====
    printf "\e[32mChecking for authentication group parameter...\e[0m\n"
    if [ -n "${AUTH_GROUP}" ]; then
        OPENCONNECT_ARGS="${OPENCONNECT_ARGS} --authgroup=${AUTH_GROUP}"
    fi

    printf "\e[32mChecking for TOTP Secret parameter...\e[0m\n"
    if [ -n "${TOTP_SECRET}" ]; then
        OPENCONNECT_ARGS="${OPENCONNECT_ARGS} --token-mode=totp --token-secret=${TOTP_SECRET}"
    fi

    printf "\e[32mChecking for additional arguments...\e[0m\n"
    if [ -n "${EXTRA_ARGS}" ]; then
        OPENCONNECT_ARGS="${OPENCONNECT_ARGS} ${EXTRA_ARGS}"
    fi
    # ===== END OPTIONAL VARS =====

    # URL needs to be the last argument
    printf "\e[32mSetting URL...\e[0m\n"
    OPENCONNECT_ARGS="${OPENCONNECT_ARGS} ${URL}"

    printf "\e[32mStarting OpenConnect VPN...\e[0m\n"
    printf "\e[33mArguments:\e[0m %s\n\n" "${OPENCONNECT_ARGS}"

}

start_openconnect() {
    echo "${PASSWORD}" | openconnect ${OPENCONNECT_ARGS} 2>/dev/null
}

fix_route() {
    # sleep until VPN is online
    while ! grep -q VPNC /etc/resolv.conf; do
        sleep 5
    done

    # once the VPN is online, force add route for the original and overwrite any changes from server
    iptables -t nat -A POSTROUTING --out-interface tun0 -j MASQUERADE
    ip route add ${default_gw} dev eth0

    echo "Fixed Routes. Running SOCKS Proxy..."
    run_ssh
}

setup_ssh() {
    # generate local keys
    ssh-keygen -A

    # add $AUTHORIZED_KEYS env variable to authorized_keys
    local authorizedKeys=""
    if [ -n "${AUTHORIZED_KEYS}" ]; then
        echo "Loaded keys from \$AUTHORIZED_KEYS env variable"
        authorizedKeys="${AUTHORIZED_KEYS}\n"
    fi

    # get all the .pub keys in /etc/ssh and add them to authorized_keys
    authorizedKeys=$(echo "${authorizedKeys}$(find '/etc/ssh/' -type f -name '*.pub' -exec cat {} \;)")
    echo "${authorizedKeys}" >/root/.ssh/authorized_keys

    # fix perms
    chown root /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys

    # # start the daemon
    /usr/sbin/sshd

    # # add keys to known_hosts
    ssh-keyscan -H localhost >>/root/.ssh/known_hosts
}

run_ssh() {
    # this runs a local SOCKS proxy on 1080 in the background.
    ssh -4 -N -D 0.0.0.0:1080 -i /etc/ssh/ssh_host_ed25519_key localhost
}

# find network config before connecting to anyconnect
default_gw=$(ip route show | grep default | awk '{print $3}')
eth0_subnet=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}')

setup_openconnect
setup_ssh

fix_route &

until (start_openconnect); do
    echo "OpenConnect exited. Automatically reconnecting in 60 seconds..." >&2
    sleep 60
done
