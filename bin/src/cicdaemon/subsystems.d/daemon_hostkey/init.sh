#!/bin/bash
init() {
  local targdir="/opt/cicdaemon/.ssh"
  #prompts for the public SSH key to be added to cicdaemon
  pubkey="$(read -rp "Enter SSH public key: " | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')"
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
};init