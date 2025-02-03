# Stack-Monitoring-Project
Stack Monitoring Project with Prometheus, Grafana, and Traefik.

## Installation and Configuration Steps

### 1. Cloning the GitHub Repository
Clone the project from the following repository:

```bash
git clone https://github.com/stefanprodan/dockprom.git
```

---

### 2. Installing Exporters on Target Machines
Configure the **Node Exporter** and **cAdvisor** tools to collect metrics from target machines.

#### - Node Exporter:

```bash
docker run -d \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  quay.io/prometheus/node-exporter:latest \
  --path.rootfs=/host
```

#### - cAdvisor:

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

#### - Pushgateway:

```bash
docker pull prom/pushgateway
docker run -d -p 9091:9091 prom/pushgateway
```

---

### 3. Adding Targets to Prometheus
Add the targets in the Prometheus configuration file to monitor the collected metrics.

#### Open the configuration file:

```bash
sudo nano prometheus/prometheus.yml
```

#### Add the targets:

```yaml
scrape_configs:
  - job_name: 'exporters'  # Can be node_exporter, cAdvisor, or pushgateway
    scrape_interval: 5s    # Interval between each metric collection
    static_configs:
      - targets:           # List of targets
        - "ip:port"        # IP address and port of the monitored machine
```

---

### 4. Verifying Metric Collection
#### - Start the containers:

```bash
docker-compose up -d
```

#### - Access the Prometheus service:
Open your browser and go to: [http://localhost:9090](http://localhost:9090)

<div align="center">
  <img src="Images/prometheus.png" alt="Prometheus Targets">
</div>

---

### 5. Adding Prometheus as a Data Source in Grafana
#### - Access Grafana:
Open your browser and go to: [http://localhost:3000](http://localhost:3000)

#### - Add Prometheus as a data source:
1. Navigate to **Data Sources → Add Data Source**.  
2. Search for **Prometheus** in the list.  
<div align="center">
  <img src="Images/Ajouter Prometheus.png" alt="Add Prometheus">
</div>

3. In the **Connection** section, add the Prometheus server URL: http://localhost:9090.
4. Save the changes.

---

### 6. Implementing Dashboards in Grafana
1. Navigate to **Dashboards → New → Import →** Select a dashboard.

#### Note:
You can add dashboards in two ways:
- By adding a JSON file corresponding to the dashboard.
- By using the appropriate dashboard ID directly:
  - For machines: **1860**
  - For containers: **11600**

2. Choose the data source: **Prometheus**.

<div align="center">
  <img src="Images/Dashboard.png" alt="Dashboard">
</div>

---

### 7. Creating Alerts
#### Create the alert file:

```bash
sudo nano prometheus/alerts.yml
```

#### Add alerts:

```yaml
groups:
  - name: node_alerts  # Alert group name
    rules:
      - alert: High CPU  # Alert name
        expr: 100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) by (instance)) * 100 > 70  # Alert condition
        for: 1m  # Delay before considering the alert active
        labels:
          severity: warning  # Alert severity level
          resolve_automatically: true  # Auto-resolve alert
        annotations:
          summary: High CPU usage for {{ $labels.instance }}
          description: The target {{ $labels.instance }} is using {{ $value }}% CPU
```

### Link the alert file in the main configuration file:
Add this line in `prometheus.yml`:

```yaml
rule_files:
  - "alerts.yml"
```

### Restart Prometheus to apply changes:

```yaml
docker-compose restart prometheus
```

<div align="center">
  <img src="Images/Alerts.png" alt="Alerts">
</div>

---

### 8. Configuring Alertmanager for Email Notifications
#### Open the configuration file:

```bash
nano alertmanager/config.yml
```

#### Add the configuration:

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'  # SMTP server
  smtp_from: 'example@gmail.com'  # Sender email address
  smtp_auth_username: 'username'  # Username
  smtp_auth_password: 'password'  # SMTP authentication password
  smtp_require_tls: true  # Secure connection

route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  receiver: "email-alert"

receivers:
  - name: "email-alert"
    email_configs:
      - to: "example@gmail.com"  # Recipient email address
```

### Generate an App Password for `smtp_auth_password`:
  - Log into your Google account.
  - Go to Security settings.
  - Under "Two-step verification," select "App passwords" (Two-step verification must be enabled).
  - Follow the instructions to generate an app password.

<div align="center">
  <img src="Images/Password.png" alt="App Password">
</div><br>

  - Use this password in your Alertmanager configuration.
### Receive Email Alerts:
<div align="center">
  <img src="Images/MailAlert.png" alt="Email Alerts">
</div>

---

## Migration to Traefik

### 1. Modifying Reverse Proxy Configuration
  - Removing Caddy configurations
  - Adding Traefik configurations

### Open the configuration file:
```bash
sudo nano docker-compose.yml
```

### Removing Caddy configuration:
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

### Removing port configurations (Traefik relies on routes):
```yaml
    expose:
      - xxxx
```

### Adding Traefik configuration:
```yaml
services:
  Traefik:
    image: traefik:v3.3    # Official image
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
    ports:
      - "80:80"    # HTTP port
      - "8080:8080"    # Traefik interface at `http://localhost:8080`
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
```

---

### 2. Configuring Routing with Traefik Labels
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
      - "traefik.enable=true"   # Enable Traefik for this container.
      - "traefik.http.routers.prometheus.rule=Host(`prometheus.localhost`)"    # Define route to Prometheus service
```
Verify configurations in Traefik dashboard: [http://localhost:8080](http://localhost:8080/dashboard/#/http/routers)

Test services at: [http://prometheus.localhost](http://prometheus.localhost/)

Apply configurations to all services.

---

### 3. Implementing Security with Let's Encrypt
 - Obtain a local SSL certificate using `openssl`
```bash
   mkdir -p ./letsencrypt
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout localhost.key -out localhost.crt -subj "/CN=localhost"
```

 - Configuring HTTPS for Traefik:
```yaml
  traefik:
    image: "traefik:v3.3"
    container_name: "traefik"
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--entryPoints.websecure.address=:443"   # Define entry point for HTTPS traffic on port 443
      - "--certificatesresolvers.myresolver.acme.tlschallenge=true"  # Enable TLS challenge for automated SSL certificate management
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"  # Define certificate storage path
    ports:
      - "443:443"
      - "8080:8080"
    volumes:
      - "./letsencrypt:/letsencrypt"   # Mount certification inside the Docker container
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
```

 - Configuring HTTPS for other services:
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
      - "traefik.http.routers.prometheus.entrypoints=websecure" # Use secure HTTPS entry
      - "traefik.http.routers.prometheus.tls.certresolver=myresolver"  # Use certificate resolver for SSL/TLS certificates
```
Verify configurations in Traefik dashboard: [http://localhost:8080](http://localhost:8080/dashboard/#/http/routers)

Test services at: [https://prometheus.localhost](https://prometheus.localhost/)

Apply configurations to all services.

---

### 4. Enabling Load Balancing
Adding `deploy` functionality for services.
```yaml
  grafana:
    image: grafana/grafana:11.3.0
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
      replicas: 2    # Two instances of the Grafana container
```



