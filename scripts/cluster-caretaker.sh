#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${1:-openclaw}"
APP_LABEL="${APP_LABEL:-app.kubernetes.io/instance=openclaw}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

need kubectl

say() {
  printf '\n## %s\n' "$1"
}

RUNNING_POD="$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" \
  --field-selector=status.phase=Running \
  --sort-by=.metadata.creationTimestamp \
  -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null || true)"

FAILED_PODS="$(kubectl get pods -n "$NAMESPACE" -l "$APP_LABEL" \
  --field-selector=status.phase=Failed \
  -o custom-columns='POD:.metadata.name,REASON:.status.reason,MESSAGE:.status.message' \
  --no-headers 2>/dev/null || true)"

say "Summary"
kubectl get pods -n "$NAMESPACE" -o wide

echo
READY_LINE="$(kubectl get deploy -n "$NAMESPACE" -o custom-columns='NAME:.metadata.name,READY:.status.readyReplicas,DESIRED:.spec.replicas,AVAILABLE:.status.availableReplicas,UPDATED:.status.updatedReplicas' --no-headers 2>/dev/null || true)"
if [[ -n "$READY_LINE" ]]; then
  echo "$READY_LINE"
fi

say "Restart check"
kubectl get pods -n "$NAMESPACE" -o custom-columns='POD:.metadata.name,PHASE:.status.phase,RESTARTS:.status.containerStatuses[*].restartCount,AGE:.metadata.creationTimestamp' --no-headers

say "Recent warning events"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -n 20 || true

say "PVCs"
kubectl get pvc -n "$NAMESPACE" -o wide || true

if [[ -n "$RUNNING_POD" ]]; then
  say "Runtime storage"
  kubectl exec -n "$NAMESPACE" -c gateway "$RUNNING_POD" -- sh -c '
    echo "pod=$(hostname)"
    echo "--- disk usage ---"
    df -h /home/node/.openclaw /tmp
    echo "--- top-level state dirs ---"
    for d in /home/node/.openclaw/agents /home/node/.openclaw/tasks /home/node/.openclaw/memory /home/node/.openclaw/logs /home/node/.openclaw/credentials /home/node/.openclaw/devices /home/node/.openclaw/identity; do
      [ -d "$d" ] || continue
      printf "%s: " "$d"
      ls -1 "$d" | wc -l
    done
  ' || true

  say "OpenClaw pod health"
  kubectl exec -n "$NAMESPACE" -c gateway "$RUNNING_POD" -- sh -c 'openclaw health --json' || true
fi

if [[ -n "$FAILED_PODS" ]]; then
  say "Failed pods"
  echo "$FAILED_PODS"
fi

say "Images"
kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.containers[*]}{.name}{"="}{.image}{" "}{end}{"\n"}{end}'

echo
say "Caretaker verdict"
RESTART_SUM="$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{range .items[*]}{.metadata.name}{"="}{range .status.containerStatuses[*]}{.restartCount}{" "}{end}{"\n"}{end}' 2>/dev/null || true)"
if [[ -n "$FAILED_PODS" ]]; then
  echo "attention: one or more pods are in Failed state"
elif echo "$RESTART_SUM" | grep -Eq '=[1-9]'; then
  echo "attention: one or more containers have restarted"
elif [[ -z "$RUNNING_POD" ]]; then
  echo "attention: no running pod matched label $APP_LABEL in namespace $NAMESPACE"
else
  echo "ok: running pod healthy enough for exec checks and no failed pods/restarts detected in namespace $NAMESPACE"
fi
