local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local var = g.dashboard.variable;
local common = import './common.libsonnet';

{
  cluster(config)::
    local datasource = common.datasource(config);
    local clusterVar =
      common.cluster(config, datasource, 'up{%(kubeStateMetricsSelector)s}')
      + var.query.generalOptions.showOnDashboard.withLabelAndValue();
    {
      datasource: datasource,
      cluster: clusterVar,
    },
}
