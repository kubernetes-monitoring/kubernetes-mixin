# Prometheus Monitoring Mixin for Kubernetes

A set of Grafana dashboards and Prometheus alerts for Kubernetes.

## To use

Generally you want to vendor this repo with your infrastructure config.
To do this, use [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

```
$ jb install github.com/kubernetes-monitoring/kubernetes-mixin
```

You can then generate the alerts, dashboards and rules:

```
$ make prometheus_alerts.yaml
$ make prometheus_rules.yaml
$ make dashboards
```

You can also use the mixin with other packages:

```
local kubernetes_mixin = (import "kubernetes-mixin/mixin.libsonnet");
```

## Background

* For more motivation, see
"[The RED Method: How to instrument your services](https://kccncna17.sched.com/event/CU8K/the-red-method-how-to-instrument-your-services-b-tom-wilkie-kausal?iframe=no&w=100%&sidebar=yes&bg=no)" talk from CloudNativeCon Austin.
* For more information about monitoring mixins, see this [design doc](https://docs.google.com/document/d/1A9xvzwqnFVSOZ5fD3blKODXfsat5fg6ZhnKu9LK3lB4/edit#).
