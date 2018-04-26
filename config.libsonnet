{
  _config+:: {
    // Selectors are inserted between {} in Prometheus queries.
    cadvisorSelector: 'job="kube-system/cadvisor"',
    kubeletSelector: 'job="kube-system/kubelet"',
    kubeStateMetricsSelector: 'job="default/kube-state-metrics"',
    nodeExporterSelector: 'job="default/node-exporter"',
    notKubeDnsSelector: 'job!="kube-system/kube-dns"',

    // We alert when the aggregate (CPU, Memory) quota for all namespaces is
    // greater than the amount of the resources in the cluster.  We do however
    // allow you to overcommit if you wish.
    namespaceOvercommitFactor: 1.5,

    // For links between grafana dashboards, you need to tell us if your grafana
    // servers under some non-root path.
    grafanaPrefix: '',
  },
}
