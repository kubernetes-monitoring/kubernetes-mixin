local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local graphPanel = grafana.graphPanel;
local prometheus = grafana.prometheus;
local promgrafonnet = import '../lib/promgrafonnet/promgrafonnet.libsonnet';
local row = grafana.row;
local singlestat = grafana.singlestat;
local template = grafana.template;
local numbersinglestat = promgrafonnet.numbersinglestat;

{
  grafanaDashboards+:: {
    'statefulset.json':
      local cpuStat =
        numbersinglestat.new(
          'CPU',
          'sum(rate(container_cpu_usage_seconds_total{%(cadvisorSelector)s, namespace="$namespace", pod_name=~"$statefulset.*"}[3m]))' % $._config,
        )
        .withSpanSize(4)
        .withPostfix('cores')
        .withSparkline();

      local memoryStat =
        numbersinglestat.new(
          'Memory',
          'sum(container_memory_usage_bytes{%(cadvisorSelector)s, namespace="$namespace", pod_name=~"$statefulset.*"}) / 1024^3' % $._config,
        )
        .withSpanSize(4)
        .withPostfix('GB')
        .withSparkline();

      local networkStat =
        numbersinglestat.new(
          'Network',
          'sum(rate(container_network_transmit_bytes_total{%(cadvisorSelector)s, namespace="$namespace", pod_name=~"$statefulset.*"}[3m])) + sum(rate(container_network_receive_bytes_total{namespace="$namespace",pod_name=~"$statefulset.*"}[3m]))' % $._config,
        )
        .withSpanSize(4)
        .withPostfix('Bps')
        .withSparkline();

      local overviewRow =
        row.new()
        .addPanel(cpuStat)
        .addPanel(memoryStat)
        .addPanel(networkStat);

      local desiredReplicasStat = numbersinglestat.new(
        'Desired Replicas',
        'max(kube_statefulset_replicas{%(kubeStateMetricsSelector)s, namespace="$namespace", statefulset="$statefulset"}) without (instance, pod)' % $._config,
      );

      local availableReplicasStat = numbersinglestat.new(
        'Replicas of current version',
        'min(kube_statefulset_status_replicas_current{%(kubeStateMetricsSelector)s, namespace="$namespace", statefulset="$statefulset"}) without (instance, pod)' % $._config,
      );

      local observedGenerationStat = numbersinglestat.new(
        'Observed Generation',
        'max(kube_statefulset_status_observed_generation{%(kubeStateMetricsSelector)s,  namespace="$namespace", statefulset="$statefulset"}) without (instance, pod)' % $._config,
      );

      local metadataGenerationStat = numbersinglestat.new(
        'Metadata Generation',
        'max(kube_statefulset_metadata_generation{%(kubeStateMetricsSelector)s, statefulset="$statefulset", namespace="$namespace"}) without (instance, pod)' % $._config,
      );

      local statsRow =
        row.new(height='100px')
        .addPanel(desiredReplicasStat)
        .addPanel(availableReplicasStat)
        .addPanel(observedGenerationStat)
        .addPanel(metadataGenerationStat);

      local replicasGraph =
        graphPanel.new(
          'Replicas',
          datasource='prometheus',
        )
        .addTarget(prometheus.target(
          'max(kube_statefulset_replicas{%(kubeStateMetricsSelector)s, statefulset="$statefulset",namespace="$namespace"}) without (instance, pod)' % $._config,
          legendFormat='replicas specified',
        ))
        .addTarget(prometheus.target(
          'max(kube_statefulset_status_replicas{%(kubeStateMetricsSelector)s, statefulset="$statefulset",namespace="$namespace"}) without (instance, pod)' % $._config,
          legendFormat='replicas created',
        ))
        .addTarget(prometheus.target(
          'min(kube_statefulset_status_replicas_ready{%(kubeStateMetricsSelector)s, statefulset="$statefulset",namespace="$namespace"}) without (instance, pod)' % $._config,
          legendFormat='ready',
        ))
        .addTarget(prometheus.target(
          'min(kube_statefulset_status_replicas_current{%(kubeStateMetricsSelector)s, statefulset="$statefulset",namespace="$namespace"}) without (instance, pod)' % $._config,
          legendFormat='replicas of current version',
        ))
        .addTarget(prometheus.target(
          'min(kube_statefulset_status_replicas_updated{%(kubeStateMetricsSelector)s, statefulset="$statefulset",namespace="$namespace"}) without (instance, pod)' % $._config,
          legendFormat='updated',
        ));

      local replicasRow =
        row.new()
        .addPanel(replicasGraph);

      dashboard.new(
        'StatefulSets',
        time_from='now-1h',
        uid=($._config.grafanaDashboardIDs['statefulset.json']),
      ).addTemplate(
        {
          current: {
            text: 'Prometheus',
            value: 'Prometheus',
          },
          hide: 0,
          label: null,
          name: 'datasource',
          options: [],
          query: 'prometheus',
          refresh: 1,
          regex: '',
          type: 'datasource',
        },
      )
      .addTemplate(
        template.new(
          'namespace',
          'prometheus',
          'label_values(kube_statefulset_metadata_generation{%(kubeStateMetricsSelector)s}, namespace)' % $._config,
          label='Namespace',
          refresh='time',
        )
      )
      .addTemplate(
        template.new(
          'statefulset',
          'prometheus',
          'label_values(kube_statefulset_metadata_generation{%(kubeStateMetricsSelector)s, namespace="$namespace"}, statefulset)' % $._config,
          label='Name',
          refresh='time',
        )
      )
      .addRow(overviewRow)
      .addRow(statsRow)
      .addRow(replicasRow),
  },
}
