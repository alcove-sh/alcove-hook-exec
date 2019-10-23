# Copyright (C) 2018-2019 Alcove Project Authors.

#
# Maintainer: urain39 <urain39[AT]qq[DOT]com>
#

##################################################
# Constants
##################################################

readonly COLOR_RESET="\033[0m"
readonly COLOR_BOLD_RED="\033[1;31m"
readonly COLOR_BOLD_GREEN="\033[1;32m"
readonly COLOR_BOLD_YELLOW="\033[1;33m"

#readonly CURSOR_BEGIN="\r"
#readonly CURSOR_BEGIN_CLEAR="\r\033[K"
readonly CURSOR_GOTO="\033[%d;%dH"

##################################################
# User's Variables
##################################################

: "${command:=""}"
: "${command_args:=""}"
: "${command_user:="nobody:nobody"}"
: "${pidfile:=""}"
: "${start_stop_daemon_args:=""}"

##################################################
# Hack for Shell
##################################################

__hack_environ__() {
	if [ -z "${COLUMNS}" ] && [ -z "${LINES}" ]; then
		eval "$(resize)"
	fi
}

__hack_stdout__() {
	__hack_environ__

	printf "\033[%d;0H" "${LINES}"
}

# __hack_xxxxxx__() {
# 	your compat hack
# }

##################################################
# Common Functions
##################################################

ebegin() {
	printf " ${COLOR_BOLD_GREEN}*${COLOR_RESET} %s ...\n" "${*}"
}

einfo() {
	printf " ${COLOR_BOLD_GREEN}*${COLOR_RESET} %s\n" "${*}"
}

ewarn() {
	printf " ${COLOR_BOLD_YELLOW}*${COLOR_RESET} %s\n" "${*}"
}

eerror() {
	printf " ${COLOR_BOLD_RED}*${COLOR_RESET} %s\n" "${*}"
}

eend() {
	# exit codes
	#	0:	ok
	#	1:	fail

	[ "${#}" -lt 1 ] && exit 0

	local status="${1}"

	shift # skip status

	# for ash & dash
	__hack_environ__

	# NOTE: `stat="[ ok ]"; echo "${#stat}"` -> 6

	if [ "${status}" = "0" ]; then
		printf "${CURSOR_GOTO}[ ${COLOR_BOLD_GREEN}ok${COLOR_RESET} ]\n" \
			"$((LINES - 1))" "$((COLUMNS - 6))"
	else
		if [ -n "${*}" ]; then
			eerror "${*}"
			printf "${CURSOR_GOTO}[ ${COLOR_BOLD_RED}!!${COLOR_RESET} ]\n" \
				"$((LINES - 1))" "$((COLUMNS - 6))"

			exit 1
		else
			printf "${CURSOR_GOTO}[ ${COLOR_BOLD_RED}!!${COLOR_RESET} ]\n" \
				"$((LINES - 1))" "$((COLUMNS - 6))"

			exit 1
		fi
	fi

	exit 0
}

yesno() {
	# return codes
	#	0:	ok
	#	1:	fail

	[ "${#}" -lt 1 ] && return 1

	local value="${1}"

	# Check the value directly so people can do:
	# yesno ${VAR}

	case "${value}" in
		[Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|[Oo][Nn]|1)
			return 0
			;;
		#[Nn][Oo]|[Ff][Aa][Ll][Ss][Ee]|[Oo][Ff][Ff]|0)
		#	return 1
		#	;;
	esac

	return 1
}

noyes() { :; }

start_pre() { :; }

start() {
	local _background=""

	ebegin "Starting ${name:-"${0}"}"

	if yesno "${command_background}"; then
		if [ -z "${pidfile}" ]; then
			eend 1 "command_background option requires a pidfile"
		fi

		if [ -z "${command_args_background}" ]; then
			eend 1 "command_background option requires a command_args_background"
		fi

		_background="--background --make-pidfile"
	fi

	[ -n "${output_logger}" ] &&
		output_logger_arg="--stdout-logger \"${output_logger}\""
	[ -n "${error_logger}" ] &&
		error_logger_arg="--stderr-logger \"${error_logger}\""

	start_pre && \
	# the eval call is necessary for cases like:
	# command_args="this \"is a\" test"
	# to work properly.
	eval "start-stop-daemon --start \
		--exec ${command} \
		${chroot:+--chroot} ${chroot} \
		${directory:+--chdir} ${directory} \
		${output_log+--stdout} ${output_log} \
		${error_log+--stderr} ${error_log} \
		${output_logger_arg} \
		${error_logger_arg} \
		${procname:+--name} ${procname} \
		${pidfile:+--pidfile} ${pidfile} \
		${command_user+--user} ${command_user} \
		${umask+--umask} ${umask} \
		${_background} ${start_stop_daemon_args} \
		-- ${command_args} ${command_args_background} \
		" && start_post

	eend "${?}" "Failed to start ${name:-"${0}"}"
}

start_post() { :; }

stop_pre() { :; }

stop() {
	local _progress=""

	ebegin "Stopping ${name:-"${0}"}"

	yesno "${command_progress}" && _progress="--progress"

	stop_pre && \
	eval "start-stop-daemon --stop \
		${retry:+--retry} ${retry} \
		${command:+--exec} ${command} \
		${procname:+--name} ${procname} \
		${pidfile:+--pidfile} ${chroot}${pidfile} \
		${stopsig:+--signal} ${stopsig} \
		${_progress} \
		" && stop_post 

	eend "${?}" "Failed to stop ${name:-"${0}"}"
}

stop_post() { :; }

status() {
	# return codes
	#	0:	running
	#	1:	stopped
	#	2:	crashed

	# XXX:
	if [ -f "${pidfile}" ]; then
		while read -r pid; do
			if [ -d "/proc/${pid}" ]; then
				einfo "status: running"
				return 0
			fi

			eerror "status: crashed"
			return 2
		done < "${pidfile}"
	fi

	einfo "status: stopped"
	return 1
}

restart() {
	stop && start
}

reload() { :; }

action() {
	local action="${1}"

	case "${action}" in
		"start")
			start
			;;
		"stop")
			stop
			;;
		"reload")
			reload
			;;
		"restart")
			restart
			;;
		"status")
			status
			;;
		*)
			einfo "Usage: <start|stop|reload|restart|status>"
			;;
	esac
}


##################################################
# Apply Pre-hacks
##################################################

__hack_environ__
__hack_stdout__

##################################################
# Apply Pre-checks
##################################################

if [ -z "${command}" ]; then
	ewarn "\${command} is empty or not set!"
fi

if [ -z "${pidfile}" ]; then
	ewarn "\${pidfile} is empty or not set!"
fi

