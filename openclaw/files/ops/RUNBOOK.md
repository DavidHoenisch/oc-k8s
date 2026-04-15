# Ops Runbook

Start here when doing operations work.

## First checks

- confirm pod health
- confirm deployment readiness
- check recent namespace events
- check restart counts
- check OpenClaw health endpoints
- check disk usage in `~/.openclaw`

## Common tools

- `./scripts/cluster-caretaker.sh openclaw`
- `kubectl get pods -n openclaw`
- `kubectl describe pod <pod> -n openclaw`
- `kubectl logs <pod> -n openclaw`
- `openclaw cron status --json`

## Change discipline

- inspect first
- prefer reversible changes
- validate chart renders before commit
- push chart changes back to GitHub when modifying the public repo
- never commit secrets or sensitive runtime data to the public repo
