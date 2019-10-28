# Copyright (c) 2018-2019 The Alcove Project Authors.
#
# Maintainer: urain39 <urain39[AT]qq[DOT]com>
#
# Requirements: awk chmod chown grep mkdir mkfifo
#		resize stat start-stop-daemon touch
#
# For debug:
#	alias exit='not echo "exited with"'
#	export readonly USER="root"
#	alias readonly=''

##################################################
# Constants
##################################################

# shellcheck disable=SC2034
readonly __VERSION__="1"

readonly COLOR_RESET="\033[0m"
readonly COLOR_BOLD_RED="\033[1;31m"
readonly COLOR_BOLD_GREEN="\033[1;32m"
readonly COLOR_BOLD_YELLOW="\033[1;33m"
readonly COLOR_BOLD_BLUE="\033[1;34m"

#readonly CURSOR_BEGIN="\r"
#readonly CURSOR_BEGIN_ERASE="\r\033[K"
readonly CURSOR_GOTO="\033[%d;%dH"

##################################################
# User's Variables
##################################################

: "${command:=""}"
: "${command_args:=""}"
: "${command_user:="root:root"}"
: "${pidfile:=""}"
: "${start_stop_daemon_args:=""}"

##################################################
# Hack for Shell
##################################################

__hack_environ__() {
	careless eval "$(resize)"
}

__hack_stdout__() {
	__hack_environ__
	printf "\033[%d;1H" "${LINES}"
}

# __hack_xxxxxx__() {
# 	your compat hack
# }

##################################################
# Common Functions
##################################################

____checkstatus____() {
	# return codes
	#	0:	ok
	#	1:	fail

	local _path="${1}"
	local _mode="${2}"
	local _owner="${3}"
	local _status=""

	if not isempty "${_mode}"; then
		_status="$(stat -c "%04a" "${_path}")"
		#_status="${_status// /}"

		if [ "${_status}" != "${_mode}" ]; then
			einfo "${_path}: correcting mode"
			quietly chmod "${_mode}" "${_path}"

			if not issuccess; then
				eend 1
				return 1
			fi
		fi
	fi

	if not isempty "${_owner}"; then
		_status="$(stat -c "%U:%G" "${_path}")"
		#_status="${_status// /}"

		if [ "${_status}" != "${_owner}" ]; then
			einfo "${_path}: correcting owner"
			quietly chown "${_owner}" "${_path}"

			if not issuccess; then
				eend 1
				return 1
			fi
		fi
	fi
}

action() {
	# return codes
	#	0:	ok
	#	1:	fail

	local _action="${1}"

	case "${_action}" in
		"start")
			start_pre && \
				start && start_post
			;;
		"stop")
			stop_pre && \
				stop && start_post
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

