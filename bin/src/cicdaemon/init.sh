#!/bin/bash
set -o errexit
set -o pipefail
HELPMSG=$(cat <<'HELPMSG'
cicdaemon init -- Initialize cicdaemon on new hosts
USAGE
  cicdaemon init {*SUBSYSTEM} ...
DESCRIPTION
	**cicdaemon init** initializes `cicdaemon` on newly provisioned hosts

	If the host you are trying to provision did not come from the PVE template,
	this script may not work as expected, but it is intended to.
	For full usage, run `man cicdaemon`

	If you have issues, please report them on the github repository at:
	https://github.com/cic-rwu/cic-rwu/tree/cicdaemon

AUTHOR
	https://github.com/mxhml

cicdaemon-init dev-1.0.3
HELPMSG
)
finish(){
	local result=$?
	rm --force "$TMP_FILE"
	ELAPSED=$((($(date +%s%N) - $START_TIME)/1000000))
	echo "Finished in ${ELAPSED}ms"
	exit ${result}
}
trap finish EXIT ERR
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
START_TIME=$(date +%s%N)
TMP_FILE="$(mktemp)"

init() {
	[ "${EUID}" -ne 0 ] && echo "cicdaemon-init: Bad permissions. Are you root?" && exit 1
	if mkdir --parents /opt/cicdaemon/log /opt/cicdaemon/bin 2> "${TMP_FILE}"; then
		:
	else
		echo -e "cicdaemon-init: failed to initialize required directories.\nstderr dump:"
		cat "${TMP_FILE}"
	fi

	. "${SCRIPT_DIR}/machine_id.sh"


	generate-hostkeys() {
		if rm --force /etc/ssh/ssh_host_*; then
			if ssh-keygen -A; then
				echo "generate-hostkeys: OK"
				echo "host ED25519 fingerprint:"
				ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
				echo "generate-hostkeys: OK"
				return 0
			fi
		fi
	}

	if machine-id; then if copy-daemon-hostkey; then generate-hostkeys; fi;fi
}; init "$@"

[[ ${#} -gt 0 || "${1}" == "-h" || "${1}" == "--help" ]] && {
	echo "cicdaemon-init: too many arguments recieved! expected 0, but got ${#}"
	echo "${HELPMSG}"
	exit 2
}