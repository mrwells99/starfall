# Superseded — source-on-droplet + systemd

This directory is the **previous** deployment model: `rsync` the source to the
droplet, run it under six templated `starfall@<instance>` systemd units driven by
`instances/*.env`.

It is superseded by the Docker pipeline in [`../../DEPLOYMENT.md`](../../DEPLOYMENT.md).
Kept because it still works and is a useful fallback if the registry is
unreachable, and because the runbook it belongs to
([`../../docs/DEPLOY.md`](../../docs/DEPLOY.md)) documents droplet facts —
firewall, DNS, SELinux — that are still true.

**Do not run both models on the same droplet.** They bind the same UDP ports.
To move from this to Docker: `systemctl disable --now 'starfall@*'` first.