checkpath() {
	# return codes
	#	0:	ok
	#	1:	fail

	local _option=""
	local _option_mode=""
	local _truncate="no"
	local _umask_old=""
	local _mode=""
	local _owner=""
	local _path=""
	local _retval="0"

	local OPTIND="1"
	local OPTARG=""

	_umask_old="$(umask)"

	umask 002

	while getopts 'dDfFpm:o:W' _option; do
		case "${_option}" in
			"d")
				_option_mode="d"
				;;
			"D")
				_option_mode="d"
				_truncate="yes"
				;;
			"f")
				_option_mode="f"
				;;
			"F")
				_option_mode="f"
				_truncate="yes"
				;;
			"p")
				_option_mode="p"
				;;
			"m")
				_mode="$(
					echo "${OPTARG}" | awk -F'[ \t]+' '{
						if (NF == 1) {
							if ($1 ~ /[0-7]{3,4}/) {
								printf("%04d", $1)
								exit(0)
							}
						}
						exit(1)
					}'
				)"

				if not issuccess; then
					eerror "checkpath: invalid mode '${OPTARG}'!"
					_retval="1"
					break
				fi
				;;
			"o")
				_owner="$(
					echo "${OPTARG}" | awk -F':' '{
						if (NF == 2) {
							printf("%s:%s", $1, $2)
						} else if (NF == 1) {
							printf("%s:%s", $1, $1)
						} else {
							exit(1)
						}
						exit(0)
					}'
				)"

				if not issuccess; then
					eerror "checkpath: invalid owner '${OPTARG}'!"
					_retval="1"
					break
				fi
				;;
			"W")
				_option_mode="W"
				;;
		esac
	done

	if [ "${_retval}" != 0 ]; then
		eend 1 "checkpath: parse arguments failed"
		umask "${_umask_old}"
		return "${_retval}"
	fi

	shift "$((OPTIND - 1))"

	for _path in "${@}"; do
		case "${_option_mode}" in
			"d")
				if yesno "${_truncate}"; then
					einfo "${_path}: truncating directory"
					quietly rm -r "${_path}"

					if not issuccess; then
						eend 1
						_retval="1"
						break
					fi
				fi

				if not isdirectory "${_path}"; then
					einfo "${_path}: creating directory"
					quietly mkdir "${_path}"

					if not issuccess; then
						eend 1
						_retval="1"
						break
					fi
				fi

				____checkstatus____ "${_path}" "${_mode}" "${_owner}"
				;;
			"f")
				if yesno "${_truncate}"; then
					einfo "${_path}: truncating file"
					quietly eval ": > \"${_path}\""

					if not issuccess; then
						eend 1
						_retval="1"
						break
					fi
				fi

				if not isfile "${_path}"; then
					einfo "${_path}: creating file"
					quietly touch "${_path}"

					if not issuccess; then
						eend 1
						_retval="1"
						break
					fi
				fi

				____checkstatus____ "${_path}" "${_mode}" "${_owner}"
				;;
			"p")
				if not ispipe "${_path}"; then
					einfo "${_path}: creating pipe"
					quietly mkfifo "${_path}"

					if not issuccess; then
						eend 1
						_retval="1"
						break
					fi
				fi

				____checkstatus____ "${_path}" "${_mode}" "${_owner}"
				;;
			"W")
				if isexists "${_path}"; then
					if isdirectory "${_path}"; then
						quietly touch "${_path}/.writable${$}" && \
							quietly rm "${_path}/.writable${$}"
					else
						quietly mv "${_path}" "${_path}.writable${$}" && \
							quietly mv "${_path}.writable${$}" "${_path}"
					fi

					if issuccess; then
						break
					fi
				fi

				eend 1
				_retval="1"
				break
				;;
		esac
	done

	umask "${_umask_old}"

	eend "${_retval}" "checkpath: apply changes failed"
	return "${_retval}"
}

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
	# return codes
	#	0:	ok
	#	1:	fail

	[ "${#}" -lt 1 ] && return 0

	local _status="${1}"

	shift # skip _status

	# for ash & dash
	__hack_environ__

	# NOTE: `stat="[ ok ]"; echo "${#stat}"` -> 6

	if [ "${_status}" = "0" ]; then
		printf "${CURSOR_GOTO}${COLOR_BOLD_BLUE}[ ${COLOR_BOLD_GREEN}ok ${COLOR_BOLD_BLUE}]${COLOR_RESET}\n" \
			"$((LINES - 1))" "$((COLUMNS - 5))"
	else
		if not isempty "${*}"; then
			eerror "${*}"
			printf "${CURSOR_GOTO}${COLOR_BOLD_BLUE}[ ${COLOR_BOLD_RED}!! ${COLOR_BOLD_BLUE}]${COLOR_RESET}\n" \
				"$((LINES - 1))" "$((COLUMNS - 5))"

			return 1
		else
			printf "${CURSOR_GOTO} ${COLOR_BOLD_RED}*${COLOR_RESET}" \
				"$((LINES - 1))" "1"
			printf "${CURSOR_GOTO}${COLOR_BOLD_BLUE}[ ${COLOR_BOLD_RED}!! ${COLOR_BOLD_BLUE}]${COLOR_RESET}\n" \
				"$((LINES - 1))" "$((COLUMNS - 5))"

			return 1
		fi
	fi

	return 0
}

quietly() {
	"${@}" > /dev/null 2>&1
}

careless() {
	"${@}" > /dev/null 2>&1
	return 0
}

shouldbe() {
	# return codes
	#	0:	matched
	#	1:	not match

	[ "${#}" -lt 2 ] && return 1

	local _shouldbe="${1}"
	local _result=""

	shift # skip _shouldbe
	_result="$("${@}" 2> /dev/null)"

	if [ "${_result}" = "${_shouldbe}" ]; then
		return 0
	fi

	eend 1 "shouldbe: expected '${_shouldbe}', but found '${_result}'"
	return 1
}

is() {
	"${@}" && return 0 \
		|| return 1
}

not() {
	"${@}" && return 1 \
		|| return 0
}

