#!/bin/bash
#==========================================================
#
#       FILE:           bin/cicdaemon
#       USAGE:          cicdaemon bootstrap
#       DESCRIPTION:    Script to automate bootstrapping host configurations
#
#       AUTHOR:         MXHML (mxhml@proton.me)
#       VERSION:        1.0.2
#       CREATED:        July 14, 2026
#       REVISION:       1
#
#==========================================================
set -o errexit
set -o pipefail
if [[ "$1" == "-h" || "$1" == "--help" ]]; then cat <<HELPMSG
cicdaemon -- CIC host management and compliance daemon
USAGE
  cicdaemon < *COMMAND* > [ *OPTION* ] [ *HOST* ... ] < *SUBSYSTEM* > ...
DESCRIPTION
	**cicdaemon** is an orchestrator script for a **HOST**'s given **SUBSYSTEM**, 
	like its *identity*, *network*, *dns*, *time*, *ssh*, and so on. 

#$0
#https://github.com/mxhml
#https://github.com/cic-rwu/cic-rwu
ciclog v1.0.4
HELPMSG
unset HELPMSG; return 0
else
finish(){
	result=$?
	rm --recursive --force "$tmpdir"
	ELAPSED=$((($(date +%s%N) - $START_TIME)/1000000))
	echo "Finished in ${ELAPSED}ms"
	exit ${result}
}
trap finish EXIT ERR
START_TIME=$(date +%s%N)
declare -r 		SCRIPT_DIR="$(cd -P "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
declare -r		WORK_DIR="/opt/cicdaemon"
declare -r 		LOG_DIR="/var/log/cicdaemon"
declare -r		tmpdir="$(mktemp -d)"
source "${SCRIPT_DIR}/ciclog.bash"
set -o nounset #ciclog allows for no args to be passed.
log info "Initializing cicdaemon..."
#=======================
#Check the permissions of the user running the script to see if they have the proper permissions
#based on EUIDs.
#
#Return 0 for OK, 1 for bad permissions/general error
expectedUser(){
	case "${EUID}" in
	"${1}") 
		return 0 
	;;
	0)
		return 0 
	;;
	777)
		return 0 
	;;
	*)
		log error "Bad permissions check. Are you root?"
		return 1
	;;
	esac
}
#cicdaemon init
init(){
	#check if a directory exists. if not, create it with --parents
	#if it exists, print the output of stat(1) and return 0
	checkDir(){
		for dir in "$@"; do
			if [[ ! -d "${dir}" ]]; then
				log info "Creating directory \`${1}\`"
				if mkdir --parents "${1}" 2>"${tmpdir}/2"; then
					log info "Success"
					return 0
				else
					log error "Failed to create directory: stderr: $(cat ${tmpdir}/2)"
				fi
			#if we were given a path that exists
			elif [[ -e "${dir}" ]]; then
				log info "Directory exists:\n$(stat ${dir})"
				return 0
			else
				log error "Bad path"
			fi
		done
	}
	if checkDir /usr/libexec/cicdaemon/subsystems /etc/cicdaemon /var/log/cicdaemon /var/lib/cicdaemon;
	then echo "${EPOCHREALTIME} initialized" >> /var/lib/cicdaemon/init.done;
	fi
	log info "OK."
};init
fi