#!/usr/bin/env bash
##[2026.09.28/entrypoint]
# set the member password and start the bonus unit
#
#Env:
#  CIC_PASSWORD     password to use for the *CIC_USER* account
#                   if unset, auto-generated password can be found in the docker logs
##

CIC_USER="${CIC_USER:-cic-guest}"

if [[ -z "${CIC_PASSWORD:-}" ]]; then
    CIC_PASSWORD=$(tr -dc 'a-z0-9' < /dev/urandom | head -c 10)
    echo "[entrypoint] generated password for ${CIC_USER}: ${CIC_PASSWORD}"
fi
echo "${CIC_USER}:${CIC_PASSWORD}" | chpasswd
unset CIC_PASSWORD

# unique SSH host keys per container
ssh-keygen -A >/dev/null

# no systemd in the container, so run the bonus service's ExecStart directly.
read -ra bonus_cmd <<< "$(sed -n 's/^ExecStart=//p' /etc/systemd/system/bonus-flag.service)"
runuser -u nobody -- "${bonus_cmd[@]}" &

mkdir -p /run/sshd
exec /usr/sbin/sshd -D -e
