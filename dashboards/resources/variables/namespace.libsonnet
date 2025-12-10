local common = import './common.libsonnet';

{
  namespace(config)::
    local datasource = common.datasource(config);
    local clusterVar = common.cluster(config, datasource);
    {
      datasource: datasource,
      cluster: clusterVar,
      namespace: common.namespace(config, datasource),
    },
}
