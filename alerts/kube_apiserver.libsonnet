local utils = import 'utils.libsonnet';

{
  _config+:: {
    kubeApiserverSelector: error 'must provide selector for kube-apiserver',

    kubeAPILatencyWarningSeconds: 1,

    certExpirationWarningSeconds: 7 * 24 * 3600,
    certExpirationCriticalSeconds: 1 * 24 * 3600,
  },

  prometheusAlerts+:: {
    groups+: [
      {
        name: 'kube-apiserver-slos',
        rules: [
          {
            alert: 'KubeAPIErrorBudgetBurn',
            expr: |||
              sum(apiserver_request:burnrate%s) > (%.2f * %.5f)
              and
              sum(apiserver_request:burnrate%s) > (%.2f * %.5f)
            ||| % [
              w.long,
              w.factor,
              (1 - $._config.SLOs.apiserver.target),
              w.short,
              w.factor,
              (1 - $._config.SLOs.apiserver.target),
            ],
            labels: {
              severity: w.severity,
              short: '%(short)s' % w,
              long: '%(long)s' % w,
            },
            annotations: {
              message: 'The API server is burning too much error budget',
            },
            'for': '%(for)s' % w,
          }
          for w in $._config.SLOs.apiserver.windows
        ],
      },
      {
        name: 'kubernetes-system-apiserver',
        rules: [
          {
            alert: 'KubeClientCertificateExpiration',
            expr: |||
              apiserver_client_certificate_expiration_seconds_count{%(kubeApiserverSelector)s} > 0 and on(job) histogram_quantile(0.01, sum by (job, le) (rate(apiserver_client_certificate_expiration_seconds_bucket{%(kubeApiserverSelector)s}[5m]))) < %(certExpirationWarningSeconds)s
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'A client certificate used to authenticate to the apiserver is expiring in less than %s.' % (utils.humanizeSeconds($._config.certExpirationWarningSeconds)),
            },
          },
          {
            alert: 'KubeClientCertificateExpiration',
            expr: |||
              apiserver_client_certificate_expiration_seconds_count{%(kubeApiserverSelector)s} > 0 and on(job) histogram_quantile(0.01, sum by (job, le) (rate(apiserver_client_certificate_expiration_seconds_bucket{%(kubeApiserverSelector)s}[5m]))) < %(certExpirationCriticalSeconds)s
            ||| % $._config,
            labels: {
              severity: 'critical',
            },
            annotations: {
              message: 'A client certificate used to authenticate to the apiserver is expiring in less than %s.' % (utils.humanizeSeconds($._config.certExpirationCriticalSeconds)),
            },
          },
          {
            alert: 'AggregatedAPIErrors',
            expr: |||
              sum by(name, namespace)(increase(aggregator_unavailable_apiservice_count[5m])) > 2
            ||| % $._config,
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'An aggregated API {{ $labels.name }}/{{ $labels.namespace }} has reported errors. The number of errors have increased for it in the past five minutes. High values indicate that the availability of the service changes too often.',
            },
          },
          {
            alert: 'AggregatedAPIDown',
            expr: |||
              (1 - max by(name, namespace)(avg_over_time(aggregator_unavailable_apiservice[5m]))) * 100 < 90
            ||| % $._config,
            'for': '5m',
            labels: {
              severity: 'warning',
            },
            annotations: {
              message: 'An aggregated API {{ $labels.name }}/{{ $labels.namespace }} has been only {{ $value | humanize }}% available over the last 5m.',
            },
          },
          (import '../lib/absent_alert.libsonnet') {
            componentName:: 'KubeAPI',
            selector:: $._config.kubeApiserverSelector,
          },
        ],
      },
    ],
  },
}
