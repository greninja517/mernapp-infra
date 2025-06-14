###  Accessing the ArgoCD  server locally
Once, the CI pipeline provision the GKE cluster. Then, folow these steps to access the argocd server ui on your local machine through ssh port forwarding using the bastion host.
1. SSH into bastion host from your local machine
```bash
ssh -i <private-key> username@BASTION_PUBLIC_IP
```

2. Verify the installation of tools like kubectl, helm, gcloud in the bastion host which is done by the bootstrap script.

3. Set up the kubectl context to interact with GKE on the bastion host

```bash
gcloud container clusters get-credentials CLUSTER_NAME  --region REGION --project PROJECT_ID
```

4. Install argocd on the cluster ( Bastion Host )
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

5. Verify the argocd installation ( Bastion Host )
```bash
kubectl get all -n argocd
```

6. Get the ArgoCD admin password ( Bastion Host )
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o  jsonpath="{.data.password}" | base64 -d
```

7. Set up Port Forwarding

i. SSH port forwarding ( Run on local machine )
```bash
ssh -i <private-key-path> -L 8080:localhost:8080 username@BASTION_PUBLIC_IP
```

ii. Kubectl port forwarding ( Run on bastion Host )

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:80
```

8. Now, You can Access ArgoCD in your `http:localhost:8080`

---
### Managing the MongoDB Secrets using KubeSeal
We will use the bitnami's kubeseal controller to encrypt our DB secrets so that they can be pushed safely to github and the GitOps controller will be able to take it during the syncing phase.
#### 1. Install the Kubeseal Controller
i. Add the HELM repo
```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```
ii. Install the Chart
```bash
helm install sealed-secrets-controller bitnami/sealed-secrets --namespace kube-system
```
#### 2. Install the `kubeseal` CLI
```bash
# Fetch the latest sealed-secrets version using GitHub API
KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/tags | jq -r '.[0].name' | cut -c 2-)

# Check if the version was fetched successfully
if [ -z "$KUBESEAL_VERSION" ]; then
    echo "Failed to fetch the latest KUBESEAL_VERSION"
    exit 1
fi

curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```
#### 3. Use the tool
i. Create your DB secret as normal Kubernetes Secret `dbsecret.yaml` but don't apply it on the cluster

ii. Encrypt the secret using this command. This will encrypt the secret using the controller public key and generate an encrypted file.
```bash
kubeseal --controller-name=sealed-secrets-controller --controller-namespace=kube-system --format=yaml < dbsecret.yaml > sealed_db_secret.yaml
```
iii. Now, the SealedSecret is safe to push in github. Only the controller in the cluster can decrypt it.

iv. When the GitOps controller like ArgoCD applies this SealedSecret in the cluster, the same Kubernetes Secret will be created that you have encrypted earlier.

---

### Manual Installation of Monitoring Stack ( Prometheus, Grafana, Loki, Promtail ) in the Cluster

We will use helm to install the entire monitoring stack.
#### 1. Installing Prometheus and Grafana using kube-prometheus-stack HELM chart

i. Add the repository. 
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

ii. Install the helm chart. This will install **Prometheus**, **Grafana**, **AlertManager** and few exporters as well.
```bash
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace
```
iii. Verify the installation
```bash
kubectl get all -n monitoring
```
iv. Get the grafana default password
```bash
kubectl get secret kube-prometheus-stack-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
```
**Note**: *You need to port forward the grafana service as well to access from your local browser. Also, you need to setup SSH port forwarding as well like as that of ArgoCD.*

#### 2. Installing Loki and Promtail
i. Add the HELM repo
```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```
ii. Install the **Loki** chart
`loki-values.yaml` 
```yaml
# Number of replicas
singleBinary:
  replicas: 1

# Component replicas
write:
  replicas: 0
read:
  replicas: 0
backend:
  replicas: 0

# Caching
chunksCache:
  enabled: false
resultsCache:
  enabled: false

# Helm test
test:
  enabled: false

# All loki settings combined under one key
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
    filesystem:
      directory: /var/loki/chunks
  useTestSchema: true

```
```bash
helm install loki grafana/loki -n monitoring -f loki-values.yaml
```

iii. Install the **Promtail** Chart
```yaml
config:
  clients:
    - url: http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push
```
```bash
helm install promtail -n monitoring grafana/promtail -f promtail-values.yaml 
```
Now, the Promtail is configured to send logs to Loki. Still, you need to configure Loki data source in the Grafana to visualize the logs collected by Loki.

#### 3. Configuring the Promtheus Alert Rules and AlertManager to send Email Notifications
i. `prometheus-email-alerting-rules.yaml` file:
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: critical-node-alerts
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
  - name: node.high.utilization.alerts
    rules:
    - alert: NodeCPUUsageCritical
      expr: (100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 60
      for: 2m
      labels:
        severity: critical
        type: node
        namespace: monitoring
      annotations:
        summary: "High CPU Usage on {{ $labels.instance }} (Node: {{ $labels.node | default $labels.instance }})"
        description: |
          CPU utilization on node {{ $labels.node | default $labels.instance }} (IP: {{ $labels.instance }}) has exceeded 60% for the last 2 minutes.
          Current value: {{ $value | printf \"%.2f\" }}%.

    - alert: NodeMemoryUsageCritical
      expr: (1 - (node_memory_MemAvailable_bytes{job="node-exporter"} / node_memory_MemTotal_bytes{job="node-exporter"})) * 100 > 70
      for: 2m
      labels:
        severity: critical
        type: node
        namespace: monitoring
      annotations:
        summary: "High Memory Usage on {{ $labels.instance }} (Node: {{ $labels.node | default $labels.instance }})"
        description: |
          Memory utilization on node {{ $labels.node | default $labels.instance }} (IP: {{ $labels.instance }}) has exceeded 70% for the last 2 minutes.
          Current value: {{ $value | printf \"%.2f\" }}%.

  - name: node.availability.alerts
    rules:
    - alert: ClusterNodeAvailabilityLow
      expr: |
        (sum(kube_node_status_condition{condition="Ready", status="true"})
        / count(kube_node_status_condition{condition="Ready", status="true"})) * 100
      for: 2m
      labels:
        severity: critical
        type: kubernetes
      annotations:
        summary: "Less than 50% nodes are Available"
        description: "Only {{ $value | printf \"%.2f\" }}% of nodes are in Ready state for the last 2 minutes."
```
ii. `alertmanager-config-email.yaml` file
```yaml
---
apiVersion: monitoring.coreos.com/v1alpha1
kind: AlertmanagerConfig
metadata:
  name: email-notifications
  namespace: monitoring
spec:
  route:
    receiver: null-receiver
    groupBy:
      - alertname
      - severity
      - job
    groupWait: 30s
    groupInterval: 5m
    repeatInterval: 4h
    routes:
      - receiver: critical-alerts-email
        matchers:
          - name: severity
            value: critical
            matchType: =
        continue: false
  receivers:
    - name: null-receiver
    - name: critical-alerts-email
      emailConfigs:
        - to: receiver@gmail.com
          from: sender@gmail.com
          smarthost: smtp.gmail.com:587
          authUsername: sender@gmail.com
          authPassword:
            name: email-secret # name of k8s secret that contains the password of gmail account
            key: password # key of the secret
          requireTLS: true
```
iii. Create a Kuberenetes Secret  named `email-secret` containing the password of account ( The App Password if using Gmail ).

iv. Apply all these manifests to the cluster
```bash
kubectl apply -f prometheus-email-alerting-rules.yaml -f <secret-file.yaml> -f alertmanager-config-email.yaml
```
Now, Alerting is also configured.
