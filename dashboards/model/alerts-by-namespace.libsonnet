local g = import 'github.com/grafana/grafonnet-lib/grafonnet-7.0/grafana.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';

{
  local alert_by_namespace_panel =
    grafana.statPanel.new(title='Alerts by Namespace', datasource='${datasource}', reducerFunction='lastNotNull', colorMode='value', graphMode='none', textMode='value_and_name', justifyMode='center')
    .addTarget(
      grafana.prometheus.target('count(kube_namespace_created{%(clusterLabel)s="$cluster"} or ALERTS{%(clusterLabel)s="$cluster"}) by (namespace) - 1' % $._config, legendFormat='{{namespace}}')
    )
    .addThresholds([{ color: 'green' }, { color: 'red', value: 1 }])
    .addDataLink(
      { 
        title: 'Explore Namespace', 
        url: '/d/%s/explore-namespace?var-namespace=${__field.labels.namespace}' % std.md5('model-namespace.json')
      }
    )
    + { gridPos: { w: 24, h: 24 } },


  grafanaDashboards+:: {
    'model-alerts-by-namespace.json':
      g.dashboard.new(title='Explore / Alerts By Namespace')
      .addPanel(alert_by_namespace_panel)
      + {
        templating+: {
          list+: [
            g.template.datasource.new(
              name='datasource',
              label='Data Source',
              query='prometheus'
            ),
            g.template.query.new(
              name='cluster',
              label='Cluster',
              datasource='$datasource',
              query='label_values(up{%(kubeStateMetricsSelector)s}, %(clusterLabel)s)' % $._config,
              hide=if $._config.showMultiCluster then 0 else 2,
              refresh=2,
              includeAll=false,
              sort=1
            ),
          ],
        },
      },
  },
}
