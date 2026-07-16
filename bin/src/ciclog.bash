#!/bin/bash

HELPMSG=$( cat <<'HELPMSG'
USAGE
  $0 [LEVEL] [message]... {*file* ...}

DESCRIPTION
  prepend and format <\${EPOCHREALTIME}>, <\${FUNCNAME[1]}> to LEVEL [message]...

NOTES
  This script is inteded to be sourced, and not run directly

  #cic-rwu/bin/ciclog
  #https://github.com/cic-rwu/cic-rwu
  ciclog v1.0.5
HELPMSG
)

ciclog() {
  local caller="${FUNCNAME[1]}"
  local calltime="${EPOCHREALTIME}"
  local label="${1}"
  local message="${2}"
  local format="[%s] %s: [%s]: %s"
  
  printf "${format}" "${calltime}" "${caller}" "${label}" "${message}"
};
ciclog "$@"