isempty() {
	# return codes
	#	0:	empty
	#	1:	not empty

	#[ "${#}" -lt 1 ] && return 1

	if [ -z "${*}" ]; then
		return 0
	fi

	return 1
}

isexists() {
	# return codes
	#	0:	exists
	#	1:	not exists

	#[ "${#}" -lt 1 ] && return 1

	if [ -e "${*}" ]; then
		return 0
	fi

	return 1
}

isfile() {
	# return codes
	#	0:	file
	#	1:	not file

	#[ "${#}" -lt 1 ] && return 1

	if [ -f "${*}" ]; then
		return 0
	fi

	return 1
}

ispipe() {
	# return codes
	#	0:	pipe
	#	1:	not pipe

	#[ "${#}" -lt 1 ] && return 1

	if [ -p "${*}" ]; then
		return 0
	fi

	return 1
}

isdirectory() {
	# return codes
	#	0:	directory
	#	1:	not directory

	#[ "${#}" -lt 1 ] && return 1

	if [ -d "${*}" ]; then
		return 0
	fi

	return 1
}

issuccess() {
	# return codes
	#	0:	success
	#	1:	failed

	if [ "${?}" = 0 ]; then
		return 0
	fi

	return 1
}

ismounted() {
	# return codes
	#	0:	mounted
	#	1:	unmounted

	local _path="${1}"

	# shellcheck disable=SC2016
	quietly awk -F'[ \t]+' \
	-v "path=${_path}" '\
	BEGIN {
		found = 0
	} {
		gsub(/\\040/, " ", $2)
		if ($2 == path) {
			found = 1
			exit(0)
		}
	} END {
		if (found) {
			exit(0)
		}
		exit(1)
	}
	' "/proc/${$}/mounts"

	if issuccess; then
		return 0
	else
		return 1
	fi
}

yesno() {
	# return codes
	#	0:	yes
	#	1:	no

	[ "${#}" -lt 1 ] && return 1

	local _value="${1}"

	# Check the _value directly so people can do:
	# yesno ${VAR}

	case "${_value}" in
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

##################################################
# Default Actions
##################################################

start_pre() { :; }

start() {
	local _background=""

	ebegin "Starting ${name:-"${0}"}"

	if isempty "${command}"; then
		ewarn "WARNING: \${command} is empty or not set!"
	fi

	# shellcheck disable=SC2154
	if yesno "${command_background}"; then
		if isempty "${pidfile}"; then
			eend 1 "command_background option requires a pidfile"
			return 1
		fi

		# shellcheck disable=SC2154
		if not isempty "${command_args_background}"; then
			eend 1 "command_background option used with command_args_background"
			return 1
		fi

		# shellcheck disable=SC2034
		_background="--background --make-pidfile"
	fi

	# shellcheck disable=SC2034,SC2154
	not isempty "${output_logger}" && \
		output_logger_arg="--stdout-logger \"${output_logger}\""
	# shellcheck disable=SC2034,SC2154
	not isempty "${error_logger}" && \
		error_logger_arg="--stderr-logger \"${error_logger}\""

	# shellcheck disable=SC2154
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
		"

	eend "${?}" "Failed to start ${name:-"${0}"}"
}

start_post() { :; }

stop_pre() { :; }

stop() {
	local _progress=""

	ebegin "Stopping ${name:-"${0}"}"

	# shellcheck disable=SC2154
	yesno "${command_progress}" && _progress="--progress"

	# shellcheck disable=SC2154
	eval "start-stop-daemon --stop \
		${retry:+--retry} ${retry} \
		${command:+--exec} ${command} \
		${procname:+--name} ${procname} \
		${pidfile:+--pidfile} ${chroot}${pidfile} \
		${stopsig:+--signal} ${stopsig} \
		${_progress} \
		"

	eend "${?}" "Failed to stop ${name:-"${0}"}"
}

stop_post() { :; }

status() {
	# return codes
	#	0:	running
	#	1:	stopped
	#	2:	crashed

	local _pid=""

	if isfile "${pidfile}"; then
		while read -r _pid; do
			if isdirectory "/proc/${_pid}"; then
				if quietly grep "${command}" "/proc/${_pid}/cmdline"; then
					einfo "status: running"
					return 0
				fi
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

##################################################
# Apply Pre-hacks
##################################################

__hack_environ__
__hack_stdout__

##################################################
# Apply Pre-checks
##################################################

if [ "${USER}" != "root" ]; then
	eend 1 "ERROR: requires root to manage daemons!"
	exit 1
fi

