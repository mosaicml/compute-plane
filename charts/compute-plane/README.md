# Compute Plane

The MosaicML Compute Plane is a lightweight collection of services to manage an ML training cluster on Kubernetes. This directory contains a [Helm chart](https://helm.sh/) used to configure and deploy the Compute Plane.

## Requirements
- Kubernetes: versions 1.20 to 1.25 are supported
- [NVIDIA GPU Operator](https://github.com/NVIDIA/gpu-operator): this comes preinstalled on most cloud-managed Kubernetes deployments, such as Amazon's EKS and Google's GKE
- (If running multinode jobs) [scheduler-plugins](https://github.com/kubernetes-sigs/scheduler-plugins): be sure to install the appropriate version for your Kubernetes cluster; should be installed as a second scheduler

For now, you are responsible for provisioning and configuring your own Kubernetes cluster for use with MosaicML, but in the future we will be releasing templates and integrations to simplify this step. Please contact your MosaicML admin if you need assistance with provisioning a Kubernetes cluster; we are happy to assist.

## Installation

**Note:** It is strongly recommended to provision a dedicated Kubernetes cluster for the Compute Plane. Kubernetes resources provisioned by other applications may cause problems with orchestration.

1. Acquire a MosaicML service API key. Contact your MosaicML admin if you do not have one.
2. Clone the repository: `git clone git@github.com:mosaicml/compute-plane.git`.
3. Install the Helm chart: `helm install compute-plane charts/compute-plane --set apiKey=<SERVICE_API_KEY>`.

This will create resources in Kubernetes to deploy the Compute Plane. You can use [`kubectl`](https://kubernetes.io/docs/reference/kubectl/) to check that everything is set up correctly:
```
$ kubectl get pods
NAME                                        READY   STATUS    RESTARTS   AGE
compute-plane-jwt-refresh-c8b6dfd9b-xpw9n   1/1     Running   0          15s
compute-plane-node-doctor-v7pw4             1/1     Running   0          15s
compute-plane-node-doctor-xj9js             1/1     Running   0          14s
compute-plane-worker-6b6d899466-l9stw       1/1     Running   0          14s
```

Once the Compute Plane deployment is installed, refer to the MCLI documentation for information on submitting training runs.

## Configuration

In Helm, the standard way to configure an installation is by creating a [values file](https://helm.sh/docs/chart_template_guide/values_files/). For instance, the Compute Plane can alternatively be configured by creating a `compute_plane_values.yaml` file such as the following:
```yaml
apiKey: <SERVICE_API_KEY>
```

And then run:
```bash
helm install compute-plane charts/compute-plane -f compute_plane_values.yaml
```

A common configuration step is to add a Kubernetes [node selector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) to the Compute Plane deployments to ensure that the Compute Plane schedules onto readily available CPU nodes, rather than GPU nodes. This can be achieved with the following values file:
```yaml
apiKey: <SERVICE_API_KEY>

worker:
    nodeSelector:
        # A KV pair indicating a Kubernetes label and desired value that 
        # identifies the instance(s) where control processes should run.
        # For example:
        node.kubernetes.io/instance-type: m5.large

jwtRefresh:
    nodeSelector:
        # A KV pair indicating a Kubernetes label and desired value that 
        # identifies the instance(s) where control processes should run.
        # This can generally be the same as `worker.nodeSelector`.
        # For example:
        node.kubernetes.io/instance-type: m5.large
```

The Compute Plane itself provides a [values file](values.yaml) which contains the full spec of configuration options for the Compute Plane. Values specified in that file are used as defaults if not overridden elsewhere.

# System Overview

The Compute Plane consists of three distinct components:

- JwtRefresh: A Kubernetes `Deployment` responsible for Compute Plane authentication with the Control Plane
- Worker: A Kubernetes `Deployment` responsible for submitting user workloads and reporting status information to the Control Plane
- NodeDoctor: A Kubernetes `DaemonSet` responsible for reporting detailed node status information to the Control Plane

---
## Worker

The Worker is responsible for submitting and monitoring Kubernetes resources which implement end users' training runs. Training runs themselves are not specified in this Helm chart, because they are dynamically created, but there are some static secondary resources, such as a ServiceAccount, specified for use by runs.

### Configuration

Setting `worker.enabled` to false will disable the Worker, preventing the Compute Plane from scheduling training runs.

By default, all resources specified by this Helm chart will be created in a single namespace, called the "main namespace", but the `runs.namespace` value can be set to override this for training runs, such that training runs (but not the Worker itself) will execute in a separate namespace.

### RBAC

The Worker is provisioned with the following permissions in the runs namespace:

| Resource | Verbs |
| -------- | ----- |
| pods | get, list, watch, create, update, patch, delete |
| configmaps | get, list, watch, create, update, patch, delete |
| secrets | get, list, watch, create, update, patch, delete |
| services | get, list, watch, create, update, patch, delete |
| scheduling.sigs.k8s.io/podgroups | get, list, watch, create, update, patch, delete |
| scheduling.x-k8s.io/podgroups | get, list, watch, create, update, patch, delete |
| events | get, list, watch |

Additionally, if the `worker.rbac.allowNodeReads` value is set to true, allowing the Worker to report node availability to the MosaicML Control Plane, the Worker is provisioned with the following cluster-scoped permissions:

| Resource | Verbs |
| -------- | ----- |
| nodes | get, list, watch |
| apiextensions.k8s.io/customresourcedefinitions | get, list, watch |

And, if the `worker.rbac.allowNodeWrites` value is set to true, the Worker is provisioned with the following additional permissions:

| Resource | Verbs |
| -------- | ----- |
| nodes | update, patch |

Runs submitted by the Worker are also provisioned with permissions, depending on configuration. If `worker.enableRunInteractivity` is set to true (enabled by default), the permissions are the following:

| Resource | Verbs |
| -------- | ----- |
| pods | get |
| pods/exec | create |

Otherwise, if `worker.enableRunLogging` is set to true (enabled by default), the permissions are the following:

| Resource | Verbs |
| -------- | ----- |
| pods | get |

Otherwise, runs are provisioned with no permissions.

---
## JwtRefresh

The JwtRefresh deployment requests and provides up-to-date [JSON Web Tokens](https://auth0.com/docs/secure/tokens/json-web-tokens) for the rest of the Compute Plane. JWTs are requested from the Control Plane, using the service API key to authenticate the request; all subsequent requests to the Control Plane are authenticated using the retrieved tokens.

Having the JwtRefresh deployment be responsible for requesting and providing JWTs for the rest of the Compute Plane comes with several advantages. For instance, this allows user workloads to have user-scoped access to the Control Plane while restricting them from the cluster-scoped access that the Compute Plane services themselves utilize.

### RBAC

The JwtRefresh deployment is provisioned with the following permissions in **both** the main namespace and the runs namespace.

| Resource | Verbs |
| -------- | ----- |
| secrets | get, list, watch, create, update, patch, delete |

---
## NodeDoctor

NodeDoctor is a DeamonSet responsible for monitoring node health, especially as relating to GPUs. It uses the [NVIDIA Management Library](https://developer.nvidia.com/nvidia-management-library-nvml) to check the error rates, availability, and utilization of GPUs on each node, and it reports potential errors to the MosaicML Control Plane.

### Configuration

Setting `nodeDoctor.enabled` to false will disable NodeDoctor, preventing the Compute Plane from detecting GPU issues on nodes.

By default, NodeDoctor uses a [nodeSelector](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector) of `feature.node.kubernetes.io/pci-10de.present: "true"` to ensure the deamon only runs on nodes with GPUs, a [toleration](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/) for the `NoSchedule` taint to allow it to still run on cordoned nodes, and the `system-node-critical` [priority class](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/) to ensure it is scheduled with the highest priority. These settings can all be overridden with the `nodeDoctor.nodeSelector`, `nodeDoctor.tolerations`, and `nodeDoctor.priorityClassName` values, respectively.

### RBAC

NodeDoctor is provisioned with the following permissions in the main namespace:

| Resource | Verbs |
| -------- | ----- |
| pods | get, list, watch |

Additionally, NodeDoctor is provisioned with the following cluster-scoped permissions:

| Resource | Verbs |
| -------- | ----- |
| nodes | get, list, watch |

# Advanced Configuration

## Custom RBAC

All [RBAC](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) resources declared in this chart have an associated `rbac.create` which can be set to false to prevent creation of those resources. This allows you to maintain direct control and configuration over your cluster's RBAC by creating your own RBAC resources for the Compute Plane to use. When an `rbac.create` value is false, the associated `rbac.serviceAccountName` must be set to the name of a pre-existing ServiceAccount resource.

One application of this is to expand the permissions available to training runs. For example, in AWS, you could configure a [ServiceAccount to assume an IAM role](https://docs.aws.amazon.com/eks/latest/userguide/associate-service-account-role.html), allowing your users to access resources inside your AWS VPC without any credentials ever exiting your Compute Plane:

```yaml
runs:
    rbac:
        create: false
        serviceAccountName: "my-aws-iam-serviceaccount"
```
