# =============================================================================
#  HA LEGACY DASHBOARD  --  Docker
#  Serveert index.html als statische pagina met nginx.
#
#  Bouwen:   docker build -t ha-legacy-dashboard .
#  Draaien:  docker run -d --name ha-dashboard -p 8080:80 --restart unless-stopped \
#              -v ha-dashboard-config:/config \
#              -e HA_URL=http://192.168.1.10:8123 -e HA_TOKEN=jouw-token \
#              ha-legacy-dashboard
#  Openen:   http://<ip-van-de-host>:8080/
#
#  Het volume op /config is optioneel (de container start ook zonder), maar
#  zonder volume kan het dashboard de configuratie niet in een bestand bewaren
#  en valt het terug op localStorage in de browser.
#
#  Makkelijker is docker compose (zie docker-compose.yml + .env.example).
# =============================================================================

# Alpine = klein image (~50 MB) en weinig aanvalsvlak. Versie vastgepind
# zodat een rebuild hetzelfde resultaat geeft.
FROM nginx:1.29-alpine

# Eigen server-config: geen caching op het dashboard, zodat een nieuwe
# build direct zichtbaar is (Safari op iOS 9 cachet anders agressief).
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Het dashboard als SJABLOON: hierin staan nog de placeholders
# ${HA_URL}, ${HA_TOKEN} en ${HA_POLL_SECONDS}. De definitieve pagina wordt
# bij elke containerstart gegenereerd op basis van de omgevingsvariabelen.
COPY index.html /opt/dashboard/index.html.template

# Startscript dat de omgevingsvariabelen in de pagina invult (en dat meldt of
# /config als volume gekoppeld is).
# De sed is voor Windows: een shellscript met CRLF-regeleindes start niet.
COPY docker-entrypoint.d/40-ha-dashboard-config.sh /docker-entrypoint.d/40-ha-dashboard-config.sh
RUN chmod +x /docker-entrypoint.d/40-ha-dashboard-config.sh \
 && sed -i 's/\r$//' /docker-entrypoint.d/40-ha-dashboard-config.sh

# Map voor het configuratiebestand (config.json). Bedoeld om te koppelen aan
# een volume; zonder mount blijft de map in de containerlaag en overleeft de
# configuratie het verwijderen van de container niet.
RUN mkdir -p /config && chown nginx:nginx /config

# Standaardwaarden. Zet HA_URL en HA_TOKEN via docker compose / .env of met -e.
# Blijft HA_TOKEN leeg, dan toont het dashboard het instellingenscherm.
ENV HA_URL="" \
    HA_TOKEN="" \
    HA_POLL_SECONDS="5"

# Alleen statische bestanden; verder heeft dit image niets nodig.
EXPOSE 80

# Container-healthcheck (BusyBox wget zit in Alpine, curl niet).
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1/ || exit 1

# De standaard CMD van het nginx-image (nginx -g "daemon off;") blijft gelden;
# daarmee draait ook /docker-entrypoint.d/ bij elke start.
