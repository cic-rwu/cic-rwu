#!/bin/sh
machine_id(){
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