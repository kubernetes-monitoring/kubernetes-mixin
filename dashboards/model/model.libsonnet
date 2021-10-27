{
    relationships: [
        {
            one: 'Namespace',
            many: 'Pod',
            metric: 'kube_pod_info',
        },
        {
            one: 'Node',
            many: 'Pod',
            metric: 'kube_pod_info',
        },
        {
            one: 'Pod',
            many: 'Persistentvolumeclaims',
            metric: 'kube_pod_spec_volumes_persistentvolumeclaims_info',
        },
        {
            one: 'ReplicaSet',
            many: 'Pod',
            one_label: 'owner_name',
            metric: 'kube_pod_owner',
            filters: ['owner_is_controller="true"', 'owner_kind="ReplicaSet"'],
        },
        {
            one: 'StatefulSet',
            many: 'Pod',
            one_label: 'owner_name',
            metric: 'kube_pod_owner',
            filters: ['owner_is_controller="true"', 'owner_kind="StatefulSet"'],
        },
        {
            one: 'ReplicaSet',
            many: 'Pod',
            one_label: 'owner_name',
            metric: 'kube_pod_owner',
            filters: ['owner_is_controller="true"', 'owner_kind="ReplicaSet"'],
        },
        {
            one: 'Job',
            many: 'Pod',
            one_label: 'owner_name',
            metric: 'kube_pod_owner',
            filters: ['owner_is_controller="true"', 'owner_kind="Job"'],
        },
        {
            one: 'DaemonSet',
            many: 'Pod',
            one_label: 'owner_name',
            metric: 'kube_pod_owner',
            filters: ['owner_is_controller="true"', 'owner_kind="DaemonSet"'],
        },
    ],

    kinds: std.set(
        [r.one for r in $.relationships] +
        [r.many for r in $.relationships]
    ),
}
