# Stack-Monitoring-Project
Projet de Stack Monitoring avec Prometheus, Grafana et Traefik.

## Étapes d'installation et de configuration

### 1. Clonage du répertoire GitHub
Clonez le projet à partir du dépôt suivant :
```bash
git clone https://github.com/stefanprodan/dockprom.git
```

---

### 2. Installation des exportateurs sur les machines cibles
Configurez les outils **Node Exporter** et **cAdvisor** pour collecter les métriques des machines cibles.

#### - Node Exporter :
```bash
docker run -d \                                                   
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  quay.io/prometheus/node-exporter:latest \
  --path.rootfs=/host

```

#### - cAdvisor :
```bash
sudo docker run \                                                               
   --volume=/:/rootfs:ro \
   --volume=/var/run:/var/run:ro \
   --volume=/sys:/sys:ro \
   --volume=/var/lib/docker/:/var/lib/docker:ro \
   --volume=/dev/disk/:/dev/disk:ro \
   --publish=8000:8080 \
   --detach=true \
   --name=cadvisor \
   gcr.io/cadvisor/cadvisor

```

#### - Pushgateway :
```bash
docker run -d -p 9091:9091 --name=pushgateway --privileged prom/pushgateway
```

---

### 3. Ajout des cibles dans Prometheus
Ajoutez les cibles dans le fichier de configuration de Prometheus pour superviser les métriques collectées.

#### Ouvrez le fichier de configuration :
```bash
sudo nano prometheus/prometheus.yml
```

#### Ajoutez les cibles :
```yaml
scrape_configs:
  - job_name: 'exportateurs'  # Peut être node_exporter, cAdvisor ou pushgateway
    scrape_interval: 5s      # Intervalle entre chaque collecte des métriques
    static_configs:
      - targets:             # Liste des cibles
        - "ip:port"          # Adresse IP et port de la machine à superviser
```

---

### 4. Vérification de la collecte des métriques
#### - Démarrez les conteneurs :
```bash
docker-compose up -d
```

#### - Accédez au service Prometheus :
Ouvrez votre navigateur et rendez-vous à l'adresse suivante :  [http://localhost:9090](http://localhost:9090)

<div align="center">
  <img src="Images/prometheus.png" alt="Prometheus Targets">
</div>

---

### 5. Ajout de Prometheus comme source de données pour Grafana
#### - Accédez à Grafana :
Ouvrez votre navigateur et rendez-vous à l'adresse suivante :  [http://localhost:3000](http://localhost:3000)

#### - Ajouter Prometheus comme source de données :
1. Naviguez vers **Data Sources → Add Data Source**.  
2. Cherchez **Prometheus** dans la liste.  
<div align="center">
  <img src="Images/Ajouter Prometheus.png" alt="Ajouter Prometheus">
</div>


3. Dans la section **Connection**, ajoutez l'URL du serveur Prometheus :  `http://localhost:9090`.
4. Enregistrez les modifications.

---

### 6. Implémentation des tableaux de bord dans Grafana
1. Naviguez vers **Dashboards → New → Import →** Choisissez un tableau de bord.  

#### Remarque :
Vous pouvez ajouter les tableaux de bord de deux manières :
- En ajoutant un fichier JSON correspondant au tableau de bord.
- En utilisant l'ID approprié du tableau de bord directement :
  - Pour les machines : **1860**
  - Pour les conteneurs : **11600**

2. Choisissez la source de données : **Prometheus**.

<div align="center">
  <img src="Images/Dashboard.png" alt="Tableau de bord">
</div>

---

### 7. Création des alertes :
#### Créez le fichier d'alertes :
```bash
sudo nano prometheus/alerts.yml
```
#### Ajoutez les alertes :
```yaml
groups:    # Définir un groupe d'alertes 
  - name: node_alerts    # Nom du groupe d'alertes  
    rules:  
      - alert: Hight CPU    # Nom de l'alerte
        expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) by (instance)) * 100 > 70    # Condition d'alerte
        for: 1m    # Délai avant de considérer l'alerte active
        labels:
          severity: warning    # Niveau de gravité de l'alerte
          resolve_automatically: true    # Automatisation de la résolution de l'alerte
        annotations:    # Informations supplémentaires pour l'alerte
          summary: Hight CPU usage for  {{ $labels.instance }}
          description: The target {{ $labels.instance }} is using {{ $value }}% CPU
```
### Liez le fichier d'alertes dans le fichier de configuration principal :
Ajoutez cette ligne dans `prometheus.yml` :

```yaml
rule_files:
  - "alerts.yml"
```
### Redémarrez Prometheus pour appliquer les changements :
```yaml
docker-compose restart prometheus
```

<div align="center">
  <img src="Images/Alerts.png" alt="Alerts">
</div>

### 8. Configuration de alert manager pour l'envoi des Emails:
#### Ouvrir le fichier de configuration :
```bash
nano alertmanager/config.yml
```
#### Ajoutez la configuration :
```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'    # Le serveur SMTP utilisé
  smtp_from: 'exemple@gmail.com'    # L'adresse email de l'expéditeur
  smtp_auth_username: 'username'    # Le nom d'utilisateur
  smtp_auth_password: 'password'    # Le mot de passe pour l'authentification SMTP (configurer dans la prochaine partie)
  smtp_require_tls: true    # Sécuriser la connexion

route:
  group_by: ['alertname']    # La methode de groupement des alertes
  group_wait: 30s    # Le temps d'attente avant d'envoyer la première alerte groupée
  group_interval: 5m    # L'intervalle entre les envois d'alertes groupées
  repeat_interval: 1h    # L'intervalle de répétition des alertes
  receiver: "email-alert"    # Le nom du récepteur des alertes

receivers:
  - name: "email-alert"
    email_configs:
      - to: "exemple@gmail.com"    # L'adresse email du destinataire
```
### Générer un mot de passe d'application pour `smtp_auth_password`:
  - Connectez-vous à votre compte Google.
  - Accédez à Sécurité.
  - Sous "Validation en deux étapes", sélectionnez "Mots de passe d'application" (Validation en deux étapes doit être activé).
  - Suivez les instructions pour générer un mot de passe d'application.

