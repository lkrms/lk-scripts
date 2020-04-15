#!/bin/bash
# <UDF name="NODE_HOSTNAME" label="Hostname" />
# <UDF name="NODE_TIMEZONE" label="Timezone" default="Australia/Sydney" />
# <UDF name="ADMIN_USERNAME" label="Admin username" default="linac" />

set -euo pipefail

# set hostname
hostnamectl set-hostname "$NODE_HOSTNAME"

# set timezone
timedatectl set-timezone "$NODE_TIMEZONE"

# create admin user
useradd --create-home --groups adm,sudo --shell /bin/bash "$ADMIN_USERNAME"
echo "$ADMIN_USERNAME ALL=(ALL) NOPASSWD:ALL" >"/etc/sudoers.d/nopasswd-$ADMIN_USERNAME"
mv /root/.ssh "/home/$ADMIN_USERNAME/"
chown -R "$ADMIN_USERNAME": "/home/$ADMIN_USERNAME/.ssh"

# lock root user
passwd -l root

# update everything
apt-get update
apt-get dist-upgrade -y
