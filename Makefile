BIN_DIR ?= $(shell pwd)/tmp/bin

JSONNET_VENDOR=vendor
GRAFANA_DASHBOARD_LINTER_BIN=$(BIN_DIR)/dashboard-linter
JB_BIN=$(BIN_DIR)/jb
JSONNET_BIN=$(BIN_DIR)/jsonnet
JSONNETLINT_BIN=$(BIN_DIR)/jsonnet-lint
JSONNETFMT_BIN=$(BIN_DIR)/jsonnetfmt
MD_FILES = $(shell find . \( -type d -name '.vale' -o -type d -name 'vendor' \) -prune -o -type f -name "*.md" -print)
MARKDOWNFMT_BIN=$(BIN_DIR)/markdownfmt
VALE_BIN=$(BIN_DIR)/vale
PROMTOOL_BIN=$(BIN_DIR)/promtool
PINT_BIN=$(BIN_DIR)/pint
TOOLING=$(JB_BIN) $(JSONNETLINT_BIN) $(JSONNET_BIN) $(JSONNETFMT_BIN) $(PROMTOOL_BIN) $(GRAFANA_DASHBOARD_LINTER_BIN) $(MARKDOWNFMT_BIN) $(VALE_BIN) $(PINT_BIN)
JSONNETFMT_ARGS=-n 2 --max-blank-lines 2 --string-style s --comment-style s
SRC_DIR ?=dashboards
OUT_DIR ?=dashboards_out

.PHONY: all
all: fmt generate lint test

.PHONY: dev
dev: generate
	@cd scripts && ./lgtm.sh && \
	echo '' && \
	echo '╔═══════════════════════════════════════════════════════════════╗' && \
	echo '║             🚀 Development Environment Ready! 🚀              ║' && \
	echo '║                                                               ║' && \
	echo '║   Run `make dev-port-forward`                                 ║' && \
	echo '║   Grafana will be available at http://localhost:3000          ║' && \
	echo '║                                                               ║' && \
	echo '║   Data will be available in a few minutes.                    ║' && \
	echo '║                                                               ║' && \
	echo '║   Dashboards will refresh every 10s, run `make generate`      ║' && \
	echo '║   and refresh your browser to see the changes.                ║' && \
	echo '║                                                               ║' && \
	echo '║   Alert and recording rules require `make dev-reload`.        ║' && \
	echo '║                                                               ║' && \
	echo '╚═══════════════════════════════════════════════════════════════╝'

.PHONY: dev-port-forward
dev-port-forward:
	kubectl --context kind-kubernetes-mixin wait --for=condition=Ready pods -l app=lgtm --timeout=300s
	kubectl --context kind-kubernetes-mixin port-forward service/lgtm 3000:3000 4317:4317 4318:4318 9090:9090

dev-reload: generate
	@cp -v prometheus_alerts.yaml scripts/provisioning/prometheus/ && \
	cp -v prometheus_rules.yaml scripts/provisioning/prometheus/ && \
	kubectl --context kind-kubernetes-mixin rollout restart deployment/lgtm && \
	echo '╔═══════════════════════════════════════════════════════════════╗' && \
	echo '║                                                               ║' && \
	echo '║           🔄 Reloading Alert and Recording Rules...           ║' && \
	echo '║                                                               ║' && \
	echo '╚═══════════════════════════════════════════════════════════════╝' && \
	kubectl --context kind-kubernetes-mixin rollout status deployment/lgtm

.PHONY: dev-down
dev-down:
	kind delete cluster --name kubernetes-mixin

.PHONY: generate
generate: prometheus_alerts.yaml prometheus_rules.yaml $(OUT_DIR)

$(JSONNET_VENDOR): $(JB_BIN) jsonnetfile.json
	$(JB_BIN) install

.PHONY: fmt
fmt: jsonnet-fmt markdownfmt

