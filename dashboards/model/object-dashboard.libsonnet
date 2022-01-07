local c = import 'common.libsonnet';
local g = import 'github.com/grafana/grafonnet-lib/grafonnet-7.0/grafana.libsonnet';
local model = import 'model.libsonnet';

local headerPanel(kind) =
  local kindLabel = std.asciiLower(kind);
  local icon = model.kinds[kind].icon;
  function(d)
    d.addPanel({
      gridPos: {
        w: 24,
        h: 2,
      },
      type: 'text',
      options: {
        mode: 'html',
        content: |||
          <div style="padding: 0px;">
              <div style="display: flex; flex-direction: row; align-items: center; margin-top: 0px;">
                  <img style="height: 48px; width: 48px; margin-right: 10px;" src="%s" alt="%s"/>
                  <h1 style="margin-top: 5px;">%s: $%s</h1>
              </div>
          </div>
        ||| % [icon, kind, kind, kindLabel],
      },
      transparent: true,
      datasource: null,
    });

local infoPanel(kind, info) =
  local kindLabel = std.asciiLower(kind);
  local filters = [
    'cluster="$cluster"',
    if model.kinds[kind].namespaced
    then 'namespace="$namespace"'
    else null,
    '%s="$%s"' % [kindLabel, kindLabel],
  ];
  local selector = std.join(',', [f for f in filters if f != null]);
  {
    datetime:
      c.addDatetimePanel('%s{%s} * 1e3' % [info.metric, selector]),
    label:
      if 'value' in info
      then c.addLabelPanel('%s{%s} == %d' % [info.metric, selector, info.value], info.label)
      else c.addLabelPanel('%s{%s}' % [info.metric, selector], info.label),
    number:
      c.addNumberPanel('%s{%s}' % [info.metric, selector]),
  }[info.type];

local infoRows(kind) =
  function(d)
    local kindLabel = std.asciiLower(kind);
    local d2 = d.chain([
      c.nextRow,
      c.addTextPanel('## Labels'),
      c.addLabelTablePanel('kube_%s_labels{cluster="$cluster", %s="$%s"}' % [kindLabel, kindLabel, kindLabel], 'label_.+'),
      c.nextRow,
      c.addTextPanel('## Annotations'),
      c.addLabelTablePanel('kube_%s_annotations{cluster="$cluster", %s="$%s"}' % [kindLabel, kindLabel, kindLabel], 'annotations_.+'),
      c.nextRow,
    ]);
    std.foldl(function(d, i)
      d.chain([
        c.addTextPanel('## %s' % i.name),
        infoPanel(kind, i),
        c.nextRow,
      ]), model.kinds[kind].info, d2);

