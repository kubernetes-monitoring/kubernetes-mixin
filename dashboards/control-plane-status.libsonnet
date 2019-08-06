local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local graphPanel = grafana.graphPanel;
local prometheus = grafana.prometheus;
local promgrafonnet = import '../lib/promgrafonnet/promgrafonnet.libsonnet';
local row = grafana.row;
local numbersinglestat = promgrafonnet.numbersinglestat;
{
  grafanaDashboards+:: {
    'control-plane-status.json':
      local apiserversStat =
        numbersinglestat.new(
          'API Servers UP',
          '(sum(up{%(kubeApiserverSelector)s} == 1) / sum(up{%(kubeApiserverSelector)s}))' % $._config,
        )
        .withTextNullValue('N/A')
        .withFormat('percentunit');

      local controllerManagersStat =
        numbersinglestat.new(
          'Controller Mangers UP',
          '(sum(up{%(kubeControllerManagerSelector)s} == 1) / sum(up{%(kubeControllerManagerSelector)s}))' % $._config,
        )
        .withTextNullValue('N/A')
        .withFormat('percentunit');

      local schedulersStat =
        numbersinglestat.new(
          'Schedulers UP',
          '(sum(up{%(kubeSchedulerSelector)s} == 1) / sum(up{%(kubeSchedulerSelector)s}))' % $._config,
        )
        .withTextNullValue('N/A')
        .withFormat('percentunit');

      local apiErrorRateStat =
        numbersinglestat.new(
          'API Request Error Rate',
          'max(sum by(instance) (rate(apiserver_request_count{%(kubeApiserverSelector)s, code=~"5.."}[5m])) / sum by(instance) (rate(apiserver_request_count{%(kubeApiserverSelector)s}[5m])))' % $._config,
        )
        .withTextNullValue('N/A')
        .withFormat('percentunit');

      local apiRequestLatency =
        graphPanel.new(
          'API Request Latency',
          datasource='$datasource',
          span=12,
        )
        .addTarget(prometheus.target(
          'sum by(verb) (rate(cluster_quantile:apiserver_request_latencies:histogram_quantile[5m]) >= 0)',
          legendFormat='{{verb}}',
        ));

      local apiRequestRate =
        graphPanel.new(
          'API Request Rate',
          datasource='$datasource',
          span=12,
        )
        .addTarget(prometheus.target(
          'sum by(instance) (rate(apiserver_request_count{%(kubeApiserverSelector)s, code!~"2.."}[5m]))' % $._config,
          legendFormat='{{instance}} Error Rate',
        ))
        .addTarget(prometheus.target(
          'sum by(instance) (rate(apiserver_request_count{%(kubeApiserverSelector)s}[5m]))' % $._config,
          legendFormat='{{instance}} Request Rate',
        ));

      local e2eSchedulingLatency =
        graphPanel.new(
          'End to End Scheduling Latency',
          datasource='$datasource',
          span=12,
        )
        .addTarget(prometheus.target(
          'cluster_quantile:scheduler_e2e_scheduling_latency:histogram_quantile',
          legendFormat='{{quantile}}',
        ));

      dashboard.new(
        'Kubernetes Control Plane Status',
        time_from='now-1h',
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
      .addRow(
        row.new(height='100px')
        .addPanel(apiserversStat)
        .addPanel(controllerManagersStat)
        .addPanel(schedulersStat)
        .addPanel(apiErrorRateStat)
      )
      .addRow(
        row.new()
        .addPanel(apiRequestLatency)
      )
      .addRow(
        row.new()
        .addPanel(apiRequestRate)
      )
      .addRow(
        row.new()
        .addPanel(e2eSchedulingLatency)
      ),
  },
}
