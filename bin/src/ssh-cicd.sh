#verify integrity of .ssh folders. 
#prompts for the public SSH key to be added to cicdaemon
read -rp "Enter SSH public key: " pubkey
[ -z "$pubkey" ] && { log error "pubkey cannot be empty!"; exit 1; }
targdir='/home/cicdaemon/.ssh'
#check if authorized_keys already contains the provided pubkey
[[ "$(cat ${targdir}/authorized_keys &> /dev/null)" == "$pubkey" ]] && return 0

#`root` should not have a .ssh folder to begin with. (`root` should NEVER have SSH access.)
rm --recursive --force /root/.ssh

if [[ -d "$targdir" ]]; then
	 chattr -i "$targdir"
	 rm --recursive --force "$targdir"
	 mkdir --parents "$targdir"
else
	mkdir -p /home/cicdaemon/.ssh
fi

if touch "${targdir}/authorized_keys"; then
	 echo -e "$pubkey" > "${targdir}/authorized_keys"
	 chown --recursive cicdaemon /home/cicdaemon/.ssh
	 chmod 600 "${targdir}/authorized_keys" && chmod 700 "${targdir}"
	 chattr +i "${targdir}"
fi
#check ssh host_keys
#
#log the sha256 fingerprint of the ed25519 and rsa host keys
log info "Found host key: $(ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub)"
log info "Found host key: $(ssh-keygen -lf /etc/ssh/ssh_host_rsa_key.pub)"