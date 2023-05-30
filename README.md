# K8s 101
Software you need for this workshop:
* [Docker](https://docs.docker.com/get-docker/)
* [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
* [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
* unix environment (Linux, MacOS of WSL)
* Decent editor with YAML schema validator (e.g. [YAML language server](https://github.com/redhat-developer/yaml-language-server) ) - Optional
* [jq](https://stedolan.github.io/jq/) and [yq](https://github.com/mikefarah/yq), json and yaml processors
* [k9s](https://k9scli.io/) - Optional

## Theory

![k8s diagram](graphics/k8s-basic-diagram.png)

Kubernetes is often shortened to K8s (there are 8 letters between K and s).

### Containers
Are a unit of functionality that addresses a single concern. A container image is self-contained and defines and 
carries its runtime dependencies.

### Pods
A Pod is an atomic unit of scheduling, deployment, and runtime isolation for a group of containers.  
The only way to run a container is via pod!
All containers in a Pod are always scheduled to the same host, are deployed and scaled together, and can also share 
filesystem, networking, and process namespaces.  
Containers within a pod interact via localhost. From outside pod looks like a single unix machine and have a single IP.  
Pods are ephemeral. IP assigned only after it is scheduled.

### Services
Service binds service name to IP and port. It's a named entry for accessing applications.
Service usually points to a set of pods. Also provide load balancing.

### Namespaces
Provide A way of dividing k8s resources. Provide scopes for Kubernetes resources and a mechanism to apply 
authorizations and other policies to a subsection of the cluster.  
Can be used for staging (e.g. dev, test, prod), can also be used to achieve multitenancy.

## Further Reading
The [official kubernetes documentation is quite good](https://kubernetes.io/docs/home/), note this doesn't extend to a lot of
the other projects in the kubernetes ecosystem. Have a look at their
[tutorials](https://kubernetes.io/docs/tutorials/) or the [explanation of pods](https://kubernetes.io/docs/concepts/workloads/pods/).

Some other literature we can recommend:
* [Kubernetes App Development](https://matthewpalmer.net/kubernetes-app-developer/), very short but gets you very well started
* [Kubernetes in Action](https://www.manning.com/books/kubernetes-in-action-second-edition), very thorough,
  1st edition somewhat outdated, 2nd edition only available as a preview
* [Kubernetes Patterns](https://www.oreilly.com/library/view/kubernetes-patterns-2nd/9781098131678/), a bit more advanced material

## Getting started
We first need a Kubernetes distribution. For local development [kind](https://kind.sigs.k8s.io) is a good fit.
It stands for Kubernetes In Docker and runs a whole cluster within docker.  

### Note about registry
We need a way of hosting container images to deploy on k8s. For common apps public registries (e.g. Docker Hub) 
are used. For development purposes we can host a registry locally. Use `00_kind/start_kind_with_registry.sh` 
to start a kind cluster with registry linked to it.  

#### Potential problems
If the script complains about ports being taken use the following command to find the process occupying port 5001
and kill it.
```shell
sudo lsof -i -n -P | grep TCP | grep 5001
```

## Starting a cluster
```shell
kind create cluster
```
or with registry:
```shell
sh 00_kind/start_kind_with_registry.sh
```

## Deleting a cluster
```shell
kind delete cluster
```

## Interacting with cluster - kubectl

```shell
kubectl cluster-info # or kubectl cluster-info --context kind-kind

# Get available contexts
kubectl config get-contexts
# Set kind-kind context to be default context
kubectl config use-context kind-kind

# Get nodes
kubectl get nodes # short: kubectl get no
# Get nodes
kubectl get namespaces # short: kubectl get ns
# Get all pods
kubectl get po -A # short: kubectl get po -A
```
### kubectl
Command line tool for interaction with k8s clusters. 

`kubectl <command> <resource> <options>`

Commands:
* get
* create
* replace
* apply
* delete

kubectl config: `~/.kube/`

## Deploying stuff
Single command:
```shell
kubectl run alpine --image=alpine -- sleep 600
```

While it can convenient using `kubectl run` to deploy pods the preferred way is using manifests.
Manifests are yaml (or json) documents describing resources you want to deploy on k8s. Here's an example:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-world
  # namespace: default
spec:
  containers:
    - name: hello-container
      image: alpine
      command: [ "/bin/sh" ]
      args:
        - "-c"
        - |
          echo "Hello, World!"
          sleep 3600
```

### Pods
Deploying:
```shell
kubectl apply -f 01_intro/00_hello_world_pod.yaml
```
Inspecting:
```shell
kubectl get po -n default
# Getting logs
kubectl logs hello-world -n default
# Getting state
kubectl describe pod hello-world -n default
# Getting manifest
kubectl get po hello-world -n default -o yaml # | yq
```
Debugging:
```shell
# Exec a command in a pod
kubectl exec -it hello-world -- sh
```
Within pod shell:
```shell
ps ax # PID 1 is the main container process
ls / # we see regular unix filesystem
```

Deleting:
```yaml
kubectl delete pod hello-world -n default
```

## What is a pod?

```
kubectl explain pod
```
Also works for all other objects.

### Deployments
Deployment enables declarative updates for Pods and ReplicaSets - i.e.
manages Pods and ReplicaSets.  

Deploying:
```shell
kubectl apply -f 01_intro/01_hello_world_deployment.yaml
```

Inspecting:
```yaml
kubectl describe deploy hello-world-deployment
# Inspect replica set that controls pod
kubectl describe replicaset hello-world-deployment-<REPLACE>
# Inspect pod
kubectl describe pod hello-world-deployment-<REPLACE>
```

Deployment makes sure there is always enough pods available. Try deleting a pod:
```yaml
kubectl delete pod hello-world-deployment-<REPLACE>
```
What happens?

## Custom applications/container images
For this section to work you have to have a local registry!

### Basic example
Building an image and pushing it to local registry.
```shell
cd 02_custom_applications/00_alpine_python
docker build . -t localhost:5001/alpine-python:0.1

# test locally with docker
docker run -it localhost:5001/alpine-python:0.1

docker push localhost:5001/alpine-python:0.1
```

deploy a pod that uses the new image:

```shell
kubectl apply -f 02_custom_applications/00_hello_world_pod_python.yaml
```

### Pack everything into container
For proper applications you want to pack your code inside a container.
```shell
docker build . -t localhost:5001/python-hello:0.1
# test with docker
docker run localhost:5001/python-hello:0.1
# push to registry
docker push localhost:5001/python-hello:0.1
```

deploy:
```shell
kubectl apply -f 02_custom_applications/01_python_app.yaml
```

## Networking and Services
`Services` forward networking requests to groups of pods selected by labels.

Apply an example echo pod and accompanying service and have a look at the yaml
file:

```shell
kubectl apply -f 03_services/pods_and_service.yaml
```

Check the output `kubectl get svc -o wide`.

Forward the port of the service and the single pod:

```shell
kubectl port-forward service/echo-service 8081:8080
```

```shell
kubectl port-forward echo-server-1 8082:80
```

Test the services with curl:

```
curl localhost:8081
curl localhost:8082
```

That service is now reachable under the pods ip on port 80 inside the cluster,
on port 8080 on the services IP and name `echo-service.default.svc.cluster.local` (also
only inside the cluster) and also on port 30888 on the nodes IP (e.g. your
localhost), but only if kind is configured as required (see
[kind docs](https://kind.sigs.k8s.io/docs/user/configuration/#extra-port-mappings)).

Try it from curl from inside your cluster:

```bash
kubectl run curlpod --image=curlimages/curl -i --tty -- sh
```


Deploy a second pod with the same label:

```bash
kubectl apply -f 03_services/second_pod.yaml
```

observe what happens when you curl against the service, use
`kubectl logs -f <pod-name>`.

Delete both pods (`kubectl delete pod <pod-name>`) and try to curl against the
service.

Then deploy `03_services/echo-deployment.yaml`.

Services and deployments work well together, but one does not require the other.

![Services and Pods](graphics/networking.png)

## Namespaces
Namespaces (or short ns) divide your cluster into several virtual clusters.

Check the namespaces currently installed (`kubectl get ns`).

Create a new namespace:

```shell
kubectl create ns my-custom-ns
```
and check if it has been created, then delete it.

Create a new namespace from the `custom_ns.yaml` file:

```shell
kubectl apply -f custom_ns.yaml
```

What is the name of that namespace?

Some resources are namespaced (like pods or deployments), others not (like
namespaces themselves).

By default, `kubectl` uses the default namespace. You can use the `-n
<namespace>` flag to specify a namespace for most kubectl commands.

Try to create a deployment in the custom-application namespace.


## Config maps and secrets
ConfigMap holds configuration data for pods to consume.  
Secret is similar to ConfigMap but for secrets. Can hold raw or base64 encoded secrets.  

Data from ConfigMaps can be exposed in a pod as environmental variable or mounted as a file.  
Variable example:
```shell
kubectl apply -f 04_configmaps/my_cm.yaml
kubectl apply -f 04_configmaps/00_hello_cm_deployment.yaml
kubectl logs deployment.apps/hello-cm-deployment
```
Modify configmap and restart deployment:
```shell
kubectl  rollout restart deployment.apps/hello-cm-deployment
# check if the change was picked up (may take some time)
kubectl logs deployment.apps/hello-cm-deployment
```

ConfigMap mounted as a file:
```shell
kubectl apply -f 04_configmaps/01_mount_cm_pod.yaml
kubectl logs pod/mount-cm-pod
# Jump into the pod and check if that file exists
kubectl exec -it mount-cm-pod -- sh
```

## Storage

## Networking

dnsutils

