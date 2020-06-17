import unittest

from io import BytesIO
from tokenize import tokenize, NUMBER, STRING, NAME, ENCODING, ENDMARKER, NEWLINE


class Token:

    def __init__(self, no, toknum, tokval):
        self.no = no
        self.toknum = toknum
        self.tokval = tokval

    def __repr__(self):
        return f'Token({self.no}, {self.toknum}, "{self.tokval}")'

    def is_name(self):
        return self.toknum == NAME

    def is_string(self):
        return self.toknum == STRING

    def is_number(self):
        return self.toknum == NUMBER

    def is_operation(self):
        return self.tokval in [
            "+", "-", "*", "/", "%", "^",
            "==", "!=", ">", "<", ">=", "<="]

    def is_colon(self):
        return self.tokval == ":"

    def is_leftbracket(self):
        return self.tokval == "("

    def is_rightbracket(self):
        return self.tokval == ")"

    def is_leftcurltbracket(self):
        return self.tokval == "{"

    def is_rightcurltbracket(self):
        return self.tokval == "}"

    def is_leftsquarebracket(self):
        return self.tokval == "["

    def is_rightsquarebracket(self):
        return self.tokval == "]"

    def is_unnecessary(self):
        return self.tokval in [
            'by', 'without',
            'group_left', 'group_right',
            'and', 'or', 'unless', 'ignoring', 'on',
            'count_values', 'quantile', 'topk', 'bottomk']

    def get_next(self, heap):
        try:
            return heap[self.no + 1]
        except IndexError:
            return None

    def get_prev(self, heap):
        try:
            return heap[self.no - 1]
        except IndexError:
            return None


def tokenize_string(query):
    result, x = [], 0
    g = tokenize(BytesIO(query.encode('utf-8')).readline)
    for toknum, tokval, _a, _b, _c in g:
        if not toknum in [ENCODING, ENDMARKER, NEWLINE]:
            result.append(Token(x, toknum, tokval))
            x += 1
    return result


def find_metrics(tokenized_query):
    skip, temp, heap, metrics = False, None, [], []
    for token in tokenized_query:
        if skip == '(' and token.is_rightbracket():
            skip = False
            if heap:
                if heap[-1].is_leftbracket():
                    heap.pop()
                    if heap and heap[-1].is_name():
                        heap.pop()
                if temp:
                    metrics.append(temp)
                    temp = None
        elif skip in ['{', '['] and (token.is_rightcurltbracket() or token.is_rightsquarebracket()):
            skip = False
            if temp:
                metrics.append(temp)
                temp = None
        elif skip:
            continue
        elif token.is_leftbracket():
            heap.append(token)
        elif token.is_leftcurltbracket() or token.is_leftsquarebracket():
            skip = token.tokval
        elif token.is_colon():
            if temp:
                temp += token.tokval
            else:
                temp = token.tokval
        elif token.is_name():
            if token.is_unnecessary():
                if token.get_next(tokenized_query).is_leftbracket():
                    skip = token.get_next(tokenized_query).tokval
            elif token.get_next(tokenized_query):
                if token.get_next(tokenized_query).is_leftbracket():
                    heap.append(token)
                elif token.get_next(tokenized_query).is_leftcurltbracket() or \
                        token.get_next(tokenized_query).is_leftsquarebracket() or \
                        token.get_next(tokenized_query).is_operation() or \
                        token.get_next(tokenized_query).is_rightbracket():
                    if temp:
                        temp += token.tokval
                        metrics.append(temp)
                        temp = None
                    else:
                        metrics.append(token.tokval)
                elif token.get_next(tokenized_query).is_colon():
                    if not temp:
                        temp = token.tokval
                    else:
                        temp += token.tokval
            elif not token.get_next(tokenized_query):
                if temp:
                    temp += token.tokval
                    metrics.append(temp)
                    temp = None
                else:
                    metrics.append(token.tokval)
    return list(set(metrics))


def get_all_metrics(query=None):
    return find_metrics(tokenized_query=tokenize_string(query))


class BaseMessage:

    def error_msg(self, metrics, expected, query):
        return f"\nQuery: {query}\nFound: [{', '.join(metrics)}]\nExpected: [{', '.join(expected)}]"


