# GPU Operator installation on Power

This section contains the [installation](#installation) as well as the [uninstallation/cleanup](#uninstallation--cleanup) of the GPU Operator!

## Prerequisites

- OpenShift (4.8, 4.9 or 4.10) Cluster
- GPU worker node (e.g. AC922)
- Temporary kubeadmin user or a regular user with cluster-admin permissions
- oc & helm client for your system: https://console-openshift-console.apps.${CLUSTER_DOMAIN}/command-line-tools
- git

## Installation

1.) Node Feature Discovery
- Login to your cluster `https://console-openshift-console.apps.${CLUSTER_DOMAIN}` and install Node Feature Discovery Operator:<br>
Operators -> OperatorHub -> Search for Node Feature Discovery (NFD) -> Install -> Create NFD instance 
- Get your (terminal) login token from `https://oauth-openshift.apps.${CLUSTER_DOMAIN}/oauth/token/display` -> Request another token
- Login with provided command and check that the node has been labelled successfully:

```
$ oc describe nodes | grep "10de"
            feature.node.kubernetes.io/pci-10de.present=true
```

2.) Clone & install GPU operator

```
$ git clone -b ppc64le_v1.10.1 https://github.com/mgiessing/gpu-operator.git
$ cd gpu-operator/deployments
$ helm install --wait --generate-name -n gpu-operator --create-namespace gpu-operator
```

3.) Optional: Enable cluster monitoring:

```
$ oc label ns/gpu-operator openshift.io/cluster-monitoring=true
```

4.) Verify successful installation:

```
$ oc get pods
NAME                                                              READY   STATUS      RESTARTS   AGE
gpu-feature-discovery-b7dgw                                       1/1     Running     0          18h
gpu-operator-1650561950-node-feature-discovery-master-85c8rbrcz   1/1     Running     0          18h
gpu-operator-b5bf6d8f4-fnhzr                                      1/1     Running     0          18h
nvidia-container-toolkit-daemonset-7vw8t                          1/1     Running     0          18h
nvidia-cuda-validator-rr8kc                                       0/1     Completed   0          18h
nvidia-dcgm-exporter-rw5nc                                        1/1     Running     0          18h
nvidia-device-plugin-daemonset-vgdxz                              1/1     Running     0          18h
nvidia-device-plugin-validator-cv87s                              0/1     Completed   0          18h
nvidia-driver-daemonset-48.84.202204192209-0-8jt9h                2/2     Running     0          18h
nvidia-operator-validator-sm5q2                                   1/1     Running     0          18h
```

5.) Run a test pod that has a GPU assigned

```
cat<< EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: gpu-operator-test
spec:
  restartPolicy: OnFailure
  containers:
  - name: cuda-vector-add
    image: "quay.io/mgiessing/cuda-sample:vectoradd-cuda11.6.0-ubi8"
    resources:
      limits:
         nvidia.com/gpu: 1
EOF
```

**You have now successfully installed the GPU Operator.**

## Uninstallation / cleanup

1.) Delete via helm

```
$ helm delete $(helm ls --short -n gpu-operator | grep gpu) -n gpu-operator
```

2.) Wait until all pods are gone

```
$ watch oc get pods -n gpu-operator (None should be in state terminating)
```

3.) Delete CRDs

```
$ oc delete crd clusterpolicies.nvidia.com
```

4.) Drain the nodes

```
$ oc adm drain <GPU_NODE> --ignore-daemonsets --delete-emptydir-data --force
```

5.) Connect to the nodes that have GPUs and reboot them to unload the driver

```
$ oc debug node/<GPU_NODE>
$ chroot /host
$ systemctl reboot
```

6.) Make the nodes schedulable again

```
$ oc adm uncordon <GPU_NODE>
```

**The GPU Operator is now successfully uninstalled.**
