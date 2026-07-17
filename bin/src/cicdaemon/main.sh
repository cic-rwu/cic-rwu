#!/bin/bash
#this script is intended to be run AFTER bin/src/cicdaemon-init.sh
#this is the main orchestrator script, and should (generally) never
#be ad-hoc modified locally
#
#if you want to change how a specific subsystem works, modify the BASH source directly
#this script assumes there is an internet connection, most likely via the PVE hosts
#vmbr0 interface.
HELPMSG=$( cat <<'HELPMSG'
cicdaemon -- CIC host management and compliance daemon
USAGE
  cicdaemon *SUBSYSTEM* [*SUBSYSTEM* [*SUBSYSTEM*]...]
DESCRIPTION
	**cicdaemon** is an orchestrator script for a **HOST**'s given **SUBSYSTEM**, 
	like its *identity*, *network*, *dns*, *time*, *ssh*, and so on. 

#$0
#https://github.com/mxhml
#https://github.com/cic-rwu/cic-rwu
cicdaemon dev-1.0.0
HELPMSG
)
set -o errexit
set -o pipefail
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