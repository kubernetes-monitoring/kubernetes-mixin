{
  _config+:: {
    // Selectors are inserted between {} in Prometheus queries.
    cadvisor_selector: 'job="kubernetes-nodes"',
    kubelet_selector: 'job="kube-system/kubelet"',
    kube_state_metrics_selector: 'job="default/kube-state-metrics"',
    node_exporter_selector: 'job="default/node-exporter"',
    not_kube_dns_selector: 'job!="kube-system/kube-dns"',

    // We alert when the aggregate (CPU, Memory) quota for all namespaces is
    // greater than the amount of the resources in the cluster.  We do however
    // allow you to overcommit if you wish.
    namespace_overcommit_factor: 1.5,

    // For links between grafana dashboards, you need to tell us if your grafana
    // servers under some non-root path.
    grafana_prefix: '',
  },
}
