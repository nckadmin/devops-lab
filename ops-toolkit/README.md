# ops-toolkit

A set of general-purpose production scripts for everyday DevOps/SysAdmin tasks:
backups, deployment, monitoring, provisioning, Docker maintenance, certificates,
database work, log rotation, security auditing, and secrets rotation.

All scripts are **templates**. Before using in production:
1. Open the script and fill in the `# ==== SETTINGS ====` block for your environment.
2. Test it on a staging environment first.
3. For backup/restore and provisioning scripts — separately verify that restoring
   actually works (a backup with unverified restore is useless).

## Structure
ops-toolkit/
├── lib/
│ └── common.sh # logging, alerts (webhook), shared checks
└── scripts/
├── backup.sh # directory backup with rotation + optional remote copy
├── healthcheck.sh # HTTP/TCP health-checks with alerts
├── deploy.sh # git deploy with health-check and auto-rollback
├── provision.sh # idempotent bootstrap for a fresh Debian/Ubuntu server
├── docker-cleanup.sh # Docker cleanup + restart unhealthy containers
├── cert-renew.sh # TLS renewal via certbot + expiry alert
├── db-backup-restore.sh # PostgreSQL/MySQL backup/restore with checksum
├── logrotate-cleanup.sh # manual log rotation + disk usage check
├── security-audit.sh # basic audit: ports, SSH, updates, firewall, cron
└── secrets-rotate.sh # SSH key rotation across hosts with pre-revoke check


## General notes

- All scripts use `set -euo pipefail` and the shared `lib/common.sh` module
  (`log_info`/`log_warn`/`log_error`, `die`, `notify`, `require_root`, `require_cmd`).
- Alerts are sent via webhook (Slack/Telegram/Discord/Mattermost) —
  set the `ALERT_WEBHOOK_URL` environment variable, otherwise notifications are skipped.
- Logs are written to `/var/log/devops-lab.log` by default (`LOG_FILE`).
- Never hardcode passwords or keys in the scripts — pass them via environment
  variables or a secrets manager (Vault, etc.).

## Scheduling (cron example)


## License

Personal/work toolkit. Use and adapt to your own infrastructure as needed.
