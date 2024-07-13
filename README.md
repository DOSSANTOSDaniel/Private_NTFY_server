# Private_NTFY_server
Dockerfile et script entrypoint permettant de créer une image pour le déploiment d'un serveur de notifications Push(NTFY).
Image basé sur alpine:latest.

## Fonctionnalités implémentées
- Configuration en HTTPS (Certificat autosigné) par défaut.
- Mise en place de webpush.
- Permet l'utilisation de variables d'environnement pour configurer le serveur.
- Création d'un utilisateur administrateur par défaut(admin).
- Sécurisation et interdiction des connexions anonymes.
- Possibilité de fournir un certificat SSL en créant un volume sur le dossier /etc/ntfy/user_cert du conteneur, alors le certificat sera détecté et intégré à la configuration du serveur.

## Les différentes variables d'environnement utilisables
|Variable|Description|
|---|---|
|DOMAIN_NAME|URL pour accéder à l'interface web, https://localhost par défaut.|
|EMAIL_ADDRESS|Adresse email pour la configuration de webpush (optionnel).|
|DEFAULT_ACCESS|Définit les droits d’accès par défaut, Configuration par défaut avec "deny-all" ce qui permet d’avoir une instance complètement privée,
valeurs possibles: read-write, read-only, write-only et deny-all.|
|CACHE_DURATION|Durée de stockage des messages en cache, par défaut c’est 24h.|
|ATTACHMENT_TOTAL_SIZE_LIMIT|Taille limite du cache concernant les pièces jointes, par défaut 10G.|
|ATTACHMENT_FILE_SIZE_LIMIT|Taille limite des pièces jointes par fichier, par défaut 1 Go.|
|ATTACHMENT_EXPIRY_DURATION|Durée après laquelle les pièces jointes téléchargées seront supprimées, par défaut 72h.|
|KEEPALIVE_INTERVAL|Intervalle pendant lequel les messages keepalive sont envoyés au client, dans le but d’empêcher les intermédiaires de fermer la connexion pour cause d’inactivité,
par défaut c'est 55 secondes.|
|LOG_LEVEL|Niveau de journalisation(logs), par défaut "warn", valeurs possibles: panic, fatal, error, warn, info et debug/trace.|

## Usage
### Création de conteneurs avec docker run
#### Valeurs par défaut
`docker run -d -p 443:443 ntfy_v15`
#### Avec variables d'environnement modifié
`docker run -d -p 443:443 -e DOMAIN_NAME='noti.exemple.ex' -e EMAIL_ADDRESS='ex@exemple.ex' ntfy_v15`
#### Avec un certificat SSL personnel
 `docker run -d -p 80:80 -p 443:443 -v /home/user/cert/:/etc/ntfy/user_cert/ ntfy_v15`
 Les nouveau certificat sera détecté et intégré à la configuration automatiquement.
 ### Création de conteneurs avec docker-compose
 ```
 services:
  ntfy:
    image: dossantosd/priv-ntfy
    container_name: ntfy
    command:
      - serve ????????????????
    environment:
      - DOMAIN_NAME='ex.exemple.ex'
      - EMAIL_ADDRESS='ex@exemple.ex'
      - LOG_LEVEL='info'
    volumes:
      - /var/cache/ntfy:/var/cache/ntfy
      - /etc/ntfy:/etc/ntfy
      - /etc/ntfy/user_cert
    ports:
      - 443:443
    restart: unless-stopped
 ```

### Utilisation de NTFY
#### Connexion à l'interface web
Si on est sur l'ordinateur où docker est installé alors aller à l'adresse https://localhost ou https://127.0.1.1.
Si vous êtes sur un autre ordinateur sur le réseau local, alors utilisez l'adresse IP du système où docker est installé, exemple https://192.168.1.35.

### Utilisation de curl pour envoyer les messages 
`curl -k -u admin:admin -d "Hi" https://192.168.1.35/test01`

- 192.168.1.35 est l'adresse IP du système gérant le conteneur.
- -k ou --insecure : Ignore les erreurs liées au certificat SSL, à utiliser seulement pour les certificats autosigné.
- test01 est l'adresse du topic(sujet).
- admin:admin, nom et mot de passe de l'utilisateur admin, ne pas oublié de changer le mot de passe par défaut sur l'interface web.
- -d, c'est le corps du message.

#### Identifiants
L'utilisateur administrateur "admin" est créé par défaut, son mot de passe est admin.

## Les différents volumes
|Chemin dans le conteneur|Description|
|---|---|
|/etc/ntfy/user_cert|Dossier contenant le certificat SSL donné par l'utilisateur.|
|/var/cache/ntfy|Dossier contenant le cache des messages.|
|/etc/ntfy|Dossier où se trouve le fichier de configuration du serveur server.yml.|
|/var/lib/ntfy/attachments|Dossier abritant le cache des pièces jointes.|

## Le dépannage 
Cette image contient un script qui se lance à chaque création ou démarrage d'un conteneur, ce script permet de configurer le serveur via les variables d'environment et autre.

Si vous avez démarré un conteneur et que celui-ci s'éteint directement c'est probablement une erreur engendré par une mauvaise saisie d'une variable d'environment, pour avoir les messages de log du conteneur il faut qu'au démarrage du conteneur monter le dossier /var/log du conteneur, exemple avec une erreur sur la variable EMAIL_ADDRESS :

docker run -v $(pwd)/logs_myntfy/:/var/log/ -e EMAIL_ADDRESS="ex@mple@gmail.com" -p 443:443 -itd myntfy && cat logs_myntfy/ntfy.log

f60f4d6b99c4bbb904941da56c16dc31c5061813a31470504de8f74d44e30ffc

2024-07-13__21:08:56   EMAIL_ADDRESS=ex@mple@gmail.com : Adresse e-mail invalide
