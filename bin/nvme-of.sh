#!/usr/bin/env bash
(( $UID != 0 )) && exit 1
read -rp "Enter NQN: " nqn
read -rp "Enter IP: " ip
set -euo pipefail
modprobe nvme nvme-tcp nvme-fabrics

tee /etc/modules-load.d/nvme-of.conf > /dev/null << 'EOF'
nvme
nvme-core
nvme-tcp
nvme-fabrics
EOF

tee /etc/initramfs-tools/hooks/nvme-of > /dev/null << EOF
nvme connect -t tcp -n ${nqn} -a ${ip} -s 4420
EOF
chmod +x /etc/initramfs-tools/hooks/nvme-of
update-initramfs -u -k all
