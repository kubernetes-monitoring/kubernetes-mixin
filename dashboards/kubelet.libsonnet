local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local tablePanel = grafana.tablePanel;
local singlestat = grafana.singlestat;

{
  grafanaDashboards+:: {
    'kubelet.json':
      local upCount =
        singlestat.new(
          'Up',
          datasource='$datasource',
          span=2,
          valueName='min',
        )
        .addTarget(prometheus.target('sum(up{%(kubeletSelector)s})' % $._config));

      local runningPodCount =
        singlestat.new(
          'Running Pods',
          datasource='$datasource',
          span=2,
          valueName='min',
        )
        .addTarget(prometheus.target('sum(kubelet_running_pod_count{%(kubeletSelector)s, instance=~"$instance"})' % $._config));

      local runningContainerCount =
        singlestat.new(
          'Running Container',
          datasource='$datasource',
          span=2,
          valueName='min',
        )
        .addTarget(prometheus.target('sum(kubelet_running_container_count{%(kubeletSelector)s, instance=~"$instance"})' % $._config));

      local volumeTable =
        tablePanel.new(
          'Pod Volume Size',
          datasource='$datasource',
          span=6,
        )
        .addTarget(prometheus.target('kubelet_volume_stats_available_bytes{instance=~"$instance",%(kubeletSelector)s}' % $._config, legendFormat='{{persistentvolumeclaim}} {{namespace}} available'))
        .addTarget(prometheus.target('kubelet_volume_stats_used_bytes{instance=~"$instance",%(kubeletSelector)s}' % $._config, legendFormat='{{persistentvolumeclaim}} {{namespace}} used'));

      local operationRate =
        graphPanel.new(
          'Operation Rate',
          datasource='$datasource',
          span=6,
          format='ops',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
        )
        .addTarget(prometheus.target('sum(rate(kubelet_runtime_operations{%(kubeletSelector)s,instance=~"$instance"}[5m])) by (operation_type)' % $._config, legendFormat='{{operation_type}}'));

      local operationErrorRate =
        graphPanel.new(
          'Operation Error Rate',
          datasource='$datasource',
          span=6,
          min=0,
          format='ops',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
        )
        .addTarget(prometheus.target('sum(rate(kubelet_runtime_operations_errors{%(kubeletSelector)s,instance=~"$instance"}[5m])) by (operation_type)' % $._config, legendFormat='{{operation_type}}'));

      local operationLatency =
        graphPanel.new(
          'Operation duration 99th quantile',
          datasource='$datasource',
          span=12,
          format='µs',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
        )
        .addTarget(prometheus.target('kubelet_runtime_operations_latency_microseconds{%(kubeletSelector)s,instance=~"$instance"}' % $._config, legendFormat='{{operation_type}}'));

      local podStartRate =
        graphPanel.new(
          'Pod Start Rate',
          datasource='$datasource',
          span=6,
          min=0,
          format='ops',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
        )
        .addTarget(prometheus.target('sum(rate(kubelet_pod_start_latency_microseconds_count{%(kubeletSelector)s,instance=~"$instance"}[5m]))' % $._config, legendFormat='pod'))
        .addTarget(prometheus.target('sum(rate(kubelet_pod_worker_start_latency_microseconds_count{%(kubeletSelector)s,instance=~"$instance"}[5m]))' % $._config, legendFormat='worker'));

      local podStartLatency =
        graphPanel.new(
          'Pod Start Duration',
          datasource='$datasource',
          span=6,
          format='µs',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',

        )
        .addTarget(prometheus.target('kubelet_pod_start_latency_microseconds{%(kubeletSelector)s,instance=~"$instance"}' % $._config, legendFormat='pod {{quantile}}'))
        .addTarget(prometheus.target('kubelet_pod_worker_start_latency_microseconds{%(kubeletSelector)s,instance=~"$instance"}' % $._config, legendFormat='worker {{quantile}}'));

      local storageOperationRate =
        graphPanel.new(
          'Storage Operation Rate',
          datasource='$datasource',
          span=6,
          format='ops',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
          legend_hideEmpty='true',
          legend_hideZero='true',
        )
        .addTarget(prometheus.target('sum(rate(storage_operation_duration_seconds_count{%(kubeletSelector)s,instance=~"$instance"}[5m])) by (operation_name,volume_plugin)' % $._config, legendFormat='{{operation_name}} {{volume_plugin}}'));

      local storageOperationLatency =
        graphPanel.new(
          'Storage Operation Duration 99th quantile',
          datasource='$datasource',
          span=6,
          format='s',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
          legend_hideEmpty='true',
          legend_hideZero='true',
        )
        .addTarget(prometheus.target('histogram_quantile(0.99,sum(rate(storage_operation_duration_seconds_bucket{%(kubeletSelector)s,instance=~"$instance"}[5m])) by (operation_name,volume_plugin,le))' % $._config, legendFormat='{{operation_name}} {{volume_plugin}}'));

      local cgroupManagerRate =
        graphPanel.new(
          'Cgroup manager operation rate',
          datasource='$datasource',
          span=6,
          format='ops',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
        )
        .addTarget(prometheus.target('sum(rate(kubelet_cgroup_manager_latency_microseconds_count{%(kubeletSelector)s,instance=~"$instance"}[5m])) by (operation_type)' % $._config, legendFormat='{{operation_type}}'));

      local cgroupManagerDuration =
        graphPanel.new(
          'Cgroup manager duration',
          datasource='$datasource',
          span=6,
          format='µs',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
        )
        .addTarget(prometheus.target('kubelet_cgroup_manager_latency_microseconds{%(kubeletSelector)s,instance=~"$instance"}' % $._config, legendFormat='{{operation_type}} {{quantile}}'));

      local networkPluginOperationRate =
        graphPanel.new(
          'Network Plugin operation rate',
          datasource='$datasource',
          span=6,
          min=0,
          format='ops',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
        )
        .addTarget(prometheus.target('sum(rate(kubelet_network_plugin_operations_latency_microseconds_count{%(kubeletSelector)s,instance=~"$instance"}[5m])) by (operation_type)' % $._config, legendFormat='{{operation_type}}'));

      local networkPluginOperationDuration =
        graphPanel.new(
          'Network plugin operation duration',
          datasource='$datasource',
          span=6,
          format='µs',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
        )
        .addTarget(prometheus.target('kubelet_network_plugin_operations_latency_microseconds{%(kubeletSelector)s,instance=~"$instance"}' % $._config, legendFormat='{{operation_type}} {{quantile}}'));


      local plegRelistRate =
        graphPanel.new(
          'PLEG relist rate',
          datasource='$datasource',
          span=6,
          description='Pod lifecycle event generator',
          format='ops',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
        )
        .addTarget(prometheus.target('sum(rate(kubelet_pleg_relist_interval_microseconds_count{%(kubeletSelector)s,instance=~"$instance"}[5m]))' % $._config, legendFormat='relist'));

      local plegRelistDuration =
        graphPanel.new(
          'PLEG relist duration',
          datasource='$datasource',
          span=6,
          format='µs',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
        )
        .addTarget(prometheus.target('kubelet_pleg_relist_interval_microseconds{%(kubeletSelector)s,instance=~"$instance"}' % $._config, legendFormat='relist {{quantile}}'));

      local rpcRate =
        graphPanel.new(
          'RPC Rate',
          datasource='$datasource',
          span=12,
          format='ops',
        )
        .addTarget(prometheus.target('sum(rate(rest_client_requests_total{%(kubeletSelector)s, instance=~"$instance",code=~"2.."}[5m]))' % $._config, legendFormat='2xx'))
        .addTarget(prometheus.target('sum(rate(rest_client_requests_total{%(kubeletSelector)s, instance=~"$instance",code=~"3.."}[5m]))' % $._config, legendFormat='3xx'))
        .addTarget(prometheus.target('sum(rate(rest_client_requests_total{%(kubeletSelector)s, instance=~"$instance",code=~"4.."}[5m]))' % $._config, legendFormat='4xx'))
        .addTarget(prometheus.target('sum(rate(rest_client_requests_total{%(kubeletSelector)s, instance=~"$instance",code=~"5.."}[5m]))' % $._config, legendFormat='5xx'));

      local requestDuration =
        graphPanel.new(
          'Request duration 99th quantile',
          datasource='$datasource',
          span=12,
          format='µs',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
        )
        .addTarget(prometheus.target('histogram_quantile(0.99,sum(rate(rest_client_request_latency_seconds_bucket{%(kubeletSelector)s,instance=~"$instance"}[5m])) by (verb,url,le))' % $._config, legendFormat='{{verb}} {{url}}'));

      local memory =
        graphPanel.new(
          'Memory',
          datasource='$datasource',
          span=4,
          format='bytes',
        )
        .addTarget(prometheus.target('process_resident_memory_bytes{%(kubeletSelector)s,instance=~"$instance"}' % $._config, legendFormat='{{instance}}'));

      local cpu =
        graphPanel.new(
          'CPU usage',
          datasource='$datasource',
          span=4,
          format='bytes',
          min=0,
        )
        .addTarget(prometheus.target('rate(process_cpu_seconds_total{%(kubeletSelector)s,instance=~"$instance"}[5m])' % $._config, legendFormat='{{instance}}'));

      local goroutines =
        graphPanel.new(
          'Goroutines',
          datasource='$datasource',
          span=4,
          format='short',
        )
        .addTarget(prometheus.target('go_goroutines{%(kubeletSelector)s,instance=~"$instance"}' % $._config, legendFormat='{{instance}}'));


      dashboard.new(
        'Kubelet',
        time_from='now-1h',
        uid=($._config.grafanaDashboardIDs['kubelet.json']),
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
          'instance',
          '$datasource',
          'label_values(kubelet_runtime_operations{%(kubeletSelector)s}, instance)' % $._config,
          refresh='time',
          includeAll=false,
        )
      )
      .addRow(
        row.new()
        .addPanel(upCount)
        .addPanel(runningPodCount)
        .addPanel(runningContainerCount)
        .addPanel(volumeTable)
      ).addRow(
        row.new()
        .addPanel(operationRate)
        .addPanel(operationErrorRate)
      ).addRow(
        row.new()
        .addPanel(operationLatency)
      ).addRow(
        row.new()
        .addPanel(podStartRate)
        .addPanel(podStartLatency)
      ).addRow(
        row.new()
        .addPanel(storageOperationRate)
        .addPanel(storageOperationLatency)
      ).addRow(
        row.new()
        .addPanel(cgroupManagerRate)
        .addPanel(cgroupManagerDuration)
      ).addRow(
        row.new()
        .addPanel(networkPluginOperationRate)
        .addPanel(networkPluginOperationDuration)
      ).addRow(
        row.new()
        .addPanel(plegRelistRate)
        .addPanel(plegRelistDuration)
      ).addRow(
        row.new()
        .addPanel(rpcRate)
      ).addRow(
        row.new()
        .addPanel(requestDuration)
      ).addRow(
        row.new()
        .addPanel(memory)
        .addPanel(cpu)
        .addPanel(goroutines)
      ),
  },
}
