local slo = import 'slo-libsonnet/slo.libsonnet';

{
  _config+:: {
    SLOs: {
      apiserver: {
        // This is templating a Multiple Burn Rate Alerts for Kubernetes Apiservers.
        // We will alert on burning too much error budget over 30 days.
        // By default we have 99% availability (1% unavailability = 7h12m in 30d).
        errors: slo.errorburn({
          metric: 'apiserver_request_total',
          selectors: [$._config.kubeApiserverSelector],
          errorBudget: 1 - 0.99,
        }),
      },
    },

    // Selectors are inserted between {} in Prometheus queries.
    cadvisorSelector: 'job="cadvisor"',
    kubeletSelector: 'job="kubelet"',
    kubeStateMetricsSelector: 'job="kube-state-metrics"',
    nodeExporterSelector: 'job="node-exporter"',
    kubeSchedulerSelector: 'job="kube-scheduler"',
    kubeControllerManagerSelector: 'job="kube-controller-manager"',
    kubeApiserverSelector: 'job="kube-apiserver"',
    kubeProxySelector: 'job="kube-proxy"',
    podLabel: 'pod',
    hostNetworkInterfaceSelector: 'device!~"veth.+"',
    hostMountpointSelector: 'mountpoint="/"',
    wmiExporterSelector: 'job="wmi-exporter"',

    // Grafana dashboard IDs are necessary for stable links for dashboards
    grafanaDashboardIDs: {
      'k8s-resources-multicluster.json': '1gBgaexoVZ4TpBNAt2eGRsc4LNjNhdjcZd6cqU6S',
      'k8s-resources-cluster.json': 'ZnbvYbcXkob7GLqcDPLTj1ZL4MRX87tOh8xdr831',
      'k8s-resources-namespace.json': 'XaY4UCP3J51an4ikqtkUGBSjLpDW4pg39xe2FuxP',
      'k8s-resources-pod.json': 'wU56sdGSNYZTL3eO0db3pONtVmTvsyV7w8aadbYF',
      'k8s-multicluster-rsrc-use.json': 'NJ9AlnsObVgj9uKiJMeAqfzMi1wihOMupcsDhlhR',
      'k8s-cluster-rsrc-use.json': 'uXQldxzqUNgIOUX6FyZNvqgP2vgYb78daNu4GiDc',
      'k8s-node-rsrc-use.json': 'E577CMUOwmPsxVVqM9lj40czM1ZPjclw7hGa7OT7',
      'nodes.json': 'kcb9C2QDe4IYcjiTOmYyfhsImuzxRcvwWC3YLJPS',
      'persistentvolumesusage.json': 'AhCeikee0xoa6faec0Weep2nee6shaiquigahw8b',
      'pods.json': 'AMK9hS0rSbSz7cKjPHcOtk6CGHFjhSHwhbQ3sedK',
      'statefulset.json': 'dPiBt0FRG5BNYo0XJ4L0Meoc7DWs9eL40c1CRc1g',
      'k8s-resources-windows-cluster.json': '4d08557fd9391b100730f2494bccac68',
      'k8s-resources-windows-namespace.json': '490b402361724ab1d4c45666c1fa9b6f',
      'k8s-resources-windows-pod.json': '40597a704a610e936dc6ed374a7ce023',
      'k8s-windows-cluster-rsrc-use.json': '53a43377ec9aaf2ff64dfc7a1f539334',
      'k8s-windows-node-rsrc-use.json': '96e7484b0bb53b74fbc2bcb7723cd40b',
      'k8s-resources-workloads-namespace.json': 'L29WgMrccBDauPs3Xsti3fwaKjMB6fReufWj6Gl1',
      'k8s-resources-workload.json': 'hZCNbUPfUqjc95N3iumVsaEVHXzaBr3IFKRFvUJf',
      'apiserver.json': 'eswbt59QCroA3XLdKFvdOHlKB8Iks3h7d2ohstxr',
      'controller-manager.json': '5g73oHG0pCRz4X1t6gNYouVUv9urrQd4wCdHR2mI',
      'scheduler.json': '4uMPZ9jmwvYJcM5fcNcNrrt9Sf6ufQL4IKFri2Gp',
      'proxy.json': 'hhT4orXD1Ott4U1bNNps0R26EHTwMypdcaCjDRPM',
      'kubelet.json': 'B1azll2ETo7DTiM8CysrH6g4s5NCgkOz6ZdU8Q0j',
    },

    // Config for the Grafana dashboards in the Kubernetes Mixin
    grafanaK8s: {
      dashboardNamePrefix: 'Kubernetes / ',
      dashboardTags: ['kubernetes-mixin'],

      // For links between grafana dashboards, you need to tell us if your grafana
      // servers under some non-root path.
      linkPrefix: '.',
    },

    // Opt-in to multiCluster dashboards by overriding this and the clusterLabel.
    showMultiCluster: false,
    clusterLabel: 'cluster',

    namespaceLabel: 'namespace',

    // This list of filesystem is referenced in various expressions.
    fstypes: ['ext[234]', 'btrfs', 'xfs', 'zfs'],
    fstypeSelector: 'fstype=~"%s"' % std.join('|', self.fstypes),

    // This list of disk device names is referenced in various expressions.
    diskDevices: ['nvme.+', 'rbd.+', 'sd.+', 'vd.+', 'xvd.+', 'dm-.+', 'dasd.+'],
    diskDeviceSelector: 'device=~"%s"' % std.join('|', self.diskDevices),
  },
}
