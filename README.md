[![GitHub license](https://img.shields.io/github/license/NVIDIA/gpu-operator?style=flat-square)](https://raw.githubusercontent.com/NVIDIA/gpu-operator/master/LICENSE)

# Important for OpenShift IBM Power Setup:
Images will get pulled from internal registry, therefore use download & push to internal registry:

```
#Download
podman pull mgiessing/gpu-operator-ppc64le:1.5.1
podman pull mgiessing/gpu-feature-discovery-ppc64le:v0.3.0
podman pull mgiessing/k8s-device-plugin-ppc64le:v0.7.3-ubi8
podman pull mgiessing/dcgm-exporter-ppc64le:2.0.13-2.1.1-ubi8

#Tag
podman tag mgiessing/gpu-operator-ppc64le:1.5.1 $HOST/openshift/gpu-operator-ppc64le:1.5.1 
podman tag mgiessing/gpu-feature-discovery-ppc64le:v0.3.0 $HOST/openshift/gpu-feature-discovery-ppc64le:v0.3.0
pdoman tag mgiessing/k8s-device-plugin-ppc64le:v0.7.3-ubi8 $HOST/openshift/k8s-device-plugin-ppc64le:v0.7.3-ubi8
podman tag mgiessing/dcgm-exporter-ppc64le:2.0.13-2.1.1-ubi8 $HOST/openshift/dcgm-exporter-ppc64le:2.0.13-2.1.1-ubi8

#Push to internal registry (you might need to login to openshift and/or podman)
podman push $HOST/openshift/gpu-operator-ppc64le:1.5.1 --tls-verify=False
podman push $HOST/openshift/gpu-feature-discovery-ppc64le:v0.3.0 --tls-verify=False
podman push $HOST/openshift/k8s-device-plugin-ppc64le:v0.7.3-ubi8
podman push $HOST/openshift/dcgm-exporter-ppc64le:2.0.13-2.1.1-ubi8
```

# NVIDIA GPU Operator

![nvidia-gpu-operator](https://www.nvidia.com/content/dam/en-zz/Solutions/Data-Center/egx/nvidia-egx-platform-gold-image-full-2c50-d@2x.jpg)

Kubernetes provides access to special hardware resources such as NVIDIA GPUs, NICs, Infiniband adapters and other devices through the [device plugin framework](https://kubernetes.io/docs/concepts/extend-kubernetes/compute-storage-net/device-plugins/). However, configuring and managing nodes with these hardware resources requires configuration of multiple software components such as drivers, container runtimes or other libraries which  are difficult and prone to errors.
The NVIDIA GPU Operator uses the [operator framework](https://coreos.com/blog/introducing-operator-framework) within Kubernetes to automate the management of all NVIDIA software components needed to provision GPU. These components include the NVIDIA drivers (to enable CUDA), Kubernetes device plugin for GPUs, the NVIDIA Container Runtime, automatic node labelling, [DCGM](https://developer.nvidia.com/dcgm) based monitoring and others.

## Audience and Use-Cases
The GPU Operator allows administrators of Kubernetes clusters to manage GPU nodes just like CPU nodes in the cluster. Instead of provisioning a special OS image for GPU nodes, administrators can rely on a standard OS image for both CPU and GPU nodes and then rely on the GPU Operator to provision the required software components for GPUs.

Note that the GPU Operator is specifically useful for scenarios where the Kubernetes cluster needs to scale quickly - for example provisioning additional GPU nodes on the cloud or on-prem and managing the lifecycle of the underlying software components. Since the GPU Operator runs everything as containers including NVIDIA drivers, the administrators can easily swap various components - simply by starting or stopping containers.

The GPU Operator is not a good fit for scenarios when special OS images are already being provisioned in a GPU cluster (for example using [NVIDIA DGX systems](https://www.nvidia.com/en-us/data-center/dgx-systems/)) or when using hybrid environments that use a combination of Kubernetes and Slurm for workload management.


## Product Documentation
For information on platform support and getting started, visit the official documentation [repository](https://docs.nvidia.com/datacenter/cloud-native/gpu-operator/overview.html). 

## Contributions
[Read the document on contributions](https://github.com/NVIDIA/gpu-operator/blob/master/CONTRIBUTING.md). You can contribute by opening a [pull request](https://help.github.com/en/articles/about-pull-requests).

## Support and Getting Help
Please open [an issue on the GitHub project](https://github.com/NVIDIA/gpu-operator/issues/new) for any questions. Your feedback is appreciated.
