local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local singlestat = grafana.singlestat;

{
  grafanaDashboards+:: {
    'kube-apiserver.json':
      local upCount =
        singlestat.new(
          'Up',
          datasource='$datasource',
          span=2,
          valueName='min',
        )
        .addTarget(prometheus.target('sum(up{%(kubeApiserverSelector)s})' % $._config));

      local rpcRate =
        graphPanel.new(
          'RPC Rate',
          datasource='$datasource',
          span=5,
          format='ops',
        )
        .addTarget(prometheus.target('sum(rate(apiserver_request_count{%(kubeApiserverSelector)s, instance=~"$instance",code=~"2.."}[5m]))' % $._config, legendFormat='2xx'))
        .addTarget(prometheus.target('sum(rate(apiserver_request_count{%(kubeApiserverSelector)s, instance=~"$instance",code=~"3.."}[5m]))' % $._config, legendFormat='3xx'))
        .addTarget(prometheus.target('sum(rate(apiserver_request_count{%(kubeApiserverSelector)s, instance=~"$instance",code=~"4.."}[5m]))' % $._config, legendFormat='4xx'))
        .addTarget(prometheus.target('sum(rate(apiserver_request_count{%(kubeApiserverSelector)s, instance=~"$instance",code=~"5.."}[5m]))' % $._config, legendFormat='5xx'));

      local requestDuration =
        graphPanel.new(
          'Request duration 99th quantile',
          datasource='$datasource',
          span=5,
          format='µs',
          legend_show='true',
          legend_values='true',
          legend_current='true',
          legend_alignAsTable='true',
          legend_rightSide='true',
        )
        .addTarget(prometheus.target('histogram_quantile(0.99, sum(rate(apiserver_request_latencies_bucket{%(kubeApiserverSelector)s, instance=~"$instance"}[5m])) by (verb, le))' % $._config, legendFormat='{{verb}}'));

      local admissionControllerDepth =
        graphPanel.new(
          'Admission Controller Queue Depth Rate',
          datasource='$datasource',
          span=4,
          format='short',
          legend_show=false,
          min=0,
        )
        .addTarget(prometheus.target('sum(rate(admission_quota_controller_depth{%(kubeApiserverSelector)s, instance=~"$instance"}[5m]))' % $._config, legendFormat='depth'));

      local admissionControllerAddRate =
        graphPanel.new(
          'Admission Controller Queue Add Rate',
          datasource='$datasource',
          span=4,
          format='ops',
          legend_show=false,
          min=0,
        )
        .addTarget(prometheus.target('sum(rate(admission_quota_controller_adds{%(kubeApiserverSelector)s, instance=~"$instance"}[5m]))' % $._config, legendFormat='add'));

      local admissionControllerLatency =
        graphPanel.new(
          'Admission Controller Queue Latency 99th quantile',
          datasource='$datasource',
          span=4,
          format='µs',
          min=0,
        )
        .addTarget(prometheus.target('admission_quota_controller_queue_latency{%(kubeApiserverSelector)s,quantile="0.99",instance=~"$instance"}' % $._config, legendFormat='{{instance}}'));

      local etcdCacheEntryCount =
        graphPanel.new(
          'ETCD Cache entry count',
          datasource='$datasource',
          span=4,
          format='short',
          min=0,
        )
        .addTarget(prometheus.target('etcd_helper_cache_entry_count{%(kubeApiserverSelector)s,instance=~"$instance"}' % $._config, legendFormat='{{instance}}'));

      local etcdCacheEntryRate =
        graphPanel.new(
          'ETCD Cache Hit rate',
          datasource='$datasource',
          span=4,
          format='ops',
          min=0,
        )
        .addTarget(prometheus.target('rate(etcd_helper_cache_hit_count{%(kubeApiserverSelector)s,instance=~"$instance"}[5m])' % $._config, legendFormat='hit {{instance}}'))
        .addTarget(prometheus.target('rate(etcd_helper_cache_miss_count{%(kubeApiserverSelector)s,instance=~"$instance"}[5m])' % $._config, legendFormat='hit {{instance}}'));

      local etcdCacheLatency =
        graphPanel.new(
          'ETCD Cache Latency 99th quantile',
          datasource='$datasource',
          span=4,
          format='s',
          min=0,
        )
        .addTarget(prometheus.target('etcd_request_cache_get_latencies_summary{%(kubeApiserverSelector)s,quantile="0.99",instance=~"$instance"}' % $._config, legendFormat='get {{instance}}'))
        .addTarget(prometheus.target('etcd_request_cache_add_latencies_summary{%(kubeApiserverSelector)s,quantile="0.99",instance=~"$instance"}' % $._config, legendFormat='add {{instance}}'));

      local memory =
        graphPanel.new(
          'Memory',
          datasource='$datasource',
          span=4,
          format='bytes',
        )
        .addTarget(prometheus.target('process_resident_memory_bytes{%(kubeApiserverSelector)s,instance=~"$instance"}' % $._config, legendFormat='{{instance}}'));

      local cpu =
        graphPanel.new(
          'CPU usage',
          datasource='$datasource',
          span=4,
          format='bytes',
          min=0,
        )
        .addTarget(prometheus.target('rate(process_cpu_seconds_total{%(kubeApiserverSelector)s,instance=~"$instance"}[5m])' % $._config, legendFormat='{{instance}}'));

      local goroutines =
        graphPanel.new(
          'Goroutines',
          datasource='$datasource',
          span=4,
          format='short',
        )
        .addTarget(prometheus.target('go_goroutines{%(kubeApiserverSelector)s,instance=~"$instance"}' % $._config, legendFormat='{{instance}}'));


      dashboard.new(
        'Kube api server',
        time_from='now-1h',
        uid=($._config.grafanaDashboardIDs['kube-apiserver.json']),
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
          'label_values(admission_quota_controller_queue_latency{%(kubeApiserverSelector)s}, instance)' % $._config,
          refresh='time',
          includeAll=true,
        )
      )
      .addRow(
        row.new()
        .addPanel(upCount)
        .addPanel(rpcRate)
        .addPanel(requestDuration)
      ).addRow(
        row.new()
        .addPanel(admissionControllerDepth)
        .addPanel(admissionControllerAddRate)
        .addPanel(admissionControllerLatency)
      ).addRow(
        row.new()
        .addPanel(etcdCacheEntryCount)
        .addPanel(etcdCacheEntryRate)
        .addPanel(etcdCacheLatency)
      ).addRow(
        row.new()
        .addPanel(memory)
        .addPanel(cpu)
        .addPanel(goroutines)
      ),
  },
}
