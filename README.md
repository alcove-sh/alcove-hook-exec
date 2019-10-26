# alcove-hook-functions

**TODO:**
- [x] checkpath dir test
- [x] checkpath file test
- [ ] checkpath pipe test
- [ ] checkpath correct test

**Examples:**
```sh
#!/bin/sh

command="/usr/sbin/sshd"

. /alcove-hooks/00-common.in

stop_post() {
	# Kill all ssh connections.
	pgrep "^${command##*/}" | xargs -r kill -s 15
}


action "${1}"
```

```sh
#!/bin/sh

owner=":www-data"
tmp_dir=/opt/tmp

#set -x

. /alcove-hooks/00-common.in

start() {
	mount -t tmpfs tmpfs "${tmp_dir}"
	checkpath -d -m1777 -o "${owner}" "${tmp_dir}"

	eend "${?}" "Failed to start ${nmae:-"${0}"}"
}

stop() {
	careless umount "${tmp_dir}" && quietly rm -r "${tmp_dir}"
	#quietly umount "${tmp_dir}" && quietly rm -r "${tmp_dir}"

	eend "${?}" "Failed to stop ${name:-"${0}"}"
}

status() {
	if ismounted "${tmp_dir}"; then
		einfo "status: mounted"
		return 0
	fi

	einfo "statis: unmounted"
	return 1
}

action "${1}"
```
