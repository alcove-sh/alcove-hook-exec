#!/bin/sh

. ./common.in

# check root
checkpath -d -m 777 /
checkpath -d -m 644 /
checkpath -d -o root /
checkpath -d -o nobody /
checkpath -d -m 755 -o root /
checkpath -d -m 755 -o nobody /
checkpath -W /root || eerror "/root: unwritable!"

