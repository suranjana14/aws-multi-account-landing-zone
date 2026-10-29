#!/usr/bin/env bash
# fmt + validate every module and environment, and JSON-lint the SCPs.
# Needs no AWS credentials: `init -backend=false` + `validate` never call AWS.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> terraform fmt -check"
terraform fmt -check -recursive .

echo "==> SCP JSON syntax"
for f in policies/scp/*.json; do
  python3 -m json.tool "$f" >/dev/null && echo "ok  $f"
done

for dir in modules/*/ envs/*/; do
  echo "==> validate ${dir}"
  terraform -chdir="${dir}" init -backend=false -input=false >/dev/null
  terraform -chdir="${dir}" validate -no-color
done

if command -v checkov >/dev/null 2>&1; then
  checkov -d . --framework terraform --quiet --compact
else
  echo "INFO: checkov not installed; skipping security scan" >&2
fi
