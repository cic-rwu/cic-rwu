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
	result=$?
	rm --force "$TMPFILE"
	ELAPSED=$((($(date +%s%N) - $START_TIME)/1000000))
	echo "Finished in ${ELAPSED}ms"
	exit ${result}
}
trap finish EXIT ERR
START_TIME=$(date +%s%N)
TMPFILE="$(mktemp)"

init() {
	[ "${EUID}" -ne 0 ] && echo "cicdaemon-init: Bad permissions. Are you root?" && exit 1
	if mkdir --parents /opt/cicdaemon/log /opt/cicdaemon/bin 2> "${TMPFILE}"; then
		:
	else
		echo -e "cicdaemon-init: failed to initialize required directories.\nstderr dump:"
		cat "${TMPFILE}"
	fi

	machine-id(){
		#reset and log /etc/machine-id and re-link /var/lib/dbus/machine-id to it
		rm --force /etc/machine-id /var/lib/dbus/machine-id
		if systemd-machine-id-setup; then
			echo "Generated new machine id: [$(cat /etc/machine-id)]"
			if ln --symbolic /etc/machine-id /var/lib/dbus/machine-id; then
				CIC_UUID=$( shasum --algorithm 1  /etc/machine-id | awk '{print $1}' )
				echo "Generated CIC_UUID: [$CIC_UUID]"
				xattr -w trusted.cicdaemon.sha1 "$CIC_UUID"
				echo "$CIC_UUID" > /etc/cic-id
				chattr -i /etc/cic-id
				echo "machine-id: OK"
				return 0
			fi
		else 
			echo "Failed to symlink /etc/machine-id to /var/lib/dbus/machine-id"; return 1
		fi
	}

	copy-daemon-hostkey() {
		local targdir="/opt/cicdaemon/.ssh"
		#prompts for the public SSH key to be added to cicdaemon
		read -rp "Enter SSH public key: " pubkey
		[ -z "$pubkey" ] && { log error "pubkey cannot be empty!"; exit 1; }
		targdir='/home/cicdaemon/.ssh'
		#remove the old .ssh directory entirely
		if [[ -d "$targdir" ]]; then
			chattr -i "$targdir"
			rm --recursive --force "$targdir"
			mkdir --parents "$targdir"
		fi
		mkdir -p /opt/cicdaemon/.ssh
		if touch "${targdir}/authorized_keys"; then
			echo -e "$pubkey" > "${targdir}/authorized_keys"
			chown --recursive cicdaemon /home/cicdaemon/.ssh
			chmod 600 "${targdir}/authorized_keys" && chmod 700 "${targdir}"
			chattr +i "${targdir}"
			echo "copy-daemon-hostkey: OK"
			return 0
		fi
	}

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