local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local promgrafonnet = import '../lib/promgrafonnet/promgrafonnet.libsonnet';
local numbersinglestat = promgrafonnet.numbersinglestat;
local gauge = promgrafonnet.gauge;

{
  grafanaDashboards+:: {
    'persistentvolumesusage.json':
      local sizeGraph = graphPanel.new(
        'Volume Space Usage',
        datasource='$datasource',
        format='percent',
        max=100,
        min=0,
        span=12,
        legend_show=true,
        legend_values=true,
        legend_min=true,
        legend_max=true,
        legend_current=true,
        legend_total=false,
        legend_avg=true,
        legend_alignAsTable=false,
        legend_rightSide=false,
      ).addTarget(prometheus.target(
        |||
          (kubelet_volume_stats_capacity_bytes{%(kubeletSelector)s, persistentvolumeclaim="$volume"} - kubelet_volume_stats_available_bytes{%(kubeletSelector)s, persistentvolumeclaim="$volume"}) / kubelet_volume_stats_capacity_bytes{%(kubeletSelector)s, persistentvolumeclaim="$volume"} * 100
        ||| % $._config,
        legendFormat='{{ Usage }}',
        intervalFactor=1,
      ));

      local inodesGraph = graphPanel.new(
        'Volume inodes Usage',
        datasource='$datasource',
        format='percent',
        max=100,
        min=0,
        span=12,
        legend_show=true,
        legend_values=true,
        legend_min=true,
        legend_max=true,
        legend_current=true,
        legend_total=false,
        legend_avg=true,
        legend_alignAsTable=false,
        legend_rightSide=false,
      ).addTarget(prometheus.target(
        |||
          kubelet_volume_stats_inodes_used{%(kubeletSelector)s, persistentvolumeclaim="$volume"} / kubelet_volume_stats_inodes{%(kubeletSelector)s, persistentvolumeclaim="$volume"} * 100
        ||| % $._config,
        legendFormat='{{ Usage }}',
        intervalFactor=1,
      ));

      dashboard.new(
        'Persistent Volumes',
        time_from='now-7d',
        uid=($._config.grafanaDashboardIDs['nodes.json']),
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
          '$datasource',
          'label_values(kubelet_volume_stats_capacity_bytes{%(kubeletSelector)s}, exported_namespace)' % $._config,
          label='Namespace',
          refresh='time',
        )
      )
      .addTemplate(
        template.new(
          'volume',
          '$datasource',
          'label_values(kubelet_volume_stats_capacity_bytes{%(kubeletSelector)s, exported_namespace="$namespace"}, persistentvolumeclaim)' % $._config,
          label='PersistentVolumeClaim',
          refresh='time',
        )
      )
      .addRow(
        row.new()
        .addPanel(sizeGraph)
      )
      .addRow(
        row.new()
        .addPanel(inodesGraph)
      ),
  },
}
