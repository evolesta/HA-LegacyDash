#!/bin/sh
# =============================================================================
#  HA LEGACY DASHBOARD -- configuratie invoegen bij het starten van de container
#  Wordt automatisch uitgevoerd door /docker-entrypoint.sh van het nginx-image,
#  vóórdat nginx start.
#
#  Omgevingsvariabelen:
#    HA_URL           bv. http://192.168.1.10:8123
#                     (leeg = hetzelfde adres als waarop de pagina wordt geopend)
#    HA_TOKEN         Long-Lived Access Token (nodig om te kunnen verbinden)
#    HA_POLL_SECONDS  verversingsinterval in seconden (minimaal 2, standaard 5)
#
#  Deze variabelen zijn de STARTSITUATIE. Zodra er een config.json in het
#  volume /config staat (gemaakt via het instellingenscherm of met de hand),
#  gaat die vóór op deze variabelen.
#
#  Let op: het token staat leesbaar in de geserveerde pagina (/index.html) en
#  eventueel in /config/config.json. Zet deze container dus nooit rechtstreeks
#  op het openbare internet.
# =============================================================================
set -eu

TEMPLATE=/opt/dashboard/index.html.template
TARGET=/usr/share/nginx/html/index.html

# Alleen deze drie variabelen vervangen; de rest van het bestand blijft intact.
envsubst '${HA_URL} ${HA_TOKEN} ${HA_POLL_SECONDS}' < "$TEMPLATE" > "$TARGET"

echo "ha-dashboard: pagina opnieuw gegenereerd uit HA_URL, HA_TOKEN en HA_POLL_SECONDS"

# ---------------------------------------------------------------------------
#  Configuratiebestand /config/config.json
#  nginx draait als gebruiker "nginx" (uid 101) en moet daar kunnen schrijven,
#  dus de rechten worden hier rechtgezet. Op Windows-/macOS-mounts is de chown
#  een no-op; dat is daar geen probleem.
# ---------------------------------------------------------------------------
CONFIG_DIR=/config
CONFIG_FILE="$CONFIG_DIR/config.json"
RUNTIME_FILE=/usr/share/nginx/html/runtime.json

mkdir -p "$CONFIG_DIR" 2>/dev/null || true
chown -R nginx:nginx "$CONFIG_DIR" 2>/dev/null || true
chmod 0775 "$CONFIG_DIR" 2>/dev/null || true
if [ -f "$CONFIG_FILE" ]; then
  chown nginx:nginx "$CONFIG_FILE" 2>/dev/null || true
  chmod 0664 "$CONFIG_FILE" 2>/dev/null || true
fi

# Is /config een echt volume (named volume of bind mount)?
CONFIG_MOUNTED=false
if grep -q " $CONFIG_DIR " /proc/mounts 2>/dev/null; then
  CONFIG_MOUNTED=true
fi

# Kan de nginx-worker er echt in schrijven? (test als de gebruiker nginx zelf)
CONFIG_WRITABLE=false
if [ -d "$CONFIG_DIR" ] && su -s /bin/sh nginx -c "test -w $CONFIG_DIR" 2>/dev/null; then
  CONFIG_WRITABLE=true
fi

# Alleen met een echt volume is opslaan in een bestand zinvol: zonder volume
# zou de configuratie verdwijnen zodra de container wordt verwijderd.
CONFIG_FILE_MODE=false
if [ "$CONFIG_MOUNTED" = "true" ] && [ "$CONFIG_WRITABLE" = "true" ]; then
  CONFIG_FILE_MODE=true
fi

cat > "$RUNTIME_FILE" <<EOF
{"configFile": $CONFIG_FILE_MODE, "configMounted": $CONFIG_MOUNTED, "configWritable": $CONFIG_WRITABLE, "generatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF

if [ "$CONFIG_FILE_MODE" = "true" ]; then
  if [ -f "$CONFIG_FILE" ]; then
    echo "ha-dashboard: configuratiebestand $CONFIG_FILE gevonden (gaat vóór de omgevingsvariabelen)"
  else
    echo "ha-dashboard: nog geen $CONFIG_FILE; entiteiten en token zijn via het instellingenscherm op te slaan"
  fi
elif [ "$CONFIG_MOUNTED" = "true" ]; then
  echo "ha-dashboard: LET OP: $CONFIG_DIR is niet beschrijfbaar voor de nginx-gebruiker (uid 101)."
  echo "ha-dashboard:           Op Linux helpt: sudo chown -R 101:101 ./config"
  echo "ha-dashboard:           Het dashboard bewaart instellingen nu in de browser (localStorage)."
else
  echo "ha-dashboard: geen volume op $CONFIG_DIR gekoppeld; instellingen worden in de browser bewaard (localStorage)."
  echo "ha-dashboard: koppel een map aan /config (zie docker-compose.yml) om ze in een bestand te bewaren."
fi

if [ -n "${HA_URL:-}" ]; then
  echo "ha-dashboard: HA_URL=${HA_URL}"
else
  echo "ha-dashboard: HA_URL niet gezet -> dashboard gebruikt het adres waarop de pagina wordt geopend"
fi

if [ -n "${HA_TOKEN:-}" ]; then
  echo "ha-dashboard: HA_TOKEN is gezet (${#HA_TOKEN} tekens)"
else
  echo "ha-dashboard: HA_TOKEN niet gezet"
fi

echo "ha-dashboard: status verversen elke ${HA_POLL_SECONDS:-5} seconde(n)"
