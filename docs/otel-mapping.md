# Prometheus → OpenTelemetry Metric Mapping

Mapping of Prometheus metrics used in kubernetes-mixin to:
- Metrics produced by the **OpenTelemetry Collector native receivers**
  (`kubeletstatsreceiver`, `k8sclusterreceiver`, `hostmetricsreceiver`)
- **OpenTelemetry Semantic Conventions** (semconv) for Kubernetes
  (<https://opentelemetry.io/docs/specs/semconv/system/k8s-metrics/>)

A final section highlights misalignments between the actual receiver
implementations and the semconv specification.

---

## Coverage Overview

| Prometheus source | Native OTel receiver | Coverage |
|-------------------|---------------------|----------|
| cAdvisor | `kubeletstatsreceiver` | **Partial** — CPU, memory, network at pod level; no throttling, no per-container I/O, no per-container network |
| kube-state-metrics | `k8sclusterreceiver` | **Partial** — workload counts, pod phase, resource requests/limits; no workload-topology join, no revision tracking, no PLEG |
| Kubelet volume stats | `kubeletstatsreceiver` | **Good** — all volume byte / inode metrics available |
| Kubelet operational | _(none)_ | **No coverage** — PLEG, certificate, runtime ops, cgroup, eviction metrics have no native equivalent |
| node-exporter | `hostmetricsreceiver` | **Partial** — CPU, memory, filesystem, network covered but with different attribute names and granularity |
| kube-apiserver | _(none)_ | **No coverage** — must use `prometheusreceiver` |
| kube-scheduler | _(none)_ | **No coverage** — must use `prometheusreceiver` |
| kube-controller-manager | _(none)_ | **No coverage** — must use `prometheusreceiver` |
| kube-proxy | _(none)_ | **No coverage** — must use `prometheusreceiver` |
| windows-exporter | _(none)_ | **No coverage** |

---

## 1. cAdvisor → `kubeletstatsreceiver`

The `kubeletstatsreceiver` reads from the Kubelet stats summary API.
It has **no per-container network or disk I/O** — those are
cAdvisor-specific and require the cAdvisor endpoint.

### CPU

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `container_cpu_usage_seconds_total` | `container.cpu.time` | `k8s.pod.cpu.time` (pod level) | Receiver splits into `container.cpu.time` (per container) and `k8s.pod.cpu.time` (per pod). Gauge version: `container.cpu.usage` / `k8s.pod.cpu.usage` |
| `container_cpu_cfs_throttled_periods_total` | **No equivalent** | _(not defined)_ | Critical gap: CPU throttle detection missing from all native receivers |
| `container_cpu_cfs_periods_total` | **No equivalent** | _(not defined)_ | Same gap |

### Memory

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `container_memory_working_set_bytes` | `container.memory.working_set` | _(not in k8s semconv)_ | Direct equivalent at container scope |
| `container_memory_rss` | `container.memory.rss` | `k8s.pod.memory.rss` (pod level) | Available per container in receiver |
| `container_memory_cache` | _(not exposed)_ | _(not defined)_ | cAdvisor-only; no equivalent in kubeletstatsreceiver |
| `container_memory_swap` | _(not exposed)_ | _(not defined)_ | cAdvisor-only; no equivalent |

### Network (pod-level only in receiver)

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `container_network_receive_bytes_total` | `k8s.pod.network.io` (direction=receive) | `k8s.pod.network.io` | Prometheus has separate tx/rx metrics; OTel uses a single metric with `direction` attribute. **Only pod-level** — no per-container network in receiver |
| `container_network_transmit_bytes_total` | `k8s.pod.network.io` (direction=transmit) | `k8s.pod.network.io` | Same |
| `container_network_receive_packets_total` | **No equivalent** | _(not defined)_ | Not exposed by kubeletstatsreceiver |
| `container_network_transmit_packets_total` | **No equivalent** | _(not defined)_ | Not exposed |
| `container_network_receive_packets_dropped_total` | **No equivalent** | _(not defined)_ | Not exposed |
| `container_network_transmit_packets_dropped_total` | **No equivalent** | _(not defined)_ | Not exposed |

### Disk I/O

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `container_fs_reads_total` | **No equivalent** | _(not defined)_ | cAdvisor-only I/O operation counts |
| `container_fs_writes_total` | **No equivalent** | _(not defined)_ | cAdvisor-only |
| `container_fs_reads_bytes_total` | **No equivalent** | _(not defined)_ | cAdvisor-only |
| `container_fs_writes_bytes_total` | **No equivalent** | _(not defined)_ | cAdvisor-only |

---

## 2. kube-state-metrics → `k8sclusterreceiver`

### Pods

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `kube_pod_status_phase` | `k8s.pod.phase` | `k8s.pod.status.phase` | Receiver encodes phase as integer (1–5); semconv uses UpDownCounter with phase as attribute value. Name mismatch: `k8s.pod.phase` vs `k8s.pod.status.phase` |
| `kube_pod_container_status_waiting_reason` | `k8s.container.status.reason` (optional) | `k8s.container.status.reason` | Optional metric in receiver; must be enabled explicitly |
| `kube_pod_container_resource_requests` | `k8s.container.cpu_request` / `k8s.container.memory_request` | `k8s.container.cpu.request` / `k8s.container.memory.request` | Receiver splits by resource type into separate metrics; see naming misalignment below |
| `kube_pod_container_resource_limits` | `k8s.container.cpu_limit` / `k8s.container.memory_limit` | `k8s.container.cpu.limit` / `k8s.container.memory.limit` | Same split |
| `kube_pod_owner` | **No metric equivalent** | _(not defined)_ | Critical gap: workload topology (ReplicaSet → Deployment join) is not a metric in OTel. Replaced by `k8sattributesprocessor` enriching resource attributes (`k8s.deployment.name`, `k8s.replicaset.name`) |
| `kube_pod_info` | Resource attributes on all pod metrics | _(resource attributes)_ | `k8s.pod.name`, `k8s.node.name`, `k8s.namespace.name` are resource attributes, not metric labels |

### Deployments

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `kube_deployment_spec_replicas` | `k8s.deployment.desired` | `k8s.deployment.pod.desired` | Name differs: receiver omits `.pod.` infix |
| `kube_deployment_status_replicas_available` | `k8s.deployment.available` | `k8s.deployment.pod.available` | Same |
| `kube_deployment_status_replicas_updated` | **No equivalent** | _(not defined)_ | Not in receiver |
| `kube_deployment_status_observed_generation` | **No equivalent** | _(not defined)_ | Not in receiver |
| `kube_deployment_metadata_generation` | **No equivalent** | _(not defined)_ | Not in receiver |
| `kube_deployment_status_condition` | **No equivalent** | _(not defined)_ | Not in receiver |

### StatefulSets

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `kube_statefulset_replicas` | `k8s.statefulset.desired_pods` | `k8s.statefulset.pod.desired` | Receiver suffix `_pods`; semconv infix `.pod.` |
| `kube_statefulset_status_replicas_ready` | `k8s.statefulset.ready_pods` | `k8s.statefulset.pod.ready` | Same pattern |
| `kube_statefulset_status_replicas_updated` | `k8s.statefulset.updated_pods` | `k8s.statefulset.pod.updated` | Same pattern |
| `kube_statefulset_status_current_revision` | **No equivalent** | _(not defined)_ | Revision string, not a numeric metric |
| `kube_statefulset_status_update_revision` | **No equivalent** | _(not defined)_ | Same |
| `kube_statefulset_status_observed_generation` | **No equivalent** | _(not defined)_ | Not in receiver |
| `kube_statefulset_metadata_generation` | **No equivalent** | _(not defined)_ | Not in receiver |

### DaemonSets

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `kube_daemonset_status_desired_number_scheduled` | `k8s.daemonset.desired_scheduled_nodes` | `k8s.daemonset.node.desired_scheduled` | Suffix vs infix naming |
| `kube_daemonset_status_current_number_scheduled` | `k8s.daemonset.current_scheduled_nodes` | `k8s.daemonset.node.current_scheduled` | Same |
| `kube_daemonset_status_number_misscheduled` | `k8s.daemonset.misscheduled_nodes` | `k8s.daemonset.node.misscheduled` | Same |
| `kube_daemonset_status_number_available` | `k8s.daemonset.ready_nodes` | `k8s.daemonset.node.ready` | `available` vs `ready` naming difference |
| `kube_daemonset_status_updated_number_scheduled` | **No equivalent** | _(not defined)_ | Not in receiver |

### HorizontalPodAutoscalers

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `kube_horizontalpodautoscaler_spec_max_replicas` | `k8s.hpa.max_replicas` | `k8s.hpa.pod.max` | Significant name divergence; semconv uses `.pod.` infix |
| `kube_horizontalpodautoscaler_spec_min_replicas` | `k8s.hpa.min_replicas` | `k8s.hpa.pod.min` | Same |
| `kube_horizontalpodautoscaler_status_current_replicas` | `k8s.hpa.current_replicas` | `k8s.hpa.pod.current` | Same |
| `kube_horizontalpodautoscaler_status_desired_replicas` | `k8s.hpa.desired_replicas` | `k8s.hpa.pod.desired` | Same |

### Jobs

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `kube_job_status_active` | `k8s.job.active_pods` | `k8s.job.pod.active` | Suffix `_pods` vs infix `.pod.` |
| `kube_job_failed` | `k8s.job.failed_pods` | `k8s.job.pod.failed` | Same |
| `kube_job_status_start_time` | **No equivalent** | _(not defined)_ | Not exposed as a metric |

### Nodes

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `kube_node_status_condition` | `k8s.node.condition` (optional) | `k8s.node.condition.status` | Receiver metric is opt-in; attribute name differs: receiver uses `condition`, semconv uses `k8s.node.condition.type` + `k8s.node.condition.status` |
| `kube_node_status_allocatable` | **No metric equivalent** | `k8s.node.cpu.allocatable`, `k8s.node.memory.allocatable`, `k8s.node.pod.allocatable` | Critical gap: allocatable capacity is not exposed as a metric by any current receiver. Semconv defines it but no receiver implements it yet |
| `kube_node_status_capacity` | **No equivalent** | _(not defined in k8s semconv)_ | Not in any receiver |
| `kube_node_spec_unschedulable` | **No equivalent** | _(not defined)_ | Not in receiver |
| `kube_node_spec_taint` | **No equivalent** | _(not defined)_ | Not in receiver |
| `kube_node_role` | **No equivalent** | _(not defined)_ | Not in receiver |

### PersistentVolumes / PVCs

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `kube_persistentvolume_status_phase` | **No equivalent** | _(not defined)_ | PV lifecycle state not in any receiver |
| `kube_persistentvolumeclaim_access_mode` | **No equivalent** | _(not defined)_ | Not in any receiver |
| `kube_persistentvolumeclaim_labels` | **No equivalent** | _(not defined)_ | Used only for label join; `k8sattributesprocessor` handles label propagation in OTel |
| `kubelet_volume_stats_available_bytes` | `k8s.volume.available` | `k8s.pod.volume.available` | Name mismatch: receiver `k8s.volume.*` vs semconv `k8s.pod.volume.*` |
| `kubelet_volume_stats_capacity_bytes` | `k8s.volume.capacity` | `k8s.pod.volume.capacity` | Same |
| `kubelet_volume_stats_used_bytes` | _(no direct match)_ | `k8s.pod.volume.usage` | Receiver exposes `k8s.pod.volume.usage` as optional; no `k8s.volume.used` in default set |
| `kubelet_volume_stats_inodes` | `k8s.volume.inodes` | `k8s.pod.volume.inode.count` | Name mismatch |
| `kubelet_volume_stats_inodes_free` | `k8s.volume.inodes.free` | `k8s.pod.volume.inode.free` | Name mismatch |
| `kubelet_volume_stats_inodes_used` | `k8s.volume.inodes.used` | `k8s.pod.volume.inode.used` | Name mismatch |

### PodDisruptionBudgets / ResourceQuotas

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `kube_poddisruptionbudget_status_desired_healthy` | **No equivalent** | _(not defined)_ | PDB metrics absent from all receivers |
| `kube_poddisruptionbudget_status_current_healthy` | **No equivalent** | _(not defined)_ | Same |
| `kube_resourcequota` | `k8s.resource_quota.hard_limit` / `k8s.resource_quota.used` | Multiple per-resource semconv metrics (e.g., `k8s.resourcequota.cpu.limit.hard`) | Receiver uses a single generic metric with a `resource` attribute; semconv defines per-resource type metrics. The Prometheus `type` label (hard/used) maps to two separate metrics in the receiver |

---

## 3. node-exporter → `hostmetricsreceiver`

The `hostmetricsreceiver` exposes OS-level system metrics.
Note: it does **not** use the `k8s.*` namespace — these are `system.*` metrics.
Kubernetes node-level kubelet stats (CPU, memory, network) are separately
covered by `kubeletstatsreceiver` under `k8s.node.*`.

| Prometheus metric | OTel receiver metric | OTel semconv metric | Notes |
|-------------------|---------------------|---------------------|-------|
| `node_cpu_seconds_total` | `system.cpu.time` | `system.cpu.time` | `mode` label → `state` attribute. Attribute values aligned (`user`, `system`, `idle`, `iowait`, etc.) |
| `node_memory_MemAvailable_bytes` | `system.memory.usage{state=free}` + buffers/cached | _(system semconv)_ | No direct single-metric equivalent; availability must be calculated from multiple states. `k8s.node.memory.available` from kubeletstatsreceiver is the closer match |
| `node_memory_MemTotal_bytes` | Sum of all `system.memory.usage` states | _(system semconv)_ | Must be derived; no single "total" metric |
| `node_memory_MemFree_bytes` | `system.memory.usage{state=free}` | _(system semconv)_ | Aligned via state attribute |
| `node_memory_Buffers_bytes` | `system.memory.usage{state=buffered}` | _(system semconv)_ | Aligned |
| `node_memory_Cached_bytes` | `system.memory.usage{state=cached}` | _(system semconv)_ | Aligned |
| `node_memory_Slab_bytes` | `system.memory.usage{state=slab_reclaimable}` + `{state=slab_unreclaimable}` | _(system semconv)_ | Split into two states vs one Prometheus metric |

---

## 4. Kubelet operational metrics — No native receiver

These metrics have **no coverage** from any native OTel Collector receiver.
They require `prometheusreceiver` scraping the `/metrics` endpoint of the Kubelet.

| Category | Prometheus metrics | Gap description |
|----------|--------------------|-----------------|
| PLEG | `kubelet_pleg_relist_duration_seconds_*`, `kubelet_pleg_relist_interval_seconds_*` | Pod Lifecycle Event Generator latency — critical for detecting kubelet health issues |
| Certificate management | `kubelet_certificate_manager_client_ttl_seconds`, `kubelet_certificate_manager_server_ttl_seconds`, `kubelet_certificate_manager_client_expiration_renew_errors`, `kubelet_server_expiration_renew_errors` | TLS certificate rotation health |
| Evictions | `kubelet_evictions` | Pod eviction event counter |
| Runtime operations | `kubelet_runtime_operations_total`, `kubelet_runtime_operations_errors_total`, `kubelet_runtime_operations_duration_seconds_*` | Container runtime (Docker/containerd) operation health |
| cgroup management | `kubelet_cgroup_manager_duration_seconds_*` | cgroup operation latency |
| Storage operations | `storage_operation_*`, `volume_manager_total_volumes` | Kubernetes volume attach/detach/mount operations |
| Pod scheduling timing | `kubelet_pod_worker_duration_seconds_*`, `kubelet_pod_start_duration_seconds_*` | Pod startup latency tracking |

---

## 5. Control plane metrics — No native receiver

None of the following have native OTel receivers.
All must be collected via `prometheusreceiver`.

| Source | Metrics | Impact on mixin |
|--------|---------|-----------------|
| kube-apiserver | `apiserver_request_total`, `apiserver_request_sli_duration_seconds_*`, `apiserver_client_certificate_expiration_*`, `aggregator_unavailable_apiservice_*` | All API server dashboards and SLO-based burn-rate alerts |
| kube-scheduler | `scheduler_scheduling_attempt_duration_seconds_*`, `scheduler_pod_scheduling_sli_duration_seconds_*`, etc. | Scheduler dashboard entirely |
| kube-controller-manager | `workqueue_*` | Controller manager dashboard entirely |
| kube-proxy | `kubeproxy_sync_proxy_rules_*`, `kubeproxy_network_programming_*` | Proxy dashboard entirely |

---

## 6. Misalignments between receiver implementations and OTel semantic conventions

These are cases where the actual receiver metric names or attribute names **differ** from what
the OTel semantic conventions specify — i.e., the receivers have not yet caught up to the spec,
or the spec was updated after the receivers were implemented.

### 6.1 `k8sclusterreceiver` vs OTel k8s semconv

#### Naming: underscores vs dots in metric name segments

The receiver uses `_` where the semconv uses `.` for separating sub-segments:

| Receiver metric | Semconv metric | Difference |
|-----------------|---------------|------------|
| `k8s.container.cpu_limit` | `k8s.container.cpu.limit` | `_` vs `.` |
| `k8s.container.cpu_request` | `k8s.container.cpu.request` | `_` vs `.` |
| `k8s.container.memory_limit` | `k8s.container.memory.limit` | `_` vs `.` |
| `k8s.container.memory_request` | `k8s.container.memory.request` | `_` vs `.` |
| `k8s.container.ephemeralstorage_limit` | `k8s.container.ephemeral_storage.limit` | `_` vs `.` + different spelling |
| `k8s.container.storage_limit` | `k8s.container.storage.limit` | `_` vs `.` |

#### Naming: resource-type suffix `_pods`/`_nodes` vs `.pod.`/`.node.` infix

| Receiver metric | Semconv metric | Difference |
|-----------------|---------------|------------|
| `k8s.deployment.available` | `k8s.deployment.pod.available` | missing `.pod.` infix |
| `k8s.deployment.desired` | `k8s.deployment.pod.desired` | missing `.pod.` infix |
| `k8s.replicaset.available` | `k8s.replicaset.pod.available` | missing `.pod.` infix |
| `k8s.replicaset.desired` | `k8s.replicaset.pod.desired` | missing `.pod.` infix |
| `k8s.statefulset.desired_pods` | `k8s.statefulset.pod.desired` | suffix vs infix |
| `k8s.statefulset.ready_pods` | `k8s.statefulset.pod.ready` | suffix vs infix |
| `k8s.statefulset.current_pods` | `k8s.statefulset.pod.current` | suffix vs infix |
| `k8s.statefulset.updated_pods` | `k8s.statefulset.pod.updated` | suffix vs infix |
| `k8s.daemonset.current_scheduled_nodes` | `k8s.daemonset.node.current_scheduled` | suffix vs infix |
| `k8s.daemonset.desired_scheduled_nodes` | `k8s.daemonset.node.desired_scheduled` | suffix vs infix |
| `k8s.daemonset.misscheduled_nodes` | `k8s.daemonset.node.misscheduled` | suffix vs infix |
| `k8s.daemonset.ready_nodes` | `k8s.daemonset.node.ready` | suffix vs infix |
| `k8s.hpa.current_replicas` | `k8s.hpa.pod.current` | `_replicas` suffix vs `.pod.` infix + shorter name |
| `k8s.hpa.desired_replicas` | `k8s.hpa.pod.desired` | same |
| `k8s.hpa.max_replicas` | `k8s.hpa.pod.max` | same |
| `k8s.hpa.min_replicas` | `k8s.hpa.pod.min` | same |
| `k8s.job.active_pods` | `k8s.job.pod.active` | suffix vs infix |
| `k8s.job.failed_pods` | `k8s.job.pod.failed` | suffix vs infix |
| `k8s.job.successful_pods` | `k8s.job.pod.successful` | suffix vs infix |
| `k8s.job.desired_successful_pods` | `k8s.job.pod.desired_successful` | suffix vs infix |
| `k8s.job.max_parallel_pods` | `k8s.job.pod.max_parallel` | suffix vs infix |

#### Metric semantics: `k8s.pod.phase`

| Aspect | Receiver | Semconv |
|--------|----------|---------|
| Metric name | `k8s.pod.phase` | `k8s.pod.status.phase` |
| Instrument | Gauge | UpDownCounter |
| Unit | _(dimensionless integer)_ | `{pod}` |
| Encoding | Integer (1=Pending, 2=Running, 3=Succeeded, 4=Failed, 5=Unknown) | Phase value as attribute `k8s.pod.status.phase`; metric counts pods in that state |

This is a significant semantic difference: the receiver encodes phase as an
enumerated integer on a per-pod series, while semconv counts pods-per-phase
(making aggregation natural).

#### Node conditions

| Aspect | Receiver | Semconv |
|--------|----------|---------|
| Metric name | `k8s.node.condition` (optional, disabled by default) | `k8s.node.condition.status` |
| Attribute — condition type | `condition` (e.g., `Ready`) | `k8s.node.condition.type` |
| Attribute — condition value | _(integer: 1=true, 0=false)_ | `k8s.node.condition.status` (attribute: `true`, `false`, `unknown`) |

#### Resource quota

| Aspect | Receiver | Semconv |
|--------|----------|---------|
| Approach | Generic: `k8s.resource_quota.hard_limit` + `k8s.resource_quota.used` with `resource` attribute | Per-resource: `k8s.resourcequota.cpu.limit.hard`, `k8s.resourcequota.memory.request.used`, etc. |
| Granularity | Single metric covers all resource types | Separate metric per resource type and scope |

---

### 6.2 `kubeletstatsreceiver` vs OTel k8s semconv

#### Network attribute names

| Attribute purpose | Receiver attribute | Semconv attribute |
|-------------------|-------------------|------------------|
| Network direction | `direction` (values: `receive`, `transmit`) | `network.io.direction` (values: `receive`, `transmit`) |
| Network interface name | `interface` | `network.interface.name` |

Affects: `k8s.pod.network.io`, `k8s.pod.network.errors`, `k8s.node.network.io`, `k8s.node.network.errors`.

#### Volume metric namespace

| Aspect | Receiver | Semconv |
|--------|----------|---------|
| Metric prefix | `k8s.volume.*` (6 metrics) | `k8s.pod.volume.*` (6 metrics) |
| Example | `k8s.volume.available` | `k8s.pod.volume.available` |
| Usage metric | `k8s.pod.volume.usage` (optional) | `k8s.pod.volume.usage` |
| Inode metrics | `k8s.volume.inodes`, `k8s.volume.inodes.free`, `k8s.volume.inodes.used` | `k8s.pod.volume.inode.count`, `k8s.pod.volume.inode.free`, `k8s.pod.volume.inode.used` |

The receiver does not scope volume metrics under the pod namespace (`k8s.pod.volume.*`),
and uses `inodes` as a suffix (e.g., `k8s.volume.inodes`) where semconv uses `inode.count`.

#### Container metrics namespace

The receiver emits container-level metrics under the `container.*` namespace
(e.g., `container.cpu.time`, `container.memory.working_set`), which belongs to the
**generic container semconv** (<https://opentelemetry.io/docs/specs/semconv/system/container-metrics/>),
not the Kubernetes semconv. The OTel k8s semconv uses `k8s.container.*` exclusively for
resource requests/limits/state metrics from the Kubernetes API (produced by `k8sclusterreceiver`).
This namespace split means container runtime stats (`container.*`) and Kubernetes API-derived
container specs (`k8s.container.*`) live in separate namespaces and require joining by
`k8s.container.name` + `k8s.pod.name` resource attributes.

#### Metrics defined in semconv but absent from receiver

| Semconv metric | Notes |
|---------------|-------|
| `k8s.pod.memory.paging.faults` | Page fault counter — not in default kubeletstatsreceiver output |
| `k8s.node.memory.paging.faults` | Same |
| `k8s.node.cpu.allocatable` | Allocatable CPU from node spec — not in kubeletstatsreceiver |
| `k8s.node.memory.allocatable` | Allocatable memory from node spec — not in any receiver |
| `k8s.node.ephemeral_storage.allocatable` | Same |
| `k8s.node.pod.allocatable` | Max schedulable pods — not in any receiver |

These allocatable metrics are critical for the kubernetes-mixin dashboards
(namespace CPU/memory usage vs. allocatable capacity) and are currently
only available via `kube_node_status_allocatable` from kube-state-metrics.

---

### 6.3 `hostmetricsreceiver` vs OTel system semconv

The hostmetricsreceiver targets the
[system metrics semconv](<https://opentelemetry.io/docs/specs/semconv/system/system-metrics/>),
not the k8s semconv. Misalignments within that scope:

| Aspect | Receiver | Semconv |
|--------|----------|---------|
| CPU state attribute | `state` (cpu scraper) | `system.cpu.state` |
| Memory state attribute | `state` (memory scraper) | `system.memory.state` |
| Filesystem state attribute | `state` (filesystem scraper) | `system.filesystem.state` |
| Network direction attribute | `direction` | `network.io.direction` |
| Disk direction attribute | `direction` | `disk.io.direction` |

The `direction` attribute naming is the most prevalent misalignment:
the receiver consistently uses the shorthand `direction` where the semconv
specifies the namespaced form (`network.io.direction`, `disk.io.direction`).

---

## 7. Summary: gaps requiring `prometheusreceiver` or alternative approaches

To fully replicate the kubernetes-mixin dashboards and alerts using OTel native receivers,
the following gaps must be bridged:

| Gap | Recommended bridge |
|-----|--------------------|
| CPU throttling (`container_cpu_cfs_*`) | `prometheusreceiver` scraping cAdvisor |
| Per-container disk I/O (`container_fs_*`) | `prometheusreceiver` scraping cAdvisor |
| Per-container network (`container_network_*`) | `prometheusreceiver` scraping cAdvisor, or `k8s.pod.network.*` from kubeletstatsreceiver (pod-level only) |
| `container_memory_cache`, `container_memory_swap` | `prometheusreceiver` scraping cAdvisor |
| Node allocatable capacity (`kube_node_status_allocatable`) | `prometheusreceiver` scraping kube-state-metrics (semconv defines metrics but no receiver implements them) |
| Node unschedulable / taints / role | `prometheusreceiver` scraping kube-state-metrics |
| PDB metrics | `prometheusreceiver` scraping kube-state-metrics |
| PV lifecycle phase | `prometheusreceiver` scraping kube-state-metrics |
| Workload topology join (`kube_pod_owner`) | `k8sattributesprocessor` enriching resource attributes |
| Kubelet operational (PLEG, certs, runtime ops) | `prometheusreceiver` scraping kubelet `/metrics` |
| kube-apiserver SLO metrics | `prometheusreceiver` scraping apiserver |
| kube-scheduler metrics | `prometheusreceiver` scraping scheduler |
| kube-controller-manager metrics | `prometheusreceiver` scraping controller-manager |
| kube-proxy metrics | `prometheusreceiver` scraping kube-proxy |
| windows-exporter metrics | `prometheusreceiver` scraping windows-exporter (no OTel native equivalent) |
