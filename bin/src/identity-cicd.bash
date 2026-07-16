#reset and log /etc/machine-id and re-link /var/lib/dbus/machine-id to it
rm --force /etc/machine-id /var/lib/dbus/machine-id
if systemd-machine-id-setup; then
	 log info "Generated new machine id: [$(cat /etc/machine-id)]"
	if ln --symbolic /etc/machine-id /var/lib/dbus/machine-id; then
		 CIC_UUID=$( shasum --algorithm 1  /etc/machine-id | awk '{print $1}' )
		 log info "Generated CIC_UUID: [$CIC_UUID]"
		 xattr -w trusted.cicdaemon.sha1 "$CIC_UUID"
		 echo "$CIC_UUID" > /etc/cic-id
	fi
else 
	log error "Failed to symlink /etc/machine-id to /var/lib/dbus/machine-id"; exit 1
fi