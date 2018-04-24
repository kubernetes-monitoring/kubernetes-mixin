JSONNET_FMT := jsonnet fmt -n 2 --max-blank-lines 2 --string-style s --comment-style s

fmt:
	find . -name '*.libsonnet' -o -name '*.jsonnet' | \
		xargs -n 1 -- $(JSONNET_FMT) -i

prometheus_alerts.yaml: mixin.libsonnet lib/alerts.jsonnet alerts/*.libsonnet
	jsonnet -J . -S lib/alerts.jsonnet > $@

prometheus_rules.yaml: mixin.libsonnet lib/rules.jsonnet rules/*.libsonnet
	jsonnet -J . -S lib/rules.jsonnet > $@

dashboards_out: mixin.libsonnet lib/dashboards.jsonnet dashboards/*.libsonnet
	@mkdir -p dashboards_out
	jsonnet -J . -J vendor -m dashboards_out lib/dashboards.jsonnet

lint: prometheus_alerts.yaml prometheus_rules.yaml
	find . -name '*.libsonnet' -o -name '*.jsonnet' | \
		while read f; do \
			$(JSONNET_FMT) "$$f" | diff -u "$$f" -; \
		done

	promtool check rules prometheus_rules.yaml
	promtool check rules prometheus_alerts.yaml
