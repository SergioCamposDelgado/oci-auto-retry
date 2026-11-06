#!/usr/bin/env bash
# Trigger GitHub Actions repository_dispatch event for oci-auto-retry
#
# Usage:
#   export GITHUB_TOKEN="ghp_yourPersonalAccessToken"
#   ./scripts/trigger.sh "your-username" "oci-auto-retry"
#
# Or with arguments:
#   ./scripts/trigger.sh "your-username" "oci-auto-retry" "ghp_yourToken"

set -euo pipefail

OWNER="${1:-${GITHUB_OWNER:-}}"
REPO="${2:-${GITHUB_REPO:-oci-auto-retry}}"
TOKEN="${3:-${GITHUB_TOKEN:-}}"
EVENT_TYPE="${4:-lanzar-intento-oci}"

if [ -z "$OWNER" ] || [ -z "$TOKEN" ]; then
  echo "Error: Missing arguments or environment variables."
  echo "Usage: $0 <github_owner> [github_repo] [github_token] [event_type]"
  echo "Or set GITHUB_OWNER and GITHUB_TOKEN environment variables."
  exit 1
fi

echo "Triggering event '$EVENT_TYPE' on $OWNER/$REPO..."

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/${OWNER}/${REPO}/dispatches" \
  -d "{\"event_type\": \"${EVENT_TYPE}\"}")

if [ "$HTTP_STATUS" -eq 204 ]; then
  echo "✅ Dispatch triggered successfully! (HTTP 204)"
else
  echo "❌ Error triggering dispatch: HTTP status code $HTTP_STATUS"
  exit 1
fi
