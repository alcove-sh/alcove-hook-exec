#!/bin/sh

set -e

sed -e '/^[ \t]*$/d' \
	-e '/^[ \t]*#.*$/d' \
	-e 's/^[ \t]*//' \
	-Ee 's/^#! +([^ ;]+)/#!\1/' \
	-Ee 's/([^;]+);$/\1/' \
	-Ee 's/\$([0-9A-Za-z@#!?%_-]|[A-Za-z_][0-9A-Za-z_]+)/\${\1}/g' \
		src/common.sh > dist/00-common.in


