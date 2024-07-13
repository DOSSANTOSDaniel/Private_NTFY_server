#!/usr/bin/env ash

#--------------------------------------------------#
# Script_Name: init-server.sh
#
# Author:  'dossantosjdf@gmail.com'
#
# Date: 13/07/2024
# Version: 1.0
# Bash_Version: 5.1.16
#--------------------------------------------------#
# Description:
#
# Ce script permet:
# - Tester et valider les valeurs des variables d'environnement indiqués par l'utilisateur.
# - La configuration du serveur selon les valeurs des variables d'environnement.
# - De détecter les certificats SSL d'un utilisateur et de les intégrées au fichier de configuration server.yml.
# - La mise en place de la journalisation des erreurs.
#

# Fonctions
# Mise en place de messages de log
ct_logs() {
  message_log="$1"
  message_time="$(date +%F__%T)"
  log_dir='/var/log/ntfy.log'
  
  echo "$message_time   $message_log" >> $log_dir
}

# Teste et intègre la configuration d'un domaine personnalisé est définit par un utilisateur
if [ -n "$DOMAIN_NAME" ]; then
  domain=${DOMAIN_NAME#*://}
  domain=${domain%%/*}
  if nslookup -type=ANY "$domain" 8.8.8.8; then
    sed -i "s#^base-url:.*#base-url: https://${domain}#" "$NTFY_CONFIG_DIR"/server.yml
    sed -i "s#^upstream-base-url:.*#upstream-base-url: https://${domain}#" "$NTFY_CONFIG_DIR"/server.yml
  else
    ct_logs "DOMAIN_NAME=$DOMAIN_NAME : Nom de domaine invalide !"
    exit 1
  fi
fi

# Configure le paramètre email de webpush
if [ -n "$EMAIL_ADDRESS" ]; then
  email_regex="^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"

  if echo "$EMAIL_ADDRESS" | grep -Eq "$email_regex"; then
    sed -i "s#^web-push-email-address:.*#web-push-email-address: $EMAIL_ADDRESS#" "$NTFY_CONFIG_DIR"/server.yml
  else
    ct_logs "EMAIL_ADDRESS=$EMAIL_ADDRESS : Adresse e-mail invalide"
    exit 1
  fi
fi

if [ -n "$DEFAULT_ACCESS" ]; then
  case "$DEFAULT_ACCESS" in
    'read-write'|'read-only'|'write-only'|'deny-all')
      sed -i "s/^auth-default-access:.*/auth-default-access: $DEFAULT_ACCESS/" "$NTFY_CONFIG_DIR"/server.yml
    ;;
    *)
      ct_logs "DEFAULT_ACCESS=$DEFAULT_ACCESS : Erreur de paramètre, valeurs possibles: read-write, read-only, write-only et deny-all"
      exit 1
    ;;
  esac
fi

if [ -n "$CACHE_DURATION" ]; then
  duration_regex="^[0-9]+[smh]$"
   if echo "$CACHE_DURATION" | grep -Eq "$duration_regex"; then
    sed -i "s/^cache-duration:.*/cache-duration: $CACHE_DURATION/" "$NTFY_CONFIG_DIR"/server.yml
  else
    ct_logs "CACHE_DURATION=$CACHE_DURATION : Valeur invalide, exemples : 30s, 15m, 2h"
    exit 1
  fi
fi

if [ -n "$ATTACHMENT_TOTAL_SIZE_LIMIT" ]; then
  regex_total_size='^[0-9]+[ ]?(B|KB|MB|GB)$'

  if echo "$ATTACHMENT_TOTAL_SIZE_LIMIT" | grep -Eq "$regex_total_size"; then
    sed -i "s/^attachment-total-size-limit:.*/attachment-total-size-limit: $ATTACHMENT_TOTAL_SIZE_LIMIT/" "$NTFY_CONFIG_DIR"/server.yml
  else
    ct_logs "ATTACHMENT_TOTAL_SIZE_LIMIT=$ATTACHMENT_TOTAL_SIZE_LIMIT : Valeur invalide : exemples, 10B, 352KB, 500MB, 8GB..."
    exit 1
  fi
fi

if [ -n "$ATTACHMENT_FILE_SIZE_LIMIT" ]; then
  regex_total_size='^[0-9]+[ ]?(B|KB|MB|GB)$'

  if echo "$ATTACHMENT_FILE_SIZE_LIMIT" | grep -Eq "$regex_total_size"; then
    sed -i "s/^attachment-file-size-limit:.*/attachment-file-size-limit: $ATTACHMENT_FILE_SIZE_LIMIT/" "$NTFY_CONFIG_DIR"/server.yml
  else
    ct_logs "ATTACHMENT_FILE_SIZE_LIMIT=$ATTACHMENT_FILE_SIZE_LIMIT : La valeur est invalide : exemples, 4552B, 1024KB, 800MB, 2GB..."
    exit 1
  fi
fi

if [ -n "$ATTACHMENT_EXPIRY_DURATION" ]; then
  expiry_regex='^([1-9][0-9]*)(h|m|s)$'

  if echo "$ATTACHMENT_EXPIRY_DURATION" | grep -Eq "$expiry_regex"; then
    sed -i "s/^attachment-expiry-duration:.*/attachment-expiry-duration: $ATTACHMENT_EXPIRY_DURATION/" "$NTFY_CONFIG_DIR"/server.yml
  else
    ct_logs "ATTACHMENT_EXPIRY_DURATION=$ATTACHMENT_EXPIRY_DURATION : Valeur invalide, exemples 32h, 60s, 80m..."
    exit 1
  fi
fi

if [ -n "$KEEPALIVE_INTERVAL" ]; then
  keepalive_regex="^[0-9]+s$"
  
  if echo "$KEEPALIVE_INTERVAL" | grep -Eq "$keepalive_regex"; then
    sed -i "s/^keepalive-interval:.*/keepalive-interval: $KEEPALIVE_INTERVAL/" "$NTFY_CONFIG_DIR"/server.yml
  else
    ct_logs "KEEPALIVE_INTERVAL=$KEEPALIVE_INTERVAL : Valeur invalide, exemples, 30s, 55s..."
    exit 1
  fi
fi

if [ -n "$LOG_LEVEL" ]; then
  case "$LOG_LEVEL" in
    ('trace'|'error'|'warn'|'info'|'debug')
      sed -i "s/^log-level:.*/log-level: $LOG_LEVEL/" "$NTFY_CONFIG_DIR"/server.yml
      ;;
    (*)
      ct_logs "LOG_LEVEL=$LOG_LEVEL : Valeur invalide, exemples : trace, error, warn, info, debug"
      exit 1
      ;;
  esac
fi

# Détecte si l'utilisateur utilise son propre certificat SSL et l'intègre au fichier de configuration 
if [ "$(find "$CERT_USER_DIR" -type f | wc -l)" -gt '0' ]; then
  find "$CERT_USER_DIR" -type f | while IFS= read -r user_cert_file; do
    cert_type="$(head -1 "$user_cert_file" | awk -F'-*' '{print $2}')"
    case "$cert_type" in
      'BEGIN CERTIFICATE')
        sed -i "s#^cert-file:.*#cert-file: $user_cert_file#" "$NTFY_CONFIG_DIR"/server.yml
        ;;
      'BEGIN PRIVATE KEY')
        sed -i "s#^key-file:.*#key-file: $user_cert_file#" "$NTFY_CONFIG_DIR"/server.yml
        ;;
      *)
        ct_logs "Clé privé ou certificat non valide dans $CERT_USER_DIR"
        exit 1
        ;;
    esac
  done
fi

# Configure la valeur "behind-proxy" si le serveur se trouve derrière un proxy 
if [ -n "$BEHIND_PROXY" ]; then
  case "$BEHIND_PROXY" in
    ('TRUE'|'true')
      if grep -Eq '^behind-proxy:.*' "$NTFY_CONFIG_DIR"/server.yml; then
        sed -i "s/^behind-proxy:.*/behind-proxy: $BEHIND_PROXY/" "$NTFY_CONFIG_DIR"/server.yml
      else
        echo "behind-proxy: true" >> "$NTFY_CONFIG_DIR"/server.yml
      fi
      ;; 
    ('FALSE'|'false')
        sed -i "s/^behind-proxy:.*//" "$NTFY_CONFIG_DIR"/server.yml
      ;;     
    (*)
      ct_logs "BEHIND_PROXY=$BEHIND_PROXY : Valeur invalide, exemples : true, false"
      exit 1
      ;;
  esac
fi

# Démarrage du serveur NTFY (Entrypoint)
ntfy serve
