# alcove-hook-functions

**Demo**
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

