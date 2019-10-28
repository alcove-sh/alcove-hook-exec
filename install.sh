#!/bin/sh

install -m644 dist/00-common.in /alcove-hooks/00-common.in
ln -s /alcove-hooks/00-common.in -f /alcove-hooks/common.in
exit "${?}"

