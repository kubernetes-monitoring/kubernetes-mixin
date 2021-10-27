local g = import 'github.com/grafana/grafonnet-lib/grafonnet-7.0/grafana.libsonnet';
local model = import "model.libsonnet";
local c = import "common.libsonnet";

local headerPanel(kind) =
    local kindLabel = std.asciiLower(kind);
    local icon = model.kinds[kind].icon;
    function(d)
        d.addPanel({
            "gridPos": {
                "w": 24,
                "h": 2
            },
            "type": "text",
            "options": {
                "mode": "html",
                "content": |||
                    <div style="padding: 0px;">
                        <div style="display: flex; flex-direction: row; align-items: center; margin-top: 0px;">
                            <img style="height: 48px; width: 48px; margin-right: 10px;" src="%s" alt="%s"/>
                            <h1 style=\"margin-top: 5px;\">%s: $%s</h1>
                        </div>
                    </div>
                ||| % [icon, kind, kind, kindLabel],
            },
            "transparent": true,
            "datasource": null
        });

local infoPanel(kind, info) =
    local kindLabel = std.asciiLower(kind);
    {
        'datetime':
            c.addDatetimePanel('%s{cluster="$cluster", %s="$%s"} * 1e3' % [info.metric, kindLabel, kindLabel]),
        'label':
            if 'value' in info
            then c.addLabelPanel('%s{cluster="$cluster", %s="$%s"} == %d' % [info.metric, kindLabel, kindLabel, info.value], info.label)
            else c.addLabelPanel('%s{cluster="$cluster", %s="$%s"}' % [info.metric, kindLabel, kindLabel], info.label),
        'number':
            c.addNumberPanel('%s{cluster="$cluster", %s="$%s"}' % [info.metric, kindLabel, kindLabel]),
    }[info.type];

local infoRows(kind) =
    function(d)
        local kindLabel = std.asciiLower(kind);
        local d2 = d.chain([
            c.nextRow,
            c.addTextPanel('Labels'),
            c.addLabelTablePanel('kube_%s_labels{%s="$%s"}' % [kindLabel, kindLabel, kindLabel], "label_.+"),
            c.nextRow,
            c.addTextPanel('Annotations'),
            c.addLabelTablePanel('kube_%s_annotations{%s="$%s"}' % [kindLabel, kindLabel, kindLabel], "annotations_.+"),
            c.nextRow,
        ]);
        std.foldl(function(d, i)
            d.chain([
                c.addTextPanel(i.name),
                infoPanel(kind, i),
                c.nextRow,
            ]), model.kinds[kind].info, d2);

// eg manyToOne(pod) adds rows for namespace, node, statefulset etc...
local manyToOne(many) =
    function(d)
        std.foldl(function(d, r)
            local manyLabel = std.asciiLower(r.many);
            local oneLabel =
                if 'one_label' in r
                then r.one_label
                else std.asciiLower(r.one);
            local namespaceFilter =
                if model.kinds[r.one].namespaced
                then ['namespace="$namespace"']
                else [];
            local manyFilter = ['%s="$%s"' % [manyLabel, manyLabel]];
            local filters =
                if 'filters' in r
                then r.filters + namespaceFilter + manyFilter
                else namespaceFilter + manyFilter;
            local query = 'group by (%s) (%s{%s})' % [oneLabel, r.metric, std.join(',', filters)];
            local link = "/d/%s/explore-%s?var-datasource=$datasource&var-%s=${__series.name}" % [std.md5(r.one), std.asciiLower(r.one), std.asciiLower(r.one)];

            if r.many == many
            then d.chain([
                c.addTextPanel(r.one),
                c.addLabelPanel(query, oneLabel, link=link),
                c.nextRow,
            ])
            else d,
        model.relationships, d);

// eg manyToOne(node) adds rows for pod etc...
local oneToMany(one) =
    function(d)
        std.foldl(function(d, r)
            local manyLabel = std.asciiLower(r.many);
            local oneLabel =
                if 'one_label' in r
                then r.one_label
                else std.asciiLower(r.one);
            local oneFilter = '%s="$%s"' % [oneLabel, std.asciiLower(r.one)];
            local filters =
                if 'filters' in r
                then r.filters + [oneFilter]
                else [oneFilter];
            local query = 'group by (%s) (%s{%s})' % [manyLabel, r.metric, std.join(',', filters)];
            local link = "/d/%s/explore-%s?var-datasource=$datasource&var-%s=${__data.fields.%s}" % [std.md5(r.many), std.asciiLower(r.many), std.asciiLower(r.many), manyLabel];

            if r.one == one
            then d.chain([
                c.addTextPanel(r.many + '(s)', height=4),
                c.addTablePanel(query, manyLabel, link=link),
                c.nextRow,
            ])
            else d,
        model.relationships, d);

local dashboardForKind(kind) =
    local kindLabel = std.asciiLower(kind);

    c.dashboard(kind).chain([
        if model.kinds[kind].namespaced
        then c.addTemplate('namespace'),
        headerPanel(kind),
        c.addTemplate(kindLabel),
        c.addRow('Info'),
        infoRows(kind),
        c.addRow('Related Objects'),
        manyToOne(kind),
        oneToMany(kind),
    ]);

{
    grafanaDashboardFolder: "Kubernetes Explore",

    grafanaDashboards: {
        ['model-%s.json' % std.asciiLower(kind)]: dashboardForKind(kind)
        for kind in std.objectFields(model.kinds)
    },
}
