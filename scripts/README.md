How to check metrics in prometheus which exist in Grafana dashboard?
--------------------------------------------------------------------

Before you start, check that script work correctly in your python 3 interpreter please run the command:

```bash
./check_metrics.py --help
```

or 

```bash
python3 check_metrics.py --help
```

If you see output which looks verys similar like below it means that script work correctly.

```bash
usage: check_metrics.py [-h] [grafana-url] [grafana-key] [prometheus-url]

Command line tool for check metrics between grafana and prometheus instance.

positional arguments:
  grafana-url     Set grafana url. Default value is http://localhost:3000
  grafana-key     Set grafana key to have API access.
  prometheus-url  Set prometheus url. Default value is http://localhost:9090

optional arguments:
  -h, --help      show this help message and exit
``` 

Very often prometheus and grafana are hidden behind a proxy. This script does not implement different authorization 
methods for both applications. The easiest way in kubernetes to access the application without proxy is port-forward.

Open port to your graphan:
```bash
kubectl port-forward svc/grafana 3000:80
```

and prometeus instances in different terminal windows:

```bash
kubectl port-forward svc/prometheus-operated 9090:9090
```

Finally run script with default set urls: `./check_metrics.py`. Script will generate for you missing metrics which 
exist in one of grafana dashboard but don’t exist in selected prometheus instance.

Example output:

```bash
CRITICAL:__main__: Metrics which don't exist: node_schedstat_running_seconds_total, node_hwmon_temp_crit_celsius, 
node_interrupts_total, node_netstat_Udp_RcvbufErrors, node_hwmon_temp_crit_alarm_celsius, node_systemd_units, 
process_resident_memory_max_bytes, node_netstat_Udp_SndbufErrors, node_hwmon_temp_crit_hyst_celsius, 
node_netstat_Tcp_MaxConn, node_schedstat_timeslices_total, node_memory_HardwareCorrupted_bytes, 
node_hwmon_temp_max_celsius, node_cooling_device_cur_state, node_cooling_device_max_state, 
node_systemd_socket_accepted_connections_total, node_schedstat_waiting_seconds_total, 
node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate, node_hwmon_temp_celsius, 
kubelet_node_config_error, node_power_supply_online
```

Run test
========

If you need run the test use command:

```bash
python3 tests_tokenize.py
```

again, if everythink looks good, you will see similar output:

```bash
.................................................................................................
----------------------------------------------------------------------
Ran 97 tests in 0.031s

OK
```