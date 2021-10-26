local g = import 'github.com/grafana/grafonnet-lib/grafonnet-7.0/grafana.libsonnet';
local layout = import 'github.com/grafana/grafonnet-lib/contrib/layout.libsonnet';

local relationships = [
    {
        one: 'Namespace',
        many: 'Pod',
        metric: 'kube_pod_info',
    },
    {
        one: 'Node',
        many: 'Pod',
        metric: 'kube_pod_info',
    },
    {
        one: 'Pod',
        many: 'Persistentvolumeclaims',
        metric: 'kube_pod_spec_volumes_persistentvolumeclaims_info',
    },
    {
        one: 'ReplicaSet',
        many: 'Pod',
        metric: 'kube_pod_owner{owner_is_controller="true", owner_kind="ReplicaSet"}',
    },
    {
        one: 'StatefulSet',
        many: 'Pod',
        metric: 'kube_pod_owner{owner_is_controller="true", owner_kind="StatefulSet"}',
    },
    {
        one: 'ReplicaSet',
        many: 'Pod',
        metric: 'kube_pod_owner{owner_is_controller="true", owner_kind="ReplicaSet"}',
    },
    {
        one: 'Job',
        many: 'Pod',
        metric: 'kube_pod_owner{owner_is_controller="true", owner_kind="Job"}',
    },
    {
        one: 'DaemonSet',
        many: 'Pod',
        metric: 'kube_pod_owner{owner_is_controller="true", owner_kind="DaemonSet"}',
    },
];

local kinds = std.set(
    [r.one for r in relationships] +
    [r.many for r in relationships]
);

local textPanel(text) = {
  type: 'text',
  title: text,
  gridPos: {
    w: 8,
    h: 1
  },
  transparent: true,
  options: {
    mode: "markdown",
    content: ""
  },
};

local labelPanel(query, label) = {
  type: "stat",
  gridPos: {
    "w": 16,
    "h": 1
  },
  transformations: [],
  datasource: '$datasource',
  targets: [
    {
      "expr": query,
      "legendFormat": '{{%s}}' % label,
      "interval": "",
      "exemplar": false,
      "refId": "A",
      "datasource": "$datasource",
      "instant": true,
    }
  ],
  options: {
    "reduceOptions": {
      "values": true,
      "calcs": [
        "lastNotNull"
      ],
      "fields": ""
    },
    "orientation": "auto",
    "textMode": "name",
    "colorMode": "value",
    "graphMode": "area",
    "justifyMode": "auto",
    "text": {
      "valueSize": 18
    }
  },
  fieldConfig: {
    "defaults": {
      "thresholds": {
        "mode": "absolute",
        "steps": [
          {
            "color": "text",
            "value": null
          }
        ]
      },
      "mappings": [],
      "color": {
        "mode": "thresholds"
      }
    },
    "overrides": []
  },
};

local manyToOne(d, many) =
    std.foldl(function(d, r)
        local oneLabel = std.asciiLower(r.one);
        local manyLabel = std.asciiLower(r.many);

        if r.many != many
        then d
        else d
            .addPanel(textPanel(r.one))
            .addPanel(labelPanel('group by (%s) (%s{%s="$%s"})' % [oneLabel, r.metric, manyLabel, manyLabel], oneLabel))
            .nextRow(),
    relationships, d);

{
  local dashboard(name) =
    g.dashboard.new(title=name, refresh='5m', uid=std.md5(name))
    .setTime(from='now-1h', to='now')
    .addTemplate(
      g.template.datasource.new(name='datasource', query='prometheus')
      .setCurrent(text='default', value='default')
    )
    .addTemplate(
      g.template.query.new(
        allValue='.+',
        datasource='${datasource}',
        includeAll=true,
        label='cluster',
        name='cluster',
        query='label_values(up{%(kubeStateMetricsSelector)s}, %(clusterLabel)s)' % $._config,
        refresh=1,
        regex='',
      )
      .setCurrent(selected=true, text=['All'], value=['$__all'])
    )
    .addTemplate(
      g.template.query.new(
        allValue='.+',
        datasource='${datasource}',
        includeAll=true,
        label='namespace',
        name='namespace',
        query='label_values(kube_namespace_created{%(clusterLabel)s="$cluster"}, namespace)' % $._config.clusterLabel,
        refresh=1,
        regex='',
      )
      .setCurrent(selected=true, text=['All'], value=['$__all'])
    ) + layout,

    local dashboardForKind(kind) =
        local kindLabel = std.asciiLower(kind);
        local d =
            dashboard('Explore / %s' % kind)
            .addTemplate(
                g.template.query.new(
                    datasource='${datasource}',
                    label=kindLabel,
                    name=kindLabel,
                    query='',
                )
            )
            .addPanel({
                collapsed: false,
                datasource: null,
                gridPos: {
                    h: 1,
                    w: 24,
                },
                id: 25,
                panels: [],
                title: kind,
                type: 'row',
            })
            .nextRow();
        manyToOne(d, kind),

    grafanaDashboards: {
        ['model-%s.json' % std.asciiLower(kind)]: dashboardForKind(kind)
        for kind in std.trace(std.toString(kinds), kinds)
    },
}
