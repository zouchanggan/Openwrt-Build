#!/bin/bash
set -e
exec bash <(curl -fsSL http://127.0.0.1:8080/openwrt/build.sh) "$@"
