local common = import './common.libsonnet';

{
  pod(config)::
    local datasource = common.datasource(config);
    local clusterVar = common.cluster(config, datasource, 'up{%(kubeStateMetricsSelector)s}');
    {
      datasource: datasource,
      cluster: clusterVar,
      namespace: common.namespace(config, datasource),
      pod: common.pod(config, datasource),
    },
}
