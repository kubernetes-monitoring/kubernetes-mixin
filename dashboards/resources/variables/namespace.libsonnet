local common = import './common.libsonnet';

{
  // Namespace dashboard variables
  // Returns datasource, cluster, and namespace variables
  namespace(config)::
    local datasource = common.datasource(config);
    local clusterVar = common.cluster(config, datasource, 'up{%(kubeStateMetricsSelector)s}');
    {
      datasource: datasource,
      cluster: clusterVar,
      namespace: common.namespace(config, datasource),
    },
}
