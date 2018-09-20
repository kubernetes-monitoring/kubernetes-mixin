{
  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kubernetes-system',
        rules: [
          {
            expr: |||
              kube_node_status_condition{%(kubeStateMetricsSelector)s,condition="Ready",status="true"} == 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: '{{ $labels.node }} has been unready for more than an hour',
            },
            'for': '1h',
            alert: 'KubeNodeNotReady',
          },
          {
            alert: 'KubeVersionMismatch',
            expr: |||
              count(count(kubernetes_build_info{%(notKubeDnsSelector)s}) by (gitVersion)) > 1
            ||| % $._config,
            'for': '1h',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'There are {{ $value }} different versions of Kubernetes components running.',
            },
          },
          {
            alert: 'KubeClientErrors',
            // Many clients use get requests to check the existance of objects,
            // this is normal and an expected error, therefore it should be
            // ignored in this alert.
            expr: |||
              (sum(rate(rest_client_requests_total{code!~"2..|404"}[5m])) by (instance, job)
                /
              sum(rate(rest_client_requests_total[5m])) by (instance, job))
              * 100 > 1
            |||,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: "Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance }}' is experiencing {{ printf \"%0.0f\" $value }}% errors.'",
            },
          },
          {
            alert: 'KubeClientErrors',
            expr: |||
              sum(rate(ksm_scrape_error_total{%(kubeStateMetricsSelector)s}[5m])) by (instance, job) > 0.1
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: "Kubernetes API server client '{{ $labels.job }}/{{ $labels.instance }}' is experiencing {{ printf \"%0.0f\" $value }} errors / sec.'",
            },
          },
          {
            alert: 'KubeletTooManyPods',
            expr: |||
              kubelet_running_pod_count{%(kubeletSelector)s} > %(kubeletPodLimit)s * 0.9
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Kubelet {{$labels.instance}} is running {{$value}} pods, close to the limit of %d.' % $._config.kubeletPodLimit,
            },
          },
          {
            alert: 'KubeAPILatencyHigh',
            expr: |||
              cluster_quantile:apiserver_request_latencies:histogram_quantile{%(kubeApiserverSelector)s,quantile="0.99",subresource!="log",verb!~"^(?:LIST|WATCH|WATCHLIST|PROXY|CONNECT)$"} > 1
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'The API server has a 99th percentile latency of {{ $value }} seconds for {{$labels.verb}} {{$labels.resource}}.',
            },
          },
          {
            alert: 'KubeAPILatencyHigh',
            expr: |||
              cluster_quantile:apiserver_request_latencies:histogram_quantile{%(kubeApiserverSelector)s,quantile="0.99",subresource!="log",verb!~"^(?:LIST|WATCH|WATCHLIST|PROXY|CONNECT)$"} > 4
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'The API server has a 99th percentile latency of {{ $value }} seconds for {{$labels.verb}} {{$labels.resource}}.',
            },
          },
          {
            alert: 'KubeAPIErrorsHigh',
            expr: |||
              sum(rate(apiserver_request_count{%(kubeApiserverSelector)s,code=~"^(?:5..)$"}[5m])) without(instance, %(podLabel)s)
                /
              sum(rate(apiserver_request_count{%(kubeApiserverSelector)s}[5m])) without(instance, pod) * 100 > 15
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'API server is erroring for {{ $value }}% of requests.',
            },
          },
          {
            alert: 'KubeAPIErrorsHigh',
            expr: |||
              sum(rate(apiserver_request_count{%(kubeApiserverSelector)s,code=~"^(?:5..)$"}[5m])) without(instance, %(podLabel)s)
                /
              sum(rate(apiserver_request_count{%(kubeApiserverSelector)s}[5m])) without(instance, pod) * 100 > 5
            ||| % $._config,
            'for': '10m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'API server is erroring for {{ $value }}% of requests.',
            },
          },
          {
            alert: 'KubeClientCertificateExpiration',
            expr: |||
              histogram_quantile(0.01, sum by (job, le) (rate(apiserver_client_certificate_expiration_seconds_bucket{%(kubeApiserverSelector)s}[5m]))) < %(certExpirationWarningSeconds)s
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Kubernetes API certificate is expiring in less than %d days.' % ($._config.certExpirationWarningSeconds / 3600 / 24),
            },
          },
          {
            alert: 'KubeClientCertificateExpiration',
            expr: |||
              histogram_quantile(0.01, sum by (job, le) (rate(apiserver_client_certificate_expiration_seconds_bucket{%(kubeApiserverSelector)s}[5m]))) < %(certExpirationCriticalSeconds)s
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'Kubernetes API certificate is expiring in less than %d day.' % ($._config.certExpirationCriticalSeconds / 3600 / 24),
            },
          },
        ],
      },
    ],
  },
}
