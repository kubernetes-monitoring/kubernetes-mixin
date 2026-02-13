#!/bin/bash
set -ex

cp ../prometheus_alerts.yaml provisioning/prometheus/
cp ../prometheus_rules.yaml provisioning/prometheus/

# Create kind cluster with kube-scheduler resource metrics enabled
kind create cluster --name kubernetes-mixin --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: ClusterConfiguration
        scheduler:
          extraArgs:
            authorization-always-allow-paths: "/metrics,/metrics/resources"
            bind-address: "0.0.0.0"
    extraMounts:
    - hostPath: "$PWD/provisioning"
      containerPath: /kubernetes-mixin/provisioning
    - hostPath: "$PWD/../dashboards_out"
      containerPath: /kubernetes-mixin/dashboards_out
EOF

# Wait for cluster to be ready
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Create kube-scheduler service for metrics access
kubectl apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: kube-scheduler
  namespace: kube-system
spec:
  selector:
    component: kube-scheduler
  ports:
  - port: 10259
    targetPort: 10259
    protocol: TCP
EOF

# run grafana, prometheus
kubectl apply -f lgtm.yaml
# kubectl port-forward service/lgtm 3000:3000 4317:4317 4318:4318 9090:9090

# scrape kube-state-metrics, node_exporter, cAdvisor, kubelet, kube-proxy, kube-apiserver, kube-controller-manager, kube-scheduler... write to prometheus
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm upgrade --install otel-collector-deployment open-telemetry/opentelemetry-collector \
    -n default \
    -f otel-collector-deployment.values.yaml

# install kube-state-metrics
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install kube-state-metrics prometheus-community/kube-state-metrics \
    -n default

# install node_exporter
helm upgrade --install prometheus-node-exporter prometheus-community/prometheus-node-exporter \
    -n default

# TODO OATs:
# https://github.com/grafana/oats

# test metrics in prometheus
# test recording rules in prometheus
# test alerting rules in prometheus
# e2e test dashboards?