.PHONY: jsonnet-fmt
jsonnet-fmt: $(JSONNETFMT_BIN)
	@find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETFMT_BIN) $(JSONNETFMT_ARGS) -i

.PHONY: markdownfmt
markdownfmt: $(MARKDOWNFMT_BIN)
	@for file in $(MD_FILES); do $(MARKDOWNFMT_BIN) -w -gofmt $$file; done

prometheus_alerts.yaml: $(JSONNET_BIN) mixin.libsonnet lib/alerts.jsonnet alerts/*.libsonnet
	@$(JSONNET_BIN) -J vendor -S lib/alerts.jsonnet > $@

prometheus_rules.yaml: $(JSONNET_BIN) mixin.libsonnet lib/rules.jsonnet rules/*.libsonnet
	@$(JSONNET_BIN) -J vendor -S lib/rules.jsonnet > $@

$(OUT_DIR): $(JSONNET_BIN) $(JSONNET_VENDOR) mixin.libsonnet lib/dashboards.jsonnet $(SRC_DIR)/*.libsonnet
	@mkdir -p $(OUT_DIR)
	@$(JSONNET_BIN) -J vendor -m $(OUT_DIR) lib/dashboards.jsonnet

.PHONY: lint
lint: jsonnet-lint alerts-lint dashboards-lint vale pint-lint

.PHONY: jsonnet-lint
jsonnet-lint: $(JSONNETLINT_BIN) $(JSONNET_VENDOR)
	@find . -name 'vendor' -prune -o -name '*.libsonnet' -print -o -name '*.jsonnet' -print | \
		xargs -n 1 -- $(JSONNETLINT_BIN) -J vendor

.PHONY: alerts-lint
alerts-lint: $(PROMTOOL_BIN) prometheus_alerts.yaml prometheus_rules.yaml
	@$(PROMTOOL_BIN) check rules prometheus_rules.yaml
	@$(PROMTOOL_BIN) check rules prometheus_alerts.yaml

$(OUT_DIR)/.lint: $(OUT_DIR)
	@cp .lint $@

.PHONY: dashboards-lint
dashboards-lint: $(GRAFANA_DASHBOARD_LINTER_BIN) $(OUT_DIR)/.lint
	# Replace $$interval:$$resolution var with $$__rate_interval to make dashboard-linter happy.
	@sed -i -e 's/$$interval:$$resolution/$$__rate_interval/g' $(OUT_DIR)/*.json
	@find $(OUT_DIR) -name '*.json' -print0 | xargs -n 1 -0 $(GRAFANA_DASHBOARD_LINTER_BIN) lint --strict

.PHONY: vale
vale: $(VALE_BIN)
	@$(VALE_BIN) sync && \
		$(VALE_BIN) $(MD_FILES)

.PHONY: pint-lint
pint-lint: generate $(PINT_BIN)
	@# Pint will not exit with a non-zero status code if there are linting issues.
	@output=$$($(PINT_BIN) -n -o -l WARN lint prometheus_alerts.yaml prometheus_rules.yaml 2>&1); \
	if [ -n "$$output" ]; then \
		echo "\n$$output"; \
		exit 1; \
	fi

.PHONY: clean
clean:
	# Remove all files and directories ignored by git.
	git clean -Xfd .

.PHONY: test
test: $(PROMTOOL_BIN) prometheus_alerts.yaml prometheus_rules.yaml
	@$(PROMTOOL_BIN) test rules tests/*.yaml

$(BIN_DIR):
	mkdir -p $(BIN_DIR)

$(TOOLING): $(BIN_DIR)
	@echo Installing tools from hack/tools.go
	@cd scripts && go list -e -mod=mod -tags tools -f '{{ range .Imports }}{{ printf "%s\n" .}}{{end}}' ./ | xargs -tI % go build -mod=mod -o $(BIN_DIR) %

########################################
# "check-with-upstream" workflow checks.
########################################

check-selectors-ksm:
	@./scripts/check-selectors-ksm.sh
