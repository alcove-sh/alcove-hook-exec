
command="/usr/sbin/sshd"
pidfile="/var/run/sshd.pid"

. common.in

stop_post() {
	# Kill all ssh connections.
	pgrep "^${command##*/}" | xargs -r kill -s 15
}

action "${1}"

