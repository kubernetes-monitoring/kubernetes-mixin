local grafana = import 'grafonnet/grafana.libsonnet';
local dashboard = grafana.dashboard;
local row = grafana.row;
local prometheus = grafana.prometheus;
local template = grafana.template;
local graphPanel = grafana.graphPanel;
local singlestat = grafana.singlestat;

{
  _config+:: {
    kubeApiserverSelector: 'job="kube-apiserver"',
  },

  grafanaDashboards+:: {
    'apiserver.json':
      local availability1d =
        singlestat.new(
          'Availability (%dd) > %.3f%%' % [$._config.SLOs.apiserver.days, 100 * $._config.SLOs.apiserver.target],
          datasource='$datasource',
          span=4,
          format='percentunit',
          decimals=3,
          description='How many percent of requests (both read and write) in %d days have been answered successfully and fast enough?' % $._config.SLOs.apiserver.days,
        )
        .addTarget(prometheus.target('apiserver_request:availability%dd{verb="all"}' % $._config.SLOs.apiserver.days));

      local errorBudget =
        graphPanel.new(
          'ErrorBudget (%dd) > %.3f%%' % [$._config.SLOs.apiserver.days, 100 * $._config.SLOs.apiserver.target],
          datasource='$datasource',
          span=8,
          format='percentunit',
          decimals=3,
          fill=10,
          description='How much error budget is left looking at our %.3f%% availability gurantees?' % $._config.SLOs.apiserver.target,
        )
        .addTarget(prometheus.target('100 * (apiserver_request:availability%dd{verb="all"} - %f)' % [$._config.SLOs.apiserver.days, $._config.SLOs.apiserver.target], legendFormat='errorbudget'));

      local readAvailability =
        singlestat.new(
          'Read Availability (%dd)' % $._config.SLOs.apiserver.days,
          datasource='$datasource',
          span=3,
          format='percentunit',
          decimals=3,
          description='How many percent of read requests (LIST,GET) in %d days have been answered successfully and fast enough?' % $._config.SLOs.apiserver.days,
        )
        .addTarget(prometheus.target('apiserver_request:availability%dd{verb="read"}' % $._config.SLOs.apiserver.days));

      local readRequests =
        graphPanel.new(
          'Read SLI - Requests',
          datasource='$datasource',
          span=3,
          format='reqps',
          stack=true,
          fill=10,
          description='How many read requests (LIST,GET) per second do the apiservers get by code?',
        )
        .addSeriesOverride({ alias: '/2../i', color: '#56A64B' })
        .addSeriesOverride({ alias: '/3../i', color: '#F2CC0C' })
        .addSeriesOverride({ alias: '/4../i', color: '#3274D9' })
        .addSeriesOverride({ alias: '/5../i', color: '#E02F44' })
        .addTarget(prometheus.target('sum by (code) (code_resource:apiserver_request_total:rate5m{verb="read"})', legendFormat='{{ code }}'));

      local readErrors =
        graphPanel.new(
          'Read SLI - Errors',
          datasource='$datasource',
          min=0,
          span=3,
          format='percentunit',
          description='How many percent of read requests (LIST,GET) per second are returned with errors (5xx)?',
        )
        .addTarget(prometheus.target('sum by (resource) (code_resource:apiserver_request_total:rate5m{verb="read",code=~"5.."}) / sum by (resource) (code_resource:apiserver_request_total:rate5m{verb="read"})', legendFormat='{{ resource }}'));

      local readDuration =
        graphPanel.new(
          'Read SLI - Duration',
          datasource='$datasource',
          span=3,
          format='s',
          description='How many seconds is the 99th percentile for reading (LIST|GET) a given resource?',
        )
        .addTarget(prometheus.target('cluster_quantile:apiserver_request_duration_seconds:histogram_quantile{verb="read"}', legendFormat='{{ resource }}'));

      local writeAvailability =
        singlestat.new(
          'Write Availability (%dd)' % $._config.SLOs.apiserver.days,
          datasource='$datasource',
          span=3,
          format='percentunit',
          decimals=3,
          description='How many percent of write requests (POST|PUT|PATCH|DELETE) in %d days have been answered successfully and fast enough?' % $._config.SLOs.apiserver.days,
        )
        .addTarget(prometheus.target('apiserver_request:availability%dd{verb="write"}' % $._config.SLOs.apiserver.days));

      local writeRequests =
        graphPanel.new(
          'Write SLI - Requests',
          datasource='$datasource',
          span=3,
          format='reqps',
          stack=true,
          fill=10,
          description='How many write requests (POST|PUT|PATCH|DELETE) per second do the apiservers get by code?',
        )
        .addSeriesOverride({ alias: '/2../i', color: '#56A64B' })
        .addSeriesOverride({ alias: '/3../i', color: '#F2CC0C' })
        .addSeriesOverride({ alias: '/4../i', color: '#3274D9' })
        .addSeriesOverride({ alias: '/5../i', color: '#E02F44' })
        .addTarget(prometheus.target('sum by (code) (code_resource:apiserver_request_total:rate5m{verb="write"})', legendFormat='{{ code }}'));

      local writeErrors =
        graphPanel.new(
          'Write SLI - Errors',
          datasource='$datasource',
          min=0,
          span=3,
          format='percentunit',
          description='How many percent of write requests (POST|PUT|PATCH|DELETE) per second are returned with errors (5xx)?',
        )
        .addTarget(prometheus.target('sum by (resource) (code_resource:apiserver_request_total:rate5m{verb="write",code=~"5.."}) / sum by (resource) (code_resource:apiserver_request_total:rate5m{verb="write"})', legendFormat='{{ resource }}'));

      local writeDuration =
        graphPanel.new(
          'Write SLI - Duration',
          datasource='$datasource',
          span=3,
          format='s',
          description='How many seconds is the 99th percentile for writing (POST|PUT|PATCH|DELETE) a given resource?',
        )
        .addTarget(prometheus.target('cluster_quantile:apiserver_request_duration_seconds:histogram_quantile{verb="write"}', legendFormat='{{ resource }}'));

      local workQueueAddRate =
        graphPanel.new(
          'Work Queue Add Rate',
          datasource='$datasource',
          span=4,
          format='ops',
          legend_show=false,
          min=0,
        )
        .addTarget(prometheus.target('sum(rate(workqueue_adds_total{%(kubeApiserverSelector)s, instance=~"$instance", %(clusterLabel)s="$cluster"}[5m])) by (instance, name)' % $._config, legendFormat='{{instance}} {{name}}'));

      local workQueueDepth =
        graphPanel.new(
          'Work Queue Depth',
          datasource='$datasource',
          span=4,
          format='short',
          legend_show=false,
          min=0,
        )
        .addTarget(prometheus.target('sum(rate(workqueue_depth{%(kubeApiserverSelector)s, instance=~"$instance", %(clusterLabel)s="$cluster"}[5m])) by (instance, name)' % $._config, legendFormat='{{instance}} {{name}}'));


      local workQueueLatency =
        graphPanel.new(
          'Work Queue Latency',
          datasource='$datasource',
          span=4,
          format='s',
          legend_show=true,
          legend_values=true,
          legend_current=true,
          legend_alignAsTable=true,
          legend_rightSide=true,
        )
        .addTarget(prometheus.target('histogram_quantile(0.99, sum(rate(workqueue_queue_duration_seconds_bucket{%(kubeApiserverSelector)s, instance=~"$instance", %(clusterLabel)s="$cluster"}[5m])) by (instance, name, le))' % $._config, legendFormat='{{instance}} {{name}}'));

      local etcdCacheEntryTotal =
        graphPanel.new(
          'ETCD Cache Entry Total',
          datasource='$datasource',
          span=4,
          format='short',
          min=0,
        )
        .addTarget(prometheus.target('etcd_helper_cache_entry_total{%(kubeApiserverSelector)s, instance=~"$instance", %(clusterLabel)s="$cluster"}' % $._config, legendFormat='{{instance}}'));

      local etcdCacheEntryRate =
        graphPanel.new(
          'ETCD Cache Hit/Miss Rate',
          datasource='$datasource',
          span=4,
          format='ops',
          min=0,
        )
        .addTarget(prometheus.target('sum(rate(etcd_helper_cache_hit_total{%(kubeApiserverSelector)s,instance=~"$instance", %(clusterLabel)s="$cluster"}[5m])) by (instance)' % $._config, legendFormat='{{instance}} hit'))
        .addTarget(prometheus.target('sum(rate(etcd_helper_cache_miss_total{%(kubeApiserverSelector)s,instance=~"$instance", %(clusterLabel)s="$cluster"}[5m])) by (instance)' % $._config, legendFormat='{{instance}} miss'));

      local etcdCacheLatency =
        graphPanel.new(
          'ETCD Cache Duration 99th Quantile',
          datasource='$datasource',
          span=4,
          format='s',
          min=0,
        )
        .addTarget(prometheus.target('histogram_quantile(0.99,sum(rate(etcd_request_cache_get_duration_seconds_bucket{%(kubeApiserverSelector)s,instance=~"$instance", %(clusterLabel)s="$cluster"}[5m])) by (instance, le))' % $._config, legendFormat='{{instance}} get'))
        .addTarget(prometheus.target('histogram_quantile(0.99,sum(rate(etcd_request_cache_add_duration_seconds_bucket{%(kubeApiserverSelector)s,instance=~"$instance", %(clusterLabel)s="$cluster"}[5m])) by (instance, le))' % $._config, legendFormat='{{instance}} miss'));

      local memory =
        graphPanel.new(
          'Memory',
          datasource='$datasource',
          span=4,
          format='bytes',
        )
        .addTarget(prometheus.target('process_resident_memory_bytes{%(kubeApiserverSelector)s,instance=~"$instance", %(clusterLabel)s="$cluster"}' % $._config, legendFormat='{{instance}}'));

      local cpu =
        graphPanel.new(
          'CPU usage',
          datasource='$datasource',
          span=4,
          format='short',
          min=0,
        )
        .addTarget(prometheus.target('rate(process_cpu_seconds_total{%(kubeApiserverSelector)s,instance=~"$instance", %(clusterLabel)s="$cluster"}[5m])' % $._config, legendFormat='{{instance}}'));

      local goroutines =
        graphPanel.new(
          'Goroutines',
          datasource='$datasource',
          span=4,
          format='short',
        )
        .addTarget(prometheus.target('go_goroutines{%(kubeApiserverSelector)s,instance=~"$instance", %(clusterLabel)s="$cluster"}' % $._config, legendFormat='{{instance}}'));

      dashboard.new(
        '%(dashboardNamePrefix)sAPI server' % $._config.grafanaK8s,
        time_from='now-1h',
        uid=($._config.grafanaDashboardIDs['apiserver.json']),
        tags=($._config.grafanaK8s.dashboardTags),
      ).addTemplate(
        {
          current: {
            text: 'default',
            value: 'default',
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
          name='cluster',
          datasource='$datasource',
          query='label_values(apiserver_request_total, %(clusterLabel)s)' % $._config,
          current='prod',
          hide=if $._config.showMultiCluster then '' else 'variable',
          refresh=1,
          includeAll=false,
          sort=1
        )
      )
      .addTemplate(
        template.new(
          'instance',
          '$datasource',
          'label_values(apiserver_request_total{%(kubeApiserverSelector)s, %(clusterLabel)s="$cluster"}, instance)' % $._config,
          refresh='time',
          includeAll=true,
          sort=1,
        )
      )
      .addRow(
        row.new()
        .addPanel(availability1d)
        .addPanel(errorBudget)
      )
      .addRow(
        row.new()
        .addPanel(readAvailability)
        .addPanel(readRequests)
        .addPanel(readErrors)
        .addPanel(readDuration)
      )
      .addRow(
        row.new()
        .addPanel(writeAvailability)
        .addPanel(writeRequests)
        .addPanel(writeErrors)
        .addPanel(writeDuration)
      ).addRow(
        row.new()
        .addPanel(workQueueAddRate)
        .addPanel(workQueueDepth)
        .addPanel(workQueueLatency)
      ).addRow(
        row.new()
        .addPanel(etcdCacheEntryTotal)
        .addPanel(etcdCacheEntryRate)
        .addPanel(etcdCacheLatency)
      ).addRow(
        row.new()
        .addPanel(memory)
        .addPanel(cpu)
        .addPanel(goroutines)
      ) + { refresh: $._config.grafanaK8s.refresh },
  },
}
