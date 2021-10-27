local g = import 'github.com/grafana/grafonnet-lib/grafonnet-7.0/grafana.libsonnet';
local model = import "model.libsonnet";
local c = import "common.libsonnet";

local manyToOne(many) =
    function(d)
        std.foldl(function(d, r)
            local manyLabel = std.asciiLower(r.many);
            local oneLabel =
                if 'one_label' in r
                then r.one_label
                else std.asciiLower(r.one);
            local manyFilter = '%s="$%s"' % [manyLabel, manyLabel];
            local filters =
                if 'filters' in r
                then r.filters + [manyFilter]
                else [manyFilter];
            local query = 'group by (%s) (%s{%s})' % [oneLabel, r.metric, std.join(',', filters)];
            local link = "/grafana/d/%s/explore-%s?var-%s=${__series.name}" % [std.md5(r.one), std.asciiLower(r.one), std.asciiLower(r.one)];

            if r.many == many
            then d.chain([
                c.addTextPanel(r.one),
                c.addLabelPanel(query, oneLabel, link=link),
                c.nextRow,
            ])
            else d,
        model.relationships, d);

{
    local dashboardForKind(kind) =
        local kindLabel = std.asciiLower(kind);

        c.dashboard(kind).chain([
            c.addTemplate('namespace'),
            c.addTemplate(kindLabel),
            c.addRow('Related Objects'),
            manyToOne(kind)
        ]),

    grafanaDashboards: {
        ['model-%s.json' % std.asciiLower(kind)]: dashboardForKind(kind)
        for kind in model.kinds
    },
}
