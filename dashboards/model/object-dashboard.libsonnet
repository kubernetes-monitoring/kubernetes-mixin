local c = import 'common.libsonnet';
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
                  <h1 style="margin-top: 5px;">%s: $%s</h1>
              </div>
          </div>
        ||| % [kind, kindLabel],
      },
      transparent: true,
      datasource: '$datasource',
    });

local infoPanel(kind, info, gridPos) =
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
      c.addDatetimePanel(info.name, '%s{%s} * 1e3' % [info.metric, selector], gridPos),
    label:
      if 'value' in info
      then c.addLabelPanel(info.name, '%s{%s} == %d' % [info.metric, selector, info.value], info.label, gridPos)
      else c.addLabelPanel(info.name, '%s{%s}' % [info.metric, selector], info.label, gridPos),
    number:
      c.addNumberPanel(info.name, '%s{%s}' % [info.metric, selector], gridPos),
  }[info.type];

local infoRows(kind) =
  function(d)
    local height = std.length(model.kinds[kind].info) * 2;
    local kindLabel = std.asciiLower(kind);
    local panels = std.mapWithIndex(function(idx, info) infoPanel(kind, info, { x: 0, y: 3 + (idx * 2), h: 2, w: 6 }), model.kinds[kind].info) +
                   [
                     c.addLabelTablePanel('Labels', 'kube_%s_labels{cluster="$cluster", %s="$%s"}' % [kindLabel, kindLabel, kindLabel], 'label_.+', { x: 6, y: 3, h: height, w: 9 }),
                     c.addLabelTablePanel('Annotations', 'kube_%s_annotations{cluster="$cluster", %s="$%s"}' % [kindLabel, kindLabel, kindLabel], 'annotations_.+', { x: 15, y: 3, h: height, w: 9 }),
                   ];
    d.chain(panels);
// std.foldl(function(d, i)
//   d.chain([
//     infoPanel(kind, i, {x: 0, y: 3 + (infoIdx * 2), h: 2, w: 6}),
//   ]), model.kinds[kind].info, d2);

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
  local ycur = std.length(model.kinds[kind].info) * 2 +  // The height of info panels for this type
               3;  // The height of the top label panel, and the info row
  // c.setCursor(0, ycur);

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
      c.addLabelPanel(r.one, query, oneLabel, { w: 6, h: 2 } + c.getCursor(), link=link),
      c.advanceCursorX(6, 2),
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
      c.addTablePanel(r.many + '(s)', query, manyLabel, {w: 8, h: 4} + c.getCursor(), link=link),
      c.advanceCursorX(8, 4),
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
