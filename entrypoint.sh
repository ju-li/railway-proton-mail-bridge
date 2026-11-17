#!/bin/sh
set -e
AUTH="$XDG_CONFIG_HOME/hydroxide/auth.json"
mkdir -p "$(dirname "$AUTH")"

# Seed from the env var on first boot, or whenever HYDROXIDE_AUTH_FORCE=1
if [ -n "$HYDROXIDE_AUTH_JSON_B64" ] && { [ ! -s "$AUTH" ] || [ "$HYDROXIDE_AUTH_FORCE" = "1" ]; }; then
  echo "$HYDROXIDE_AUTH_JSON_B64" | base64 -d > "$AUTH"
  chmod 600 "$AUTH"
  echo "Seeded $AUTH from HYDROXIDE_AUTH_JSON_B64"
fi
[ -s "$AUTH" ] || { echo "No auth.json: set HYDROXIDE_AUTH_JSON_B64" >&2; exit 1; }

# An empty host means listen on all interfaces, IPv4 and IPv6 (Railway private network)
exec hydroxide -imap-host "" -smtp-host "" -carddav-host "" \
  -carddav-port "${PORT:-8080}" serve
