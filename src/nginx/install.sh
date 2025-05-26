#!/bin/bash

set -eEuo pipefail

NGINX_VERSION="${VERSION:-"mainline"}"
CONFIG_PHP_FPM="${ENABLE_PHP_FPM:-"true"}"

DEBIAN_DEPENDENCIES="debian-archive-keyring"
UBUNTU_DEPENDENCIES="ubuntu-keyring"


export DEBIAN_FRONTEND=noninteractive

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

install_nginx() {

    local nginx_package_str=""
    local distribution=""
    local dependencies=""

    apt update -y
    apt install -y --no-install-recommends \
        curl \
        gnupg2 \
        ca-certificates \
        lsb-release

    distribution="$(lsb_release -si)"
    if [ "Debian" = "$distribution" ]; then
        dependencies="$DEBIAN_DEPENDENCIES"
        distribution="debian"
    fi

    if [ "Ubuntu" = "$distribution" ]; then
        dependencies="$UBUNTU_DEPENDENCIES"
        distribution="ubuntu"
    fi
    apt install -y --no-install-recommends "$dependencies"

    nginx_package_str="http://nginx.org/packages/${NGINX_VERSION}/${distribution}"

    if [ "stable" = "$NGINX_VERSION" ]; then
        nginx_package_str="http://nginx.org/packages/${distribution}"
    fi

    curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

    gpg --dry-run --quiet --no-keyring --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg


    echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
    "$nginx_package_str" `lsb_release -cs` nginx" \
    | tee /etc/apt/sources.list.d/nginx.list

    echo -e "Package: *\nPin: origin nginx.org\nPin: release o=nginx\nPin-Priority: 900\n" \
    | tee /etc/apt/preferences.d/99nginx

    apt update -y
    apt install -y --no-install-recommends nginx 
}

config-php-fpm() {
    local confDir=""
    local defaultFile=""

    confDir="/etc/nginx/conf.d"
    defaultFile="$confDir/default.conf"

    rm -f "$defaultFile"
    cp -v "fpm.conf" "$defaultFile"
}

install_nginx

if [ "true" = "$CONFIG_PHP_FPM" ]; then
    config-php-fpm
fi
