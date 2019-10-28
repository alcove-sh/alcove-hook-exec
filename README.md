# alcove-hook-functions

**TODO:**
- [x] checkpath dir test
- [x] checkpath file test
- [x] checkpath pipe test
- [x] checkpath correct test
- [x] checkpath truncate test

**Examples:**
```sh
#!/bin/sh
# href=./test/22-sshd

HERE="${0%/*}"

command="/usr/sbin/sshd"
pidfile="/var/run/sshd.pid"

. "${HERE}/00-common.in"

stop_post() {
	# Kill all ssh connections.
	pgrep "^${command##*/}" | xargs -r kill -s 15
}

action "$1"

```

```sh
#!/bin/sh
# href=./test/00-mytmp

owner="root:www-data"
tmp_dir=/opt/tmp

#set -x

. /alcove-hooks/00-common.in


start_pre() {
	quietly status

	if issuccess; then
		# fix mount twice or more.
		return 1
	fi

	return 0
}

start() {
	checkpath -d "${tmp_dir}"	
	mount -t tmpfs tmpfs "${tmp_dir}"

	checkpath -d -m1777 -o "${owner}" "${tmp_dir}"	

	eend "${?}" "Failed to start ${nmae:-"${0}"}"
}

stop() {
	#careless umount "${tmp_dir}" && quietly rm -r "${tmp_dir}"
	quietly umount "${tmp_dir}" && quietly rm -r "${tmp_dir}"

	eend "${?}" "Failed to stop ${name:-"${0}"}"
}

status() {
	if ismounted "${tmp_dir}"; then
		einfo "status: mounted"
		return 0
	fi

	einfo "status: unmounted"
	return 1
}

action "${1}"

```
