BIN_DIR ?= $(shell pwd)/tmp/bin

JSONNET_VENDOR=vendor
JB_BIN=$(BIN_DIR)/jb
JSONNET_BIN=$(BIN_DIR)/jsonnet
JSONNETLINT_BIN=$(BIN_DIR)/jsonnet-lint
JSONNETFMT_BIN=$(BIN_DIR)/jsonnetfmt
PROMTOOL_BIN=$(BIN_DIR)/promtool
TOOLING=$(JB_BIN) $(JSONNETLINT_BIN) $(JSONNET_BIN) $(JSONNETFMT_BIN) $(PROMTOOL_BIN)
JSONNETFMT_ARGS=-n 2 --max-blank-lines 2 --string-style s --comment-style s

.PHONY: all
all: fmt generate lint test

.PHONY: generate
generate: prometheus_alerts.yaml prometheus_rules.yaml dashboards_out

$(JSONNET_VENDOR): $(JB_BIN) jsonnetfile.json
	$(JB_BIN) install

.PHONY: fmt
fmt: $(JSONNETFMT_BIN)
	find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETFMT_BIN) $(JSONNETFMT_ARGS) -i

prometheus_alerts.yaml: $(JSONNET_BIN) mixin.libsonnet lib/alerts.jsonnet alerts/*.libsonnet
	@$(JSONNET_BIN) -J vendor -S lib/alerts.jsonnet > $@

prometheus_rules.yaml: $(JSONNET_BIN) mixin.libsonnet lib/rules.jsonnet rules/*.libsonnet
	@$(JSONNET_BIN) -J vendor -S lib/rules.jsonnet > $@

dashboards_out: $(JSONNET_BIN) $(JSONNET_VENDOR) mixin.libsonnet lib/dashboards.jsonnet dashboards/*.libsonnet
	@mkdir -p dashboards_out
	@$(JSONNET_BIN) -J vendor -m dashboards_out lib/dashboards.jsonnet

.PHONY: lint
lint: $(PROMTOOL_BIN) $(JSONNET_VENDOR) prometheus_alerts.yaml prometheus_rules.yaml
	find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETLINT_BIN) -J vendor

	@$(PROMTOOL_BIN) check rules prometheus_rules.yaml
	@$(PROMTOOL_BIN) check rules prometheus_alerts.yaml

.PHONY: clean
clean:
	# Remove all files and directories ignored by git.
	git clean -Xfd .

.PHONY: test
test: $(PROMTOOL_BIN) prometheus_alerts.yaml prometheus_rules.yaml
	@$(PROMTOOL_BIN) test rules tests.yaml

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TOOLING): $(BIN_DIR)
	@echo Installing tools from hack/tools.go
	@cd scripts && go list -mod=mod -tags tools -f '{{ range .Imports }}{{ printf "%s\n" .}}{{end}}' ./ | xargs -tI % go build -mod=mod -o $(BIN_DIR) %

