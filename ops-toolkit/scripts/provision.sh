#!/usr/bin/env bash
# provision.sh — basic idempotent bootstrap for a fresh Linux server (Debian/Ubuntu).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
require_root

# ==== SETTINGS ====
PACKAGES=(curl git vim htop ufw fail2ban unattended-upgrades)
NEW_USER="deploy"
SSH_PUBKEY="ssh-ed25519 AAAA...your-key... user@host"
SSH_PORT=2222
ALLOWED_TCP_PORTS=(80 443)
# ===================

log_info "Updating packages"
apt-get update -qq && apt-get upgrade -y -qq

log_info "Installing base packages: ${PACKAGES[*]}"
apt-get install -y -qq "${PACKAGES[@]}"

if ! id "$NEW_USER" &>/dev/null; then
    log_info "Creating user $NEW_USER"
    useradd -m -s /bin/bash -G sudo "$NEW_USER"
    mkdir -p "/home/$NEW_USER/.ssh"
    echo "$SSH_PUBKEY" > "/home/$NEW_USER/.ssh/authorized_keys"
    chown -R "$NEW_USER:$NEW_USER" "/home/$NEW_USER/.ssh"
    chmod 700 "/home/$NEW_USER/.ssh"
    chmod 600 "/home/$NEW_USER/.ssh/authorized_keys"
else
    log_info "User $NEW_USER already exists, skipping"
fi

log_info "Hardening SSH (port $SSH_PORT, disable root and password login)"
sed -i -E \
    -e "s/^#?Port .*/Port ${SSH_PORT}/" \
    -e 's/^#?PermitRootLogin .*/PermitRootLogin no/' \
    -e 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' \
    /etc/ssh/sshd_config
systemctl restart sshd

log_info "Configuring firewall (ufw)"
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow "${SSH_PORT}/tcp"
for port in "${ALLOWED_TCP_PORTS[@]}"; do
    ufw allow "${port}/tcp"
done
ufw --force enable

log_info "Enabling fail2ban and unattended-upgrades"
systemctl enable --now fail2ban
dpkg-reconfigure -f noninteractive unattended-upgrades

log_info "Server provisioning completed"
