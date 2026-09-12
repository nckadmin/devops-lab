#!/usr/bin/env bash
# security-audit.sh — basic security audit for a Linux host.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPORT="/tmp/security-audit-$(date +%Y%m%d_%H%M%S).txt"
{
    echo "=== Security audit: $(hostname) — $(date) ==="

    echo -e "\n--- Open ports (LISTEN) ---"
    ss -tulnp 2>/dev/null || netstat -tulnp

    echo -e "\n--- SSH configuration ---"
    grep -Ei '^(PermitRootLogin|PasswordAuthentication|Port|PermitEmptyPasswords)' /etc/ssh/sshd_config || true

    echo -e "\n--- Users with UID 0 (should be root only) ---"
    awk -F: '$3 == 0 {print $1}' /etc/passwd

    echo -e "\n--- Users able to log in with a password ---"
    awk -F: '($2 != "*" && $2 != "!" && $2 !~ /^!/) {print $1}' /etc/shadow 2>/dev/null || echo "no access to /etc/shadow (root required)"

    echo -e "\n--- Available security updates ---"
    if command -v apt >/dev/null; then
        apt list --upgradable 2>/dev/null | grep -i security || echo "no data / no updates"
    elif command -v dnf >/dev/null; then
        dnf updateinfo list security 2>/dev/null || echo "no data"
    fi

    echo -e "\n--- Failed login attempts (last 20) ---"
    grep -i "failed password" /var/log/auth.log 2>/dev/null | tail -20 || echo "log unavailable"

    echo -e "\n--- Firewall status ---"
    (ufw status 2>/dev/null) || (firewall-cmd --state 2>/dev/null) || echo "firewall not detected"

    echo -e "\n--- Root and system cron jobs ---"
    crontab -l -u root 2>/dev/null || echo "no crontab for root"
    ls -la /etc/cron.d/ 2>/dev/null

} > "$REPORT"

log_info "Audit report saved: $REPORT"
notify "Security audit completed on $(hostname -s), report: $REPORT"
cat "$REPORT"
