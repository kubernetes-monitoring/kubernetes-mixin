local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local var = g.dashboard.variable;

{
  // Namespace dashboard variables
  // Returns datasource, cluster, and namespace variables
  namespace(config):: {
    datasource:
      var.datasource.new('datasource', 'prometheus')
      + var.datasource.withRegex(config.datasourceFilterRegex)
      + var.datasource.generalOptions.showOnDashboard.withLabelAndValue()
      + var.datasource.generalOptions.withLabel('Data source')
      + {
        current: {
          selected: true,
          text: config.datasourceName,
          value: config.datasourceName,
        },
      },

    cluster:
      var.query.new('cluster')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        config.clusterLabel,
        'up{%(kubeStateMetricsSelector)s}' % config,
      )
      + var.query.generalOptions.withLabel('cluster')
      + var.query.refresh.onTime()
      + (
        if config.showMultiCluster
        then var.query.generalOptions.showOnDashboard.withLabelAndValue()
        else var.query.generalOptions.showOnDashboard.withNothing()
      )
      + var.query.withSort(type='alphabetical'),

    namespace:
      var.query.new('namespace')
      + var.query.withDatasourceFromVariable(self.datasource)
      + var.query.queryTypes.withLabelValues(
        'namespace',
        'kube_namespace_status_phase{%(kubeStateMetricsSelector)s, %(clusterLabel)s="$cluster"}' % config,
      )
      + var.query.generalOptions.withLabel('namespace')
      + var.query.refresh.onTime()
      + var.query.generalOptions.showOnDashboard.withLabelAndValue()
      + var.query.withSort(type='alphabetical'),
  },
}