class TestGeneralTokenize(unittest.TestCase, BaseMessage):

    def test_example1(self):
        query = """sum(up{cluster="$cluster", job="kubelet"})"""
        metrics = get_all_metrics(query)
        expected = {"up"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example2(self):
        query = """sum(kubelet_running_pod_count{cluster="$cluster", job="kubelet", instance=~"$instance"})"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_running_pod_count"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example3(self):
        query = """sum(kubelet_running_container_count{cluster="$cluster", job="kubelet", instance=~"$instance"})"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_running_container_count"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example4(self):
        query = """sum(volume_manager_total_volumes{cluster="$cluster", job="kubelet", instance=~"$instance", state="actual_state_of_world"})"""
        metrics = get_all_metrics(query)
        expected = {"volume_manager_total_volumes"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example5(self):
        query = """sum(volume_manager_total_volumes{cluster="$cluster", job="kubelet", instance=~"$instance",state="desired_state_of_world"})"""
        metrics = get_all_metrics(query)
        expected = {"volume_manager_total_volumes"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example6(self):
        query = """sum(rate(kubelet_node_config_error{cluster="$cluster", job="kubelet", instance=~"$instance"}[5m]))"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_node_config_error"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example7(self):
        query = """sum(rate(kubelet_runtime_operations_total{cluster="$cluster",job="kubelet",instance=~"$instance"}[5m])) by (operation_type, instance)"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_runtime_operations_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example8(self):
        query = """sum(rate(kubelet_runtime_operations_errors_total{cluster="$cluster",job="kubelet",instance=~"$instance"}[5m])) by (instance, operation_type)"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_runtime_operations_errors_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example9(self):
        query = """histogram_quantile(0.99, sum(rate(kubelet_runtime_operations_duration_seconds_bucket{cluster="$cluster",job="kubelet",instance=~"$instance"}[5m])) by (instance, operation_type, le))"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_runtime_operations_duration_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example10(self):
        query = """sum(rate(kubelet_pod_start_duration_seconds_count{cluster="$cluster",job="kubelet",instance=~"$instance"}[5m])) by (instance)"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_pod_start_duration_seconds_count"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example11(self):
        query = """sum(rate(kubelet_pod_worker_duration_seconds_count{cluster="$cluster",job="kubelet",instance=~"$instance"}[5m])) by (instance)"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_pod_worker_duration_seconds_count"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example12(self):
        query = """histogram_quantile(0.99, sum(rate(kubelet_pod_start_duration_seconds_count{cluster="$cluster",job="kubelet",instance=~"$instance"}[5m])) by (instance, le))"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_pod_start_duration_seconds_count"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example13(self):
        query = """histogram_quantile(0.99, sum(rate(kubelet_pod_worker_duration_seconds_bucket{cluster="$cluster",job="kubelet",instance=~"$instance"}[5m])) by (instance, le))"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_pod_worker_duration_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example14(self):
        query = """sum(rate(storage_operation_duration_seconds_count{cluster="$cluster",job="kubelet",instance=~"$instance"}[5m])) by (instance, operation_name, volume_plugin)"""
        metrics = get_all_metrics(query)
        expected = {"storage_operation_duration_seconds_count"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example15(self):
        query = """sum(rate(storage_operation_errors_total{cluster="$cluster",job="kubelet",instance=~"$instance"}[5m])) by (instance, operation_name, volume_plugin)"""
        metrics = get_all_metrics(query)
        expected = {"storage_operation_errors_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example16(self):
        query = """histogram_quantile(0.99, sum(rate(storage_operation_duration_seconds_bucket{cluster="$cluster", job="kubelet", instance=~"$instance"}[5m])) by (instance, operation_name, volume_plugin, le))"""
        metrics = get_all_metrics(query)
        expected = {"storage_operation_duration_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example17(self):
        query = """sum(rate(kubelet_cgroup_manager_duration_seconds_count{cluster="$cluster", job="kubelet", instance=~"$instance"}[5m])) by (instance, operation_type)"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_cgroup_manager_duration_seconds_count"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example18(self):
        query = """histogram_quantile(0.99, sum(rate(kubelet_cgroup_manager_duration_seconds_bucket{cluster="$cluster", job="kubelet", instance=~"$instance"}[5m])) by (instance, operation_type, le))"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_cgroup_manager_duration_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example19(self):
        query = """sum(rate(kubelet_pleg_relist_duration_seconds_count{cluster="$cluster", job="kubelet", instance=~"$instance"}[5m])) by (instance)"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_pleg_relist_duration_seconds_count"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example20(self):
        query = """histogram_quantile(0.99, sum(rate(kubelet_pleg_relist_interval_seconds_bucket{cluster="$cluster",job="kubelet",instance=~"$instance"}[5m])) by (instance, le))"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_pleg_relist_interval_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example21(self):
        query = """histogram_quantile(0.99, sum(rate(kubelet_pleg_relist_duration_seconds_bucket{cluster="$cluster",job="kubelet",instance=~"$instance"}[5m])) by (instance, le))"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_pleg_relist_duration_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example22(self):
        query = """sum(rate(rest_client_requests_total{cluster="$cluster",job="kubelet", instance=~"$instance",code=~"2.."}[5m]))"""
        metrics = get_all_metrics(query)
        expected = {"rest_client_requests_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example23(self):
        query = """sum(rate(rest_client_requests_total{cluster="$cluster",job="kubelet", instance=~"$instance",code=~"3.."}[5m]))"""
        metrics = get_all_metrics(query)
        expected = {"rest_client_requests_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example24(self):
        query = """sum(rate(rest_client_requests_total{cluster="$cluster",job="kubelet", instance=~"$instance",code=~"4.."}[5m]))"""
        metrics = get_all_metrics(query)
        expected = {"rest_client_requests_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example25(self):
        query = """sum(rate(rest_client_requests_total{cluster="$cluster",job="kubelet", instance=~"$instance",code=~"5.."}[5m]))"""
        metrics = get_all_metrics(query)
        expected = {"rest_client_requests_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example26(self):
        query = """histogram_quantile(0.99, sum(rate(rest_client_request_latency_seconds_bucket{cluster="$cluster",job="kubelet", instance=~"$instance"}[5m])) by (instance, verb, url, le))"""
        metrics = get_all_metrics(query)
        expected = {"rest_client_request_latency_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example27(self):
        query = """process_resident_memory_bytes{cluster="$cluster",job="kubelet",instance=~"$instance"}"""
        metrics = get_all_metrics(query)
        expected = {"process_resident_memory_bytes"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example28(self):
        query = """rate(process_cpu_seconds_total{cluster="$cluster",job="kubelet",instance=~"$instance"}[5m])"""
        metrics = get_all_metrics(query)
        expected = {"process_cpu_seconds_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example29(self):
        query = """go_goroutines{cluster="$cluster",job="kubelet",instance=~"$instance"}"""
        metrics = get_all_metrics(query)
        expected = {"go_goroutines"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example30(self):
        query = """sort_desc(min(avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) by (instance)))"""
        metrics = get_all_metrics(query)
        expected = {"node_cpu_seconds_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example31(self):
        query = """min(node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes)"""
        metrics = get_all_metrics(query)
        expected = {"node_memory_MemAvailable_bytes", "node_memory_MemTotal_bytes"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example32(self):
        query = """count(sum by (pod)(delta(kube_pod_container_status_restarts_total[15m]) > 0))"""
        metrics = get_all_metrics(query)
        expected = {"kube_pod_container_status_restarts_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example33(self):
        query = """sum by (pod)(delta(kube_pod_container_status_restarts_total[15m]) > 0)"""
        metrics = get_all_metrics(query)
        expected = {"kube_pod_container_status_restarts_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example34(self):
        query = """sum (kube_pod_status_phase{}) by (phase)"""
        metrics = get_all_metrics(query)
        expected = {"kube_pod_status_phase"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example35(self):
        query = """kubelet_running_pod_count{kubernetes_io_role =~ ".*node.*"}"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_running_pod_count"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example36(self):
        query = """node_load1"""
        metrics = get_all_metrics(query)
        expected = {"node_load1"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example37(self):
        query = """node_memory_MemFree_bytes + node_memory_Buffers_bytes + node_memory_Cached_bytes"""
        metrics = get_all_metrics(query)
        expected = {"node_memory_MemFree_bytes", "node_memory_Buffers_bytes", "node_memory_Cached_bytes"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example38(self):
        query = """avg(rate(node_cpu_seconds_total{mode="idle"}[2m])) by (instance)"""
        metrics = get_all_metrics(query)
        expected = {"node_cpu_seconds_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example39(self):
        query = """min(node_filesystem_avail_bytes{mountpoint!~".*(serviceaccount|proc|sys).*", device!="overlay"}/node_filesystem_size_bytes{mountpoint!~".*(serviceaccount|proc|sys).*", device!="overlay"}) by (device, instance)"""
        metrics = get_all_metrics(query)
        expected = {"node_filesystem_avail_bytes", "node_filesystem_size_bytes"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example40(self):
        query = """rate(node_disk_io_time_seconds_total[2m])"""
        metrics = get_all_metrics(query)
        expected = {"node_disk_io_time_seconds_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example41(self):
        query = """sum(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{%(clusterLabel)s="$cluster", namespace="$namespace"} * on(namespace,pod) group_left(workload, workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", namespace="$namespace", workload_type="$type"}) by (workload, workload_type)"""
        metrics = get_all_metrics(query)
        expected = {"node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate", "mixin_pod_workload"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example42(self):
        query = """sum(rate(kubelet_runtime_operations_total{%(clusterLabel)s="$cluster",%(kubeletSelector)s,instance=~"$instance"}[5m])) by (operation_type, instance)"""
        metrics = get_all_metrics(query)
        expected = {"kubelet_runtime_operations_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_example43(self):
        query = """sum(irate(container_network_receive_bytes_total{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace"}[$__interval]) * on (namespace,pod) group_left(workload,workload_type) mixin_pod_workload{%(clusterLabel)s="$cluster", %(namespaceLabel)s=~"$namespace", workload_type="$type"}) by (workload)"""
        metrics = get_all_metrics(query)
        expected = {"container_network_receive_bytes_total", "mixin_pod_workload"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))


class TestApiServerTokenize(unittest.TestCase, BaseMessage):

    def test_apiserver_01(self):
        query = """apiserver_request:availability30d{verb="all"}"""
        metrics = get_all_metrics(query)
        expected = {"apiserver_request:availability30d"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_02(self):
        query = """100 * (apiserver_request:availability30d{verb="all"} - 0.990000)"""
        metrics = get_all_metrics(query)
        expected = {"apiserver_request:availability30d"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_03(self):
        query = """apiserver_request:availability30d{verb="read"}"""
        metrics = get_all_metrics(query)
        expected = {"apiserver_request:availability30d"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_04(self):
        query = """sum by (code) (code_resource:apiserver_request_total:rate5m{verb="read"})"""
        metrics = get_all_metrics(query)
        expected = {"code_resource:apiserver_request_total:rate5m"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_05(self):
        query = """sum by (resource) (code_resource:apiserver_request_total:rate5m{verb="read",code=~"5.."}) / sum by (resource) (code_resource:apiserver_request_total:rate5m{verb="read"})"""
        metrics = get_all_metrics(query)
        expected = {"code_resource:apiserver_request_total:rate5m"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_06(self):
        query = """cluster_quantile:apiserver_request_duration_seconds:histogram_quantile{verb="read"}"""
        metrics = get_all_metrics(query)
        expected = {"cluster_quantile:apiserver_request_duration_seconds:histogram_quantile"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_07(self):
        query = """apiserver_request:availability30d{verb="write"}"""
        metrics = get_all_metrics(query)
        expected = {"apiserver_request:availability30d"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_08(self):
        query = """sum by (code) (code_resource:apiserver_request_total:rate5m{verb="write"})"""
        metrics = get_all_metrics(query)
        expected = {"code_resource:apiserver_request_total:rate5m"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_09(self):
        query = """sum by (resource) (code_resource:apiserver_request_total:rate5m{verb="write",code=~"5.."}) / sum by (resource) (code_resource:apiserver_request_total:rate5m{verb="write"})"""
        metrics = get_all_metrics(query)
        expected = {"code_resource:apiserver_request_total:rate5m"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_10(self):
        query = """cluster_quantile:apiserver_request_duration_seconds:histogram_quantile{verb="write"}"""
        metrics = get_all_metrics(query)
        expected = {"cluster_quantile:apiserver_request_duration_seconds:histogram_quantile"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_11(self):
        query = """sum(rate(workqueue_adds_total{job="kube-apiserver", instance=~"$instance", cluster="$cluster"}[5m])) by (instance, name)"""
        metrics = get_all_metrics(query)
        expected = {"workqueue_adds_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_12(self):
        query = """sum(rate(workqueue_depth{job="kube-apiserver", instance=~"$instance", cluster="$cluster"}[5m])) by (instance, name)"""
        metrics = get_all_metrics(query)
        expected = {"workqueue_depth"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_13(self):
        query = """histogram_quantile(0.99, sum(rate(workqueue_queue_duration_seconds_bucket{job="kube-apiserver", instance=~"$instance", cluster="$cluster"}[5m])) by (instance, name, le))"""
        metrics = get_all_metrics(query)
        expected = {"workqueue_queue_duration_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_14(self):
        query = """etcd_helper_cache_entry_total{job="kube-apiserver", instance=~"$instance", cluster="$cluster"}"""
        metrics = get_all_metrics(query)
        expected = {"etcd_helper_cache_entry_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_15(self):
        query = """sum(rate(etcd_helper_cache_hit_total{job="kube-apiserver",instance=~"$instance", cluster="$cluster"}[5m])) by (instance)"""
        metrics = get_all_metrics(query)
        expected = {"etcd_helper_cache_hit_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_16(self):
        query = """sum(rate(etcd_helper_cache_miss_total{job="kube-apiserver",instance=~"$instance", cluster="$cluster"}[5m])) by (instance)"""
        metrics = get_all_metrics(query)
        expected = {"etcd_helper_cache_miss_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_17(self):
        query = """histogram_quantile(0.99,sum(rate(etcd_request_cache_get_duration_seconds_bucket{job="kube-apiserver",instance=~"$instance", cluster="$cluster"}[5m])) by (instance, le))"""
        metrics = get_all_metrics(query)
        expected = {"etcd_request_cache_get_duration_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_18(self):
        query = """histogram_quantile(0.99,sum(rate(etcd_request_cache_add_duration_seconds_bucket{job="kube-apiserver",instance=~"$instance", cluster="$cluster"}[5m])) by (instance, le))"""
        metrics = get_all_metrics(query)
        expected = {"etcd_request_cache_add_duration_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_19(self):
        query = """process_resident_memory_bytes{job="kube-apiserver",instance=~"$instance", cluster="$cluster"}"""
        metrics = get_all_metrics(query)
        expected = {"process_resident_memory_bytes"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_20(self):
        query = """rate(process_cpu_seconds_total{job="kube-apiserver",instance=~"$instance", cluster="$cluster"}[5m])"""
        metrics = get_all_metrics(query)
        expected = {"process_cpu_seconds_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_apiserver_21(self):
        query = """go_goroutines{job="kube-apiserver",instance=~"$instance", cluster="$cluster"}"""
        metrics = get_all_metrics(query)
        expected = {"go_goroutines"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))


class TestKubeletTokenize(unittest.TestCase, BaseMessage):

    def test_kubelet_01(self):
        query = """sort_desc(sum(irate(container_network_receive_bytes_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_receive_bytes_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_02(self):
        query = """sort_desc(sum(irate(container_network_transmit_bytes_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_transmit_bytes_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_03(self):
        query = """sort_desc(sum(irate(container_network_receive_bytes_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_receive_bytes_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_04(self):
        query = """sort_desc(sum(irate(container_network_transmit_bytes_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_transmit_bytes_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_05(self):
        query = """sort_desc(avg(irate(container_network_receive_bytes_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_receive_bytes_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_06(self):
        query = """sort_desc(avg(irate(container_network_transmit_bytes_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_transmit_bytes_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_07(self):
        query = """sort_desc(sum(irate(container_network_receive_packets_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_receive_packets_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_08(self):
        query = """sort_desc(sum(irate(container_network_transmit_packets_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_transmit_packets_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_09(self):
        query = """sort_desc(sum(irate(container_network_receive_packets_dropped_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_receive_packets_dropped_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_10(self):
        query = """sort_desc(sum(irate(container_network_transmit_packets_dropped_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_transmit_packets_dropped_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_11(self):
        query = """sort_desc(avg(irate(container_network_receive_bytes_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_receive_bytes_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_12(self):
        query = """sort_desc(avg(irate(container_network_transmit_bytes_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_transmit_bytes_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_13(self):
        query = """sort_desc(sum(irate(container_network_receive_bytes_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_receive_bytes_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_14(self):
        query = """sort_desc(sum(irate(container_network_transmit_bytes_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_transmit_bytes_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_15(self):
        query = """sort_desc(sum(irate(container_network_receive_packets_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_receive_packets_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_16(self):
        query = """sort_desc(sum(irate(container_network_transmit_packets_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_transmit_packets_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_17(self):
        query = """sort_desc(sum(irate(container_network_receive_packets_dropped_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_receive_packets_dropped_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_18(self):
        query = """sort_desc(sum(irate(container_network_transmit_packets_dropped_total{namespace=~".+"}[$interval:$resolution])) by (namespace))"""
        metrics = get_all_metrics(query)
        expected = {"container_network_transmit_packets_dropped_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_19(self):
        query = """sort_desc(sum(rate(node_netstat_Tcp_RetransSegs[$interval:$resolution]) / rate(node_netstat_Tcp_OutSegs[$interval:$resolution])) by (instance))"""
        metrics = get_all_metrics(query)
        expected = {"node_netstat_Tcp_RetransSegs", "node_netstat_Tcp_OutSegs"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_kubelet_20(self):
        query = """sort_desc(sum(rate(node_netstat_TcpExt_TCPSynRetrans[$interval:$resolution]) / rate(node_netstat_Tcp_RetransSegs[$interval:$resolution])) by (instance))"""
        metrics = get_all_metrics(query)
        expected = {"node_netstat_TcpExt_TCPSynRetrans", "node_netstat_Tcp_RetransSegs"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))


class TestControllerManagerTokenize(unittest.TestCase, BaseMessage):

    def test_controllermanager_01(self):
        query = """sum(up{job="kube-controller-manager"})"""
        metrics = get_all_metrics(query)
        expected = {"up"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_controllermanager_02(self):
        query = """sum(rate(workqueue_adds_total{job="kube-controller-manager", instance=~"$instance"}[5m])) by (instance, name)"""
        metrics = get_all_metrics(query)
        expected = {"workqueue_adds_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_controllermanager_03(self):
        query = """sum(rate(workqueue_depth{job="kube-controller-manager", instance=~"$instance"}[5m])) by (instance, name)"""
        metrics = get_all_metrics(query)
        expected = {"workqueue_depth"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_controllermanager_04(self):
        query = """histogram_quantile(0.99, sum(rate(workqueue_queue_duration_seconds_bucket{job="kube-controller-manager", instance=~"$instance"}[5m])) by (instance, name, le))"""
        metrics = get_all_metrics(query)
        expected = {"workqueue_queue_duration_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_controllermanager_05(self):
        query = """sum(rate(rest_client_requests_total{job="kube-controller-manager", instance=~"$instance",code=~"2.."}[5m]))"""
        metrics = get_all_metrics(query)
        expected = {"rest_client_requests_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_controllermanager_06(self):
        query = """sum(rate(rest_client_requests_total{job="kube-controller-manager", instance=~"$instance",code=~"3.."}[5m]))"""
        metrics = get_all_metrics(query)
        expected = {"rest_client_requests_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_controllermanager_07(self):
        query = """sum(rate(rest_client_requests_total{job="kube-controller-manager", instance=~"$instance",code=~"4.."}[5m]))"""
        metrics = get_all_metrics(query)
        expected = {"rest_client_requests_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_controllermanager_08(self):
        query = """sum(rate(rest_client_requests_total{job="kube-controller-manager", instance=~"$instance",code=~"5.."}[5m]))"""
        metrics = get_all_metrics(query)
        expected = {"rest_client_requests_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_controllermanager_09(self):
        query = """histogram_quantile(0.99, sum(rate(rest_client_request_latency_seconds_bucket{job="kube-controller-manager", instance=~"$instance", verb="POST"}[5m])) by (verb, url, le))"""
        metrics = get_all_metrics(query)
        expected = {"rest_client_request_latency_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_controllermanager_10(self):
        query = """histogram_quantile(0.99, sum(rate(rest_client_request_latency_seconds_bucket{job="kube-controller-manager", instance=~"$instance", verb="GET"}[5m])) by (verb, url, le))"""
        metrics = get_all_metrics(query)
        expected = {"rest_client_request_latency_seconds_bucket"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_controllermanager_11(self):
        query = """process_resident_memory_bytes{job="kube-controller-manager",instance=~"$instance"}"""
        metrics = get_all_metrics(query)
        expected = {"process_resident_memory_bytes"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_controllermanager_12(self):
        query = """rate(process_cpu_seconds_total{job="kube-controller-manager",instance=~"$instance"}[5m])"""
        metrics = get_all_metrics(query)
        expected = {"process_cpu_seconds_total"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))

    def test_controllermanager_13(self):
        query = """go_goroutines{job="kube-controller-manager",instance=~"$instance"}"""
        metrics = get_all_metrics(query)
        expected = {"go_goroutines"}
        self.assertCountEqual(set(metrics), expected, self.error_msg(metrics, expected, query))


if __name__ == '__main__':
    unittest.main()
