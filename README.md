# Stack-Monitoring-Project
PrProjet de Stack Monitoring avec Prometheus, Grafana et Traefik

1/ Clonage du répertoire Github :
 ``` git clone https://github.com/stefanprodan/dockprom.git ```

2/ Installation des exportateurs sur les machines cibles (Node Exporter, cAdvisor) :
  - Nodeexporter :
```bash
docker run -d -p 9100:9100 --name=node_exporter --privileged prom/node-exporter
```
  -  Cadvisor :
```bash
docker run -d -p 8000:8080 --name=cadvisor --privileged gcr.io/cadvisor/cadvisor
```
3/ Ajout des cibles dans Prometheus pour superviser les métriques collectées par les exportateurs :
```bash
sudo nano prometheus/prometheus.yml
```
- Ajouter les cibles dans le fichier de configuration de Prometheus :
  ```
  scrape_configs:
    - job_name: 'exportateurs'  # Peut être nodeexporter, cadvisor ou pushgateway dans notre cas
      scrape_interval: 5s      # Intervalle entre chaque collecte des métriques
      static_configs:
        - targets:             # Liste des cibles
          - "ip:port"          # Adresse IP et port de la machine à superviser
  ```
4/ Verification de la collecte de metriques :
  - Monter les contenaires:
  ```bash
  docker-compose up -d
  ```
  - Acceder au service prometheus:
  ```
  http://localhost:9090
  ```
  <div align="center">
  <img src="prometheus.png" alt="Prometheus Targets">
  </div>
  
5/ Ajouter Prometheus comme source de données pour grafana :
  - Acceder au service grafana:
  ```
  http://localhost:3000
  ```
  - Naviger vers : ***Data Sources → Add Data Source***
