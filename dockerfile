# Alpine
FROM "alpine:latest"

# Variables d'environnement
ARG NTFY_VERSION="2.11.0"
ENV PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
ENV TZ="Europe/Paris"

ARG NTFY_TEMPORARY_ADMIN="admin"
# Variable permettant d'indiquer le mot de passe de l'utilisateur admin à la commande ntf add.
ARG NTFY_PASSWORD="admin"

ENV NTFY_DOMAIN_NAME="https://localhost"

ENV NTFY_CONFIG_DIR="/etc/ntfy"

# Variables concernant le cache
ENV NTFY_CACHE_DURATION="24h"

# Variables concernant les fichiers attachés aux messages
ENV NTFY_ATTACHMENT_TOTAL_SIZE_LIMIT="10G"
ENV NTFY_ATTACHMENT_FILE_SIZE_LIMIT="1G" 
ENV NTFY_ATTACHMENT_EXPIRY_DURATION="72h"

ENV NTFY_KEEPALIVE_INTERVAL="55s"
ENV NTFY_LOG_LEVEL="warn"

# Variables d'environnement pour le certificat SSL par défaut
ARG CERT_DIR="$NTFY_CONFIG_DIR/default_cert"
ARG CERT_KEY="$CERT_DIR/ntfy.key"
ARG CERT_CRT="$CERT_DIR/ntfy.crt"

ENV CERT_USER_DIR="$NTFY_CONFIG_DIR/user_cert"

ARG CERT_DAYS=365
ARG COUNTRY="FR"
ARG STATE="Ile-de-France"
ARG LOCALITY="Paris"
ARG ORGANIZATION="OpenSSL certificat auto"
ARG ORGANIZATIONAL_UNIT="$ORGANIZATION"
ARG COMMON_NAME="localhost"

# Installation des dépendances
RUN apk update && apk upgrade && apk add --no-cache \
    wget tar tzdata openssl \
    ca-certificates \
    && update-ca-certificates

# Création des répertoires de configuration
RUN mkdir -p $CERT_USER_DIR $CERT_DIR /var/cache/ntfy/ /var/lib/ntfy/  

# Téléchargement et installation de NTFY
RUN wget -qO- https://github.com/binwiederhier/ntfy/releases/download/v${NTFY_VERSION}/ntfy_${NTFY_VERSION}_linux_amd64.tar.gz \
    | tar -xz --strip-components=1 -C $NTFY_CONFIG_DIR/ \
    && mv $NTFY_CONFIG_DIR/ntfy /usr/local/bin/ \
    && chmod +x /usr/local/bin/ntfy  

# Création du fichier de Logs
RUN touch /var/log/ntfy.log

# Configuration de la timezone
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Exposer les ports 80 et 443
EXPOSE 80/tcp
EXPOSE 443/tcp

# Création du fichier de configuration du serveur
RUN cat <<EOF > $NTFY_CONFIG_DIR/server.yml
base-url: $NTFY_DOMAIN_NAME
listen-http: ":80"
listen-https: ":443"

cache-file: /var/cache/ntfy/cache.db
cache-duration: $NTFY_CACHE_DURATION

auth-file: /var/lib/ntfy/user.db
auth-default-access: deny-all

attachment-cache-dir: /var/lib/ntfy/attachments
attachment-total-size-limit: $NTFY_ATTACHMENT_TOTAL_SIZE_LIMIT
attachment-file-size-limit: $NTFY_ATTACHMENT_FILE_SIZE_LIMIT
attachment-expiry-duration: $NTFY_ATTACHMENT_EXPIRY_DURATION

keepalive-interval: $NTFY_KEEPALIVE_INTERVAL

enable-login: true

# Compatibilité IOS
upstream-base-url: $NTFY_DOMAIN_NAME

message-size-limit: "4k"

key-file: $CERT_KEY
cert-file: $CERT_CRT

log-level: $NTFY_LOG_LEVEL
log-format: text
log-file: /var/log/ntfy.log
EOF

# Ajout du script d'initialisation
COPY init-server.sh $NTFY_CONFIG_DIR/init-server.sh
RUN chmod +x $NTFY_CONFIG_DIR/init-server.sh

# Création du fichier de configuration OpenSSL et génération du certificat autosigné
RUN cat <<EOF > $CERT_DIR/openssl.cnf
[req]
distinguished_name=req_distinguished_name
req_extensions=v3_req
[req_distinguished_name]
[v3_req]
basicConstraints=CA:TRUE
keyUsage = keyCertSign, cRLSign, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName=@alt_names
[alt_names]
DNS.1=$COMMON_NAME
IP.1=127.0.0.1
IP.2=127.0.1.1
IP.3=::1
EOF

RUN openssl req -new -newkey rsa:4096 -days $CERT_DAYS -nodes -x509 \
  -subj "/C=${COUNTRY}/ST=${STATE}/L=${LOCALITY}/O=${ORGANIZATION}/OU=${ORGANIZATIONAL_UNIT}/CN=${COMMON_NAME}" \
  -keyout $CERT_KEY -out $CERT_CRT \
  -config $CERT_DIR/openssl.cnf
    
# Création des clés webpush
RUN ntfy webpush keys 2>&1 | grep "^web-push*\:*" >> $NTFY_CONFIG_DIR/server.yml

# Démarrage temporaire du server ntfy pour créer l'utilisateur admin
RUN ntfy serve --config $NTFY_CONFIG_DIR/server.yml & server_pid="$!" && sleep 4 \
  && ntfy user add --role=admin $NTFY_TEMPORARY_ADMIN && kill $server_pid  

# Commande pour lancer le script d'initialisation et démarrer le serveur NTFY
ENTRYPOINT ["/etc/ntfy/init-server.sh"]

LABEL maintainer="Dos Santos Daniel <dossantosjdf@gmail.com>"
