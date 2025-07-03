#!/bin/bash

set -ex

# export time in milliseconds
# export OTEL_METRIC_EXPORT_INTERVAL=500

# use http instead of https (needed because of https://github.com/open-telemetry/opentelemetry-go/issues/4834)
# export OTEL_EXPORTER_OTLP_INSECURE="true"

# https://github.com/grafana/docker-otel-lgtm/tree/main/examples

# docker run -p 3001:3000 -p 4317:4317 -p 4318:4318 \
#     -v ./provisioning/dashboards:/otel-lgtm/grafana/conf/provisioning/dashboards \
#     -v ../dashboards_out:/kubernetes-mixin/dashboards_out \
#     --rm -ti grafana/otel-lgtm

# set up 1-node k3d cluster
k3d cluster create kubernetes-mixin \
    -v "$PWD"/provisioning:/kubernetes-mixin/provisioning \
    -v "$PWD"/../dashboards_out:/kubernetes-mixin/dashboards_out

# run grafana, prometheus
# install dashboards in grafana
# wget https://raw.githubusercontent.com/grafana/docker-otel-lgtm/refs/heads/main/k8s/lgtm.yaml
kubectl apply -f lgtm.yaml
# kubectl port-forward service/lgtm 3001:3000 4317:4317 4318:4318

# scrape kube-state-metrics, node_exporter, cAdvisor, kubelet, kube-proxy, kube-apiserver, kube-controller-manager, kube-scheduler... write to prometheus
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update
helm upgrade --install otel-collector-deployment open-telemetry/opentelemetry-collector \
		-n default \
		-f otel-collector-deployment.values.yaml

# TODO install kube-state-metrics, node_exporter

# TODO OATs:
# https://github.com/grafana/oats
# test metrics in prometheus
# test recording rules in prometheus
# test alerting rules in prometheus

# TODO: e2e test dashboards?