// addRelationships adds rows (linking the current king to other kind) to d.
//
// There a 8 cases to think about and test if you change this function...
//
// 1. One (namespaced) -> Many (namespaced), eg StatefulSet -> Pod
// 2. One (non-namespaced) -> Many (namespaced), eg Node -> Pod
// 3. Many (namespaced) -> One (namespaced), eg Pod -> StatefulSet
// 4. Many (namespaced) -> One (non-namespaced), eg Pod -> Node
//
// There are 4 cases that are possible, but I don't think actually exist:
//
// a. One (namespaced) -> Many (non-namespaced), eg ???
// b. One (non-namespaced) -> Many (non-namespaced), eg ???
// c. Many (non-namespaced) -> One (namespaced), eg ???
// d. Many (non-namespaced) -> One (non-namespaced), eg ???
local addRelationships(kind) =

  // addSingularLinks adds links from kinds on the 'many' side of a relationship
  // to kinds on the 'one' side of the relationship, eg links from pods -> nodes.
  local addSingularLinks(d, r) =
    local manyLabel = std.asciiLower(r.many);

    // Some relationships don't use the actual name of the kind for the 'one'
    // side of the link (eg kube_pod_owner, where we use owner_name).
    local oneVar = std.asciiLower(r.one);
    local oneLabel =
      if 'one_label' in r
      then r.one_label
      else std.asciiLower(r.one);

    // If the 'one' side of the relationship (eg pod -> controller) is
    // namespaced, we need to group by that label to enrich the link.
    local groupLabels =
      if model.kinds[r.one].namespaced
      then ['namespace', oneLabel]
      else [oneLabel];

    // I'm the 'many' side of the relationship; if I'm namespaced, we
    // need to include that in the selectors.
    local selectors =
      [
        'cluster="$cluster"',
        '%s="$%s"' % [manyLabel, manyLabel],
      ] +
      (if model.kinds[r.many].namespaced
       then ['namespace="$namespace"']
       else []) +
      (if 'filters' in r
       then r.filters
       else []);

    local query = 'group by (%s) (%s{%s})' % [std.join(',', groupLabels), r.metric, std.join(',', selectors)];

    local linkVars = [
      'var-datasource=$datasource',
      'var-cluster=$cluster',
      if model.kinds[r.one].namespaced
      then 'var-namespace=${__field.labels.namespace}',
      'var-%s=${__field.labels.%s}' % [oneVar, oneLabel],
    ];

    local link = '/d/%s/explore-%s?%s' % [std.md5('model-%s.json' % oneVar), oneVar, std.join('&', linkVars)];

    d.chain([
      c.addLinkPanel(r.one, r.one),
      c.addLabelPanel(query, oneLabel, link=link),
      c.nextRow,
    ]);

  // addListLinks adds links from kinds on the 'one' side of a relationship
  // to kinds on the 'many' side of the relationship, eg links from node -> pods.
  local addListLinks(d, r) =
    local manyLabel = std.asciiLower(r.many);

    // Some relationships don't use the actual name of the kind for the 'one'
    // side of the link (eg kube_pod_owner, where we use owner_name).
    local oneLabel =
      if 'one_label' in r
      then r.one_label
      else std.asciiLower(r.one);

    // If the 'many' side of the relationship (eg node -> pods) is namespaced,
    // we need to group by that label to enrich the link.
    local groupLabels =
      if model.kinds[r.many].namespaced
      then ['namespace', manyLabel]
      else [manyLabel];

    // If the 'one' side of the relatioship (eg pod -> controller) is namespaced,
    // we need to include that in the selectors.
    local selectors =
      [
        'cluster="$cluster"',
        '%s="$%s"' % [oneLabel, std.asciiLower(r.one)],
      ] +
      (if model.kinds[r.one].namespaced
       then ['namespace="$namespace"']
       else []) +
      (if 'filters' in r
       then r.filters
       else []);

    local query = 'group by (%s) (%s{%s})' % [std.join(',', groupLabels), r.metric, std.join(',', selectors)];

    local linkVars = [
      'var-datasource=$datasource',
      'var-cluster=$cluster',
      if model.kinds[r.many].namespaced
      then 'var-namespace=${__data.fields.namespace}',
      'var-%s=${__data.fields.%s}' % [manyLabel, manyLabel],
    ];

    local link = '/d/%s/explore-%s?%s' % [std.md5('model-%s.json' % manyLabel), manyLabel, std.join('&', linkVars)];

    d.chain([
      c.addLinkPanel(r.many, r.many + '(s)', height=4),
      c.addTablePanel(query, manyLabel, link=link),
      c.nextRow,
    ]);

  function(d)
    d.chain([
      function(d)
        std.foldl(function(d, r)
                    if r.many == kind
                    then addSingularLinks(d, r)
                    else d,
                  model.relationships,
                  d),
      function(d)
        std.foldl(function(d, r)
                    if r.one == kind
                    then addListLinks(d, r)
                    else d,
                  model.relationships,
                  d),
    ]);

local dashboardForKind(kind, config) =
  local kindLabel = std.asciiLower(kind);

  c.dashboard(kind, config).chain([
    if model.kinds[kind].namespaced
    then c.addTemplate('namespace', config),
    headerPanel(kind),
    c.addTemplate(kindLabel, config),
    c.addRow('Info'),
    infoRows(kind),
    c.addRow('Related Objects'),
    addRelationships(kind),
  ]);

{
  grafanaDashboardFolder: 'Kubernetes Explore',

  grafanaDashboards+:: {
    ['model-%s.json' % std.asciiLower(kind)]: dashboardForKind(kind, $._config)
    for kind in std.objectFields(model.kinds)
  },
}
