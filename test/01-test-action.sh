#!/bin/sh

HERE=${0%/*}

command="/usr/bin/qbittorrent-nox"

. "${HERE}"/common.in

action "${1}"

