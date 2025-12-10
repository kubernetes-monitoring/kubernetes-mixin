local common = import './common.libsonnet';

{
  cluster(config)::
    local datasource = common.datasource(config);
    {
      datasource: datasource,
      cluster: common.cluster(config, datasource),
    },
}
