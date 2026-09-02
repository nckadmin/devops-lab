# DevOps Home Lab

An end-to-end home infrastructure project built to demonstrate practical DevOps skills: Infrastructure as Code, configuration management, container orchestration, CI/CD, GitOps, observability, and secrets management — all self-hosted on local hardware.

## Architecture

```mermaid
flowchart TB
    subgraph Host["Windows Host (Hyper-V)"]
        Packer["Packer<br/>Golden Image Builder"]
        Terraform["Terraform<br/>Infrastructure Provisioning"]
        Ansible["Ansible<br/>Configuration Management (via WSL)"]

        subgraph K3s["k3s Cluster"]
            Ctrl["ctrl-01<br/>control-plane"]
            Worker["worker-01<br/>worker node"]

            subgraph Apps["Deployed via kubectl/Helm"]
                Gitea["Gitea + act_runner<br/>CI"]
                ArgoCD["ArgoCD<br/>GitOps / CD"]
                Monitoring["Prometheus + Grafana<br/>+ Alertmanager"]
                Demo["demo-nginx<br/>sample app"]
            end
        end

        VaultVM["vault-01<br/>HashiCorp Vault<br/>(standalone VM)"]
    end

    Packer -->|golden image| Terraform
    Terraform -->|provisions 4 VMs| Ctrl
    Terraform -->|provisions| Worker
    Terraform -->|provisions| VaultVM
    Ansible -->|hardens SSH, bootstraps k3s| Ctrl
    Ansible -->|joins cluster| Worker
    Gitea -->|webhook / push| ArgoCD
    ArgoCD -->|auto-sync| Demo
    Monitoring -->|scrapes metrics| K3s
```

## Tech Stack & Rationale

| Layer | Tool | Why |
|---|---|---|
| Image building | Packer | Bakes a single, hygienic Ubuntu 22.04 golden image (autoinstall, cloud-init cleaned, host keys stripped) so every VM starts from the same known-good state |
| Provisioning | Terraform | Clones the golden image into differencing disks and creates 4 Hyper-V VMs declaratively; state-driven, fully reproducible |
| Configuration | Ansible | SSH hardening (key-only auth, no root login) and k3s cluster bootstrap, driven from a WSL control node |
| Orchestration | k3s | Lightweight Kubernetes distribution — full core functionality with a fraction of the footprint of full `kubeadm`, appropriate for a home-lab scale cluster |
| CI | Gitea + act_runner | Self-hosted git server with GitHub-Actions-compatible workflow syntax; the runner executes jobs via Docker-in-Docker inside the cluster |
| CD / GitOps | ArgoCD | Watches a git repository and automatically reconciles cluster state to match it (auto-sync + self-heal); no manual `kubectl apply` for deployed apps |
| Observability | kube-prometheus-stack | Prometheus for metrics, Grafana for dashboards, Alertmanager for alerting, node-exporter/kube-state-metrics for cluster-wide visibility |
| Secrets | HashiCorp Vault | Centralized secret storage instead of hardcoding tokens/passwords in config files or git |

## Infrastructure Layout

- **Host 1 (Windows + Hyper-V)**: `ctrl-01` (192.168.50.210), `worker-01` (.211), `ci-01` (.212, reserved for future use), `vault-01` (.213)
- **Host 2 (Proxmox)**: planned second worker node, joining the same cluster over the LAN

## Key Problems Solved

This project was built through hands-on debugging, not a scripted happy path. Some of the harder issues encountered and resolved:

- **Packer boot on Generation 2 (UEFI) Hyper-V VMs**: initial `boot_command` targeting the GRUB edit menu silently failed; switched to entering the GRUB command line directly to inject the `autoinstall` kernel parameter reliably.
- **Hyper-V KVP-based IP autodetection**: Packer's SSH communicator couldn't discover the guest IP over NAT/KVP; resolved by assigning a static IP via cloud-init and pointing Packer directly at it.
- **Cloud-init NoCloud seed generation on Windows**: building the seed ISO with IMAPI2FS via `ADODB.Stream` was unreliable and broke under parallel Terraform execution; replaced with a robust `Add-Type`/unsafe `IStream` read implementation and serialized the apply (`-parallelism=1`).
- **Terraform/provider path normalization bug**: the Hyper-V provider round-tripped disk paths with inconsistent slash direction, causing "inconsistent final plan" errors; fixed with an explicit `replace()` in the resource definition.
- **SSH hardening undone by cloud-init**: Ubuntu's `sshd_config` `Include` directive loads `/etc/ssh/sshd_config.d/50-cloud-init.conf` *before* the main config, so cloud-init's `PasswordAuthentication yes` silently overrode the hardening playbook; fixed by removing the override file before applying the hardened setting.
- **act_runner Docker socket race condition**: the runner container started before the sidecar `dind` container's Docker daemon was ready, causing crash loops; solved with a self-contained retry loop (register-or-daemon) that never exits the container, avoiding Kubernetes' exponential backoff.
- **ArgoCD CRD size limit**: the `ApplicationSet` CRD's `kubectl apply` annotation exceeded Kubernetes' 262144-byte limit; resolved using `--server-side --force-conflicts` apply instead of client-side apply.

## Repository Structure

## Status

Core infrastructure, CI, CD/GitOps, observability, and secrets management are all deployed and verified end-to-end.

## Photo Backup Service (Immich)

Self-hosted Google Photos replacement, deployed as a standard Kubernetes workload:

- **Storage**: uploads persist on a 3.7TB SMB share mounted from the Hyper-V host onto `worker-01`, exposed to the cluster as a `hostPath` PersistentVolume with node affinity. Database and ML model cache use fast local storage (`local-path`) instead, since network storage is a poor fit for database I/O.
- **Cluster expansion**: `ci-01` (previously idle) was joined as a second k3s worker node via the existing Ansible playbook, and the resource-heavy machine-learning component is pinned there via `nodeSelector`, keeping it off the node serving the database and API.
- **External access**: exposed through the same OCI VPS used for WireGuard connectivity, via Nginx Proxy Manager with a Let's Encrypt certificate, tunneled back to the home cluster over WireGuard. Mobile app supports automatic local/external endpoint switching based on Wi-Fi SSID.
- **Security hardening**: nginx rate limiting (`limit_req`) on the login endpoint, plus a custom fail2ban jail that reads the reverse-proxy access log and bans offending IPs at the network level via `nftables`/`DOCKER-USER`. Both layers were validated with a live brute-force test (Kali Linux + Hydra + `rockyou.txt`) — see `security/` for the (secret-free) configuration.

## Next Steps

## File Storage (Nextcloud)

Self-hosted file storage and collaboration, deployed the same way as Immich — plain Kubernetes manifests, no Helm chart, external access via the same OCI VPS + WireGuard + Nginx Proxy Manager path. Backed by MariaDB and the same 3.7TB SMB share used by Immich (separate folder).

Discovered and fixed a subtle official-image requirement in the process: the Docker image expects the *entire* `/var/www/html` directory to live on one persistent volume (it manages upgrades and internal file structure itself). Splitting `config`/`data` onto separate PVCs — a reasonable-looking optimization — broke the image's own install/upgrade detection logic and caused a persistent crash loop. Consolidating to a single `/var/www/html` PVC resolved it.

## Password Manager (Vaultwarden)

A lightweight, Bitwarden-compatible password manager for storing infrastructure credentials — deliberately kept on local-path storage (no SMB share) to avoid the same class of permission issues encountered with Nextcloud's data directory.

## Security Hardening

Both services are fronted by nginx rate limiting on their login endpoints. Nextcloud additionally relies on its own built-in brute-force throttling (exponential delay per source IP), validated against a live penetration test using Kali Linux and Hydra against Immich's login endpoint, confirmed via reverse-proxy access logs.

## Next Steps

Alertmanager → Telegram routing by severity, Velero cluster backups, Vault snapshots, storage-capacity alerting for the shared photo/file archive, a self-hosted mail server (Grommunio) pending an SMTP relay solution for the VPS's blocked port 25, and a third Proxmox-hosted node for control-plane HA.


Alertmanager → Telegram routing by severity, Velero cluster backups, Vault snapshots, storage-capacity alerting for the photo archive, and a third Proxmox-hosted node for control-plane HA.
Core infrastructure, CI, CD/GitOps, observability, and secrets management are all deployed and verified end-to-end. Planned next steps: second worker node on Proxmox, SSH certificate-based authentication via Vault, and cloud provider practice (AWS/Azure).
