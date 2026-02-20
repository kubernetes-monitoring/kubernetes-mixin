local common = import './common.libsonnet';

{
  pod(config)::
    local datasource = common.datasource(config);
    local clusterVar = common.cluster(config, datasource);
    {
      datasource: datasource,
      cluster: clusterVar,
      namespace: common.namespace(config, datasource),
      pod: common.pod(config, datasource),
      container: common.container(config, datasource), // I Added this line
    },
}