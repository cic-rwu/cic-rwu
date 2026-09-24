# syntax=docker/dockerfile:1
##
# Linux basics demo (2026-09-28)
#
#   docker build -t linux-basics:v0.1.1 demos/2026.09.28
#   docker run -d --name member-01 -p 2201:22 -e CIC_PASSWORD=changeme linux-basics:v0.1.1
#   ssh -p 2201 cic-guest@<host>
#
# The randomized b.1 answer is printed in the build log and saved in
# /root/cic-answers.txt (docker exec member01 cat /root/cic-answers.txt).
##
FROM debian:bookworm-slim

ARG CIC_USER=cic-guest
ENV CIC_USER=${CIC_USER}

# The README tells members to use `man`, so keep man pages (slim images strip them)
# and reinstall the core tools so their pages come back.
RUN rm -f /etc/dpkg/dpkg.cfg.d/docker \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        openssh-server procps less man-db manpages \
 && apt-get install -y --no-install-recommends --reinstall \
        coreutils findutils grep \
 && rm -rf /var/lib/apt/lists/* \
 && rm -f /etc/ssh/ssh_host_*

RUN printf '%s\n' \
        'PermitRootLogin no' \
        "AllowUsers ${CIC_USER}" \
        'PasswordAuthentication yes' \
        'KbdInteractiveAuthentication no' \
        'MaxAuthTries 5' \
        'AllowTcpForwarding no' \
        'AllowAgentForwarding no' \
        'AllowStreamLocalForwarding no' \
        'PermitTunnel no' \
        'GatewayPorts no' \
        'X11Forwarding no' \
        > /etc/ssh/sshd_config.d/cic.conf

# Bind-mounted rather than COPY'd so the script (which contains every flag), so it never exists in the image filesystem or its layers.
RUN --mount=type=bind,source=setup-flags.sh,target=/tmp/setup-flags.sh \
    bash /tmp/setup-flags.sh

COPY --chown=root:root --chmod=644 README.md /home/${CIC_USER}/README.md
COPY --chown=root:root --chmod=700 entrypoint.sh /usr/local/sbin/entrypoint.sh

EXPOSE 22
HEALTHCHECK --interval=30s --timeout=5s CMD pgrep -x sshd >/dev/null || exit 1
ENTRYPOINT ["/usr/local/sbin/entrypoint.sh"]
