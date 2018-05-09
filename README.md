# Prometheus Monitoring Mixin for Kubernetes

> NOTE: This project is *alpha* stage. Flags, configuration, behaviour and design may change significantly in following releases.

A set of Grafana dashboards and Prometheus alerts for Kubernetes.

## How to use

This mixin is designed to be vendored into the repo with your infrastructure config.
To do this, use [jsonnet-bundler](https://github.com/jsonnet-bundler/jsonnet-bundler):

You then have three options for deploying your dashboards
1. Generate the config files and deploy them yourself
1. Use ksonnet to deploy this mixin along with Prometheus and Grafana
1. Use prometheus-operator to deploy this mixin (TODO)

## Generate config files

You can manually generate the alerts, dashboards and rules files, but first you
must install some tools:

```
$ go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
$ brew install jsonnet
```

Then, grab the mixin and its dependencies:

```
$ git clone https://github.com/kubernetes-monitoring/kubernetes-mixin
$ cd kubernetes-mixin
$ jb install
```

Finally, build the mixin:

```
$ make prometheus_alerts.yaml
$ make prometheus_rules.yaml
$ make dashboards_out
```

The `prometheus_alerts.yaml` and `prometheus_rules.yaml` file then need to passed
to your Prometheus server, and the files in `dashboards_out` need to be imported
into you Grafana server.  The exact details will depending on how you deploy your
monitoring stack to Kubernetes.

## Using with prometheus-ksonnet

Alternatively you can also use the mixin with
[prometheus-ksonnet](https://github.com/kausalco/public/tree/master/prometheus-ksonnet),
a [ksonnet](https://github.com/ksonnet/ksonnet) module to deploy a fully-fledged
Prometheus-based monitoring system for Kubernetes:

Make sure you have the ksonnet v0.8.0:

```
$ brew install ksonnet/tap/ks
$ ks version
ksonnet version: v0.8.0
jsonnet version: v0.9.5
client-go version: v1.6.8-beta.0+$Format:%h$
```

In your config repo, if you don't have a ksonnet application, make a new one (will copy credentials from current context):

```
$ ks init <application name>
$ cd <application name>
$ ks env add default
```

Install the kubernetes-jsonnet package:

```
$ ks registry add kausal https://github.com/kausalco/public
$ ks pkg install kausal/prometheus-ksonnet
```

Install kubernetes-mixin:

```
$ go get github.com/jsonnet-bundler/jsonnet-bundler/cmd/jb
$ jb init
$ jb install github.com/kubernetes-monitoring/kubernetes-mixin
```

Assuming you want to run in the default namespace ('environment' in ksonnet parlance), add the follow to the file `environments/default/main.jsonnet`:

```
local prometheus = import "prometheus-ksonnet/prometheus-ksonnet.libsonnet";
local kubernetes = import "kubernetes-mixin/mixin.libsonnet";

prometheus + kubernetes {
  _config+:: {
    namespace: "default",
  },
}
```

Apply your config:

```
$ ks apply default
```

## Using prometheus-operator

TODO

## Customising the mixin

Kubernetes-mixin allows you to override the selectors used for various jobs,
to match those used in your Prometheus set.

In a new directory, add a file `mixin.libsonnet`:

```
local kubernetes = import "kubernetes-mixin/mixin.libsonnet";

kubernetes {
  _config+:: {
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    cadvisorSelector: 'job="kubernetes-cadvisor"',
    nodeExporterSelector: 'job="kubernetes-node-exporter"',
    kubeletSelector: 'job="kubernetes-kubelet"',
  },
}
```

Then, install the kubernetes-mixin:

```
$ jb init
$ jb install github.com/kubernetes-monitoring/kubernetes-mixin
```

Generate the alerts, rules and dashboards:

```
$ jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusAlerts)' > alerts.yml
$ jsonnet -J vendor -S -e 'std.manifestYamlDoc((import "mixin.libsonnet").prometheusRules)' >files/rules.yml
$ jsonnet -J vendor -m files/dashboards -e '(import "mixin.libsonnet").grafanaDashboards'
```

## Background

* For more motivation, see
"[The RED Method: How to instrument your services](https://kccncna17.sched.com/event/CU8K/the-red-method-how-to-instrument-your-services-b-tom-wilkie-kausal?iframe=no&w=100%&sidebar=yes&bg=no)" talk from CloudNativeCon Austin.
* For more information about monitoring mixins, see this [design doc](https://docs.google.com/document/d/1A9xvzwqnFVSOZ5fD3blKODXfsat5fg6ZhnKu9LK3lB4/edit#).
