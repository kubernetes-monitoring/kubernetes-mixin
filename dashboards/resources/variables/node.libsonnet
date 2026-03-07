local common = import './common.libsonnet';

{
  node(config)::
    local datasource = common.datasource(config);
    local clusterVar = common.cluster(config, datasource);
    {
      datasource: datasource,
      cluster: clusterVar,
      node:
        common.queryVar(
          'node',
          datasource,
          'kube_node_info{%(clusterLabel)s="$cluster"}' % config,
          label='node',
          multi=true
        ),
    },
}
