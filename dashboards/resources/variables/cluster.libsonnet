local common = import './common.libsonnet';

{
  // Cluster dashboard variables
  // Returns both datasource and cluster variables
  cluster(config)::
    local datasource = common.datasource(config);
    {
      datasource: datasource,
      cluster: common.cluster(config, datasource, 'up{%(cadvisorSelector)s}'),
    },
}