<div align="center">
  <img src="Images/Password.png" alt="mot de passe d'application">
</div><br>

  - Utilisez ce mot de passe dans votre configuration Alertmanager.
### Recevoir des alertes par mail :
<div align="center">
  <img src="Images/MailAlert.png" alt="Alerts par Mail">
</div>

---

## Migration vers Traefik :
### 1. Modification des configuration du reverse proxy:
  - Supression des configurations de caddy
  - Ajout des configuration de Traefik
### Ouvrir le fichier de configuration:
```bash
sudo nano docker-compose.yml
```
### Supression de la configuration de caddy:
```yaml
  caddy:
    image: caddy:2.8.4
    container_name: caddy
    ports:
      - "3001:3000"
      - "8081:8080"
      - "9094:9090"
      - "9095:9093"
      - "9096:9091"
    volumes:
      - ./caddy:/etc/caddy
    environment:
      - ADMIN_USER=${ADMIN_USER:-admin}
      - ADMIN_PASSWORD=${ADMIN_PASSWORD:-admin}
      - ADMIN_PASSWORD_HASH=${ADMIN_PASSWORD_HASH:-$2a$14$1l.IozJx7xQRVmlkEQ32OeEEfP5mRxTpbDTCTcXRqn19gXD8YK1pO}
    restart: unless-stopped
    networks:
      - monitor-net
    labels:
      org.label-schema.group: "monitoring"
```
### Supression de la configuration des ports (Traefik se base sur les routes):
```yaml
    expose:
      - xxxx
```
### Ajout de la configuration de Traefik:
```yaml
services:
  Traefik:
    image: traefik:v3.3    # Image officielle
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
    ports:
      - "80:80"    # Port HTTP
      - "8080:8080"    # Interface de Traefik sur `http://localhost:8080`
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
```

---

### 2. Configuration du routage à travers les Labels Traefik:
```yaml
  prometheus:
    image: prom/prometheus:v2.55.0
    container_name: prometheus
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    restart: unless-stopped
    labels:
      - "traefik.enable=true"   # Activer Traefik pour gérer ce conteneur.
      - "traefik.http.routers.prometheus.rule=Host(`prometheus.localhost`)"    # Définir la route vers le service Prometheus
```
Verifier les configurations sur l'interface Traefik sur: [http://localhost:8080](http://localhost:8080/dashboard/#/http/routers)

Tester les services sur: [http://prometheus.localhost](http://prometheus.localhost/)

Appliquer les configurations sur tout les services.

---

### 2. Implementation de la sécurite avec Let's Encrypt:
 - Obtention d'une certification SSL locale avec `openssl`
```bash
   mkdir -p ./letsencrypt
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout localhost.key -out localhost.crt -subj "/CN=localhost"
   # Génèrer une clé privée RSA de 2048 bits et un certificat valide pour 365 jours
```

 - Implementation de la configuration de HTTPS pour Traefik:
```yaml
  traefik:
    image: "traefik:v3.3"
    container_name: "traefik"
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--entryPoints.websecure.address=:443"   # Définit l'entrée pour le trafic HTTPS sur le port 443
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"  # Activation du défi TLS pour automatisé l'obtention et le renouvellement des certificats SSL
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"  # Définit le chemin de stockage des certificats ACME
    ports:
      - "443:443"
      - "8080:8080"
    volumes:
      - "./letsencrypt:/letsencrypt"   # Monter la certification dans le conteneurs docker
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
```
 - Implementation de la configuration de HTTPS pour l'autres services:
```yaml
  prometheus:
    image: prom/prometheus:v2.55.0
    container_name: prometheus
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(`prometheus.localhost`)"
      - "traefik.http.routers.prometheus.entrypoints=websecure" # Utiliser l'entrée sécurisée HTTPS
      - "traefik.http.routers.prometheus.tls.certresolver=myresolver"  # Utilise le résolveur de certificats pour obtenir des certificats SSL/TLS
```
Verifier les configurations sur l'interface Traefik sur: [http://localhost:8080](http://localhost:8080/dashboard/#/http/routers)

Tester les services sur: [https://prometheus.localhost](https://prometheus.localhost/)

Appliquer les configurations sur tout les services.

---

### 2. Activation de l'equilibrage de charge:
Ajout la fonctionnalité `deploy` pour les services.
```yaml
  grafana:
    image: grafana/grafana:11.3.0
    # container_name: grafana    # Enlever le nom de contenaire en cas de replication d'images
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/provisioning/dashboards:/etc/grafana/provisioning/dashboards
      - ./grafana/provisioning/datasources:/etc/grafana/provisioning/datasources
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.localhost`)"
      - "traefik.http.routers.grafana.entrypoints=websecure"
      - "traefik.http.routers.grafana.tls.certresolver=myresolver"
    deploy:
      replicas: 2    # Deux instances du conteneur Grafana
```
   
