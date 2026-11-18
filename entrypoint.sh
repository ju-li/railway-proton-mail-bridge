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

# Railway injects PORT automatically and it can clash with the mail ports,
# so each listener has its own variable instead.
export SMTP_PORT="${SMTP_PORT:-1025}"
export IMAP_PORT="${IMAP_PORT:-1143}"
export CARDDAV_PORT="${CARDDAV_PORT:-8080}"

# Keep one IMAP session open so hydroxide indexes the folders and keeps them
# loaded; without it, clients that poll see empty folders. Needs the bridge
# password. It waits for the IMAP server below to start.
if [ -n "$HYDROXIDE_BRIDGE_PASS" ]; then
  hydroxide-keepalive &
else
  echo "HYDROXIDE_BRIDGE_PASS is not set: IMAP clients that poll may see empty folders (see README)" >&2
fi

# An empty host means listen on all interfaces, IPv4 and IPv6 (Railway private network)
exec hydroxide \
  -smtp-host "" -smtp-port "$SMTP_PORT" \
  -imap-host "" -imap-port "$IMAP_PORT" \
  -carddav-host "" -carddav-port "$CARDDAV_PORT" \
  serve
