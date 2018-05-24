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
            expr: |||
              sum(rate(rest_client_requests_total{code!~"2.."}[5m])) by (instance, job) * 100
                /
              sum(rate(rest_client_requests_total[5m])) by (instance, job)
                > 1
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
              kubelet_running_pod_count{%(kubeletSelector)s} > %(kubeletTooManyPods)s
            ||| % $._config,
            'for': '15m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Kubelet {{$labels.instance}} is running {{$value}} pods, close to the limit of 110.',
            },
          },
          {
            alert: 'KubeAPILatencyHigh',
            expr: |||
              cluster_quantile:apiserver_request_latencies:histogram_quantile{%(kubeApiserverSelector)s,quantile="0.99",subresource!="log",verb!~"^(?:WATCH|WATCHLIST|PROXY|CONNECT)$"} > 1
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
              cluster_quantile:apiserver_request_latencies:histogram_quantile{%(kubeApiserverSelector)s,quantile="0.99",subresource!="log",verb!~"^(?:WATCH|WATCHLIST|PROXY|CONNECT)$"} > 4
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
              sum(rate(apiserver_request_count{%(kubeApiserverSelector)s}[5m])) without(instance, pod) * 100 > 5
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
            alert: 'KubeCertificateExpiration',
            expr: |||
              sum(apiserver_client_certificate_expiration_seconds_bucket{%(kubeApiserverSelector)s,le="604800"}) > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Kubernetes API certificate is expiring in less than 7 days.',
            },
          },
          {
            alert: 'KubeCertificateExpiration',
            expr: |||
              sum(apiserver_client_certificate_expiration_seconds_bucket{%(kubeApiserverSelector)s,le="86400"}) > 0
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'Kubernetes API certificate is expiring in less than 1 day.',
            },
          },
        ],
      },
    ],
  },
}
