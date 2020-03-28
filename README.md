# HyperFlow deployment on Kubernetes

## Running the workflow
If you already have access to a Kubernetes cluster via `kubectl`, you can run workflows as follows. 

### Creating Kubernetes resources
Create Kubernetes resources as follows:
```
kubectl apply -f crb.yml
kubectl apply -f cm.yml
kubectl apply -f nfs-server-service.yml
kubectl apply -f redis-service.yml
kubectl apply -f redis.yml
kubectl apply -f nfs-server.yml
sed -i -E "s/server:.*/server: `kubectl get services | grep nfs-server | awk '{ print $3 }'`/" pv-pvc.yml
kubectl apply -f pv-pvc.yml
kubectl apply -f hyperflow-engine-deployment.yml
kubectl apply -f parser-job.yml
```

The default configuration runs a small Montage workflow. To change this, configure workflow *worker container* in `hyperflow-engine-deployment.yml` and *data container* in `nfs-server.yml`.

### Running without the data container
If you do not have a data container, you can set up a container that downloads the data before running the workflow. More instructions coming soon...

## Using Google Kubernetes Engine

Here are additional steps you need to do in order to run HyperFlow on the Google Kubernetes Engine.

### Configure `gcloud` and create Kubernetes cluster

- Install the `gcloud` client as described [here](https://cloud.google.com/sdk/install).
- If needed, [create a new project](https://cloud.google.com/resource-manager/docs/creating-managing-projects) using the Google cloud console.
- Create the Kubernetes cluster with the following command (fill in the `project id`):
```
gcloud container clusters create --project=<your project id> --zone=europe-west2-a --num-nodes=4 --cluster-version=1.15.8-gke.2 --machine-type=n1-standard-2 my-k8s-cluster
```
- [Install `kubectl`](https://kubernetes.io/docs/tasks/tools/install-kubectl/) and configure `kubeconfig` to access your GKE cluster [following these instructions](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#generate_kubeconfig_entry).

### Resize the cluster

To minimize cost, you can delete the cluster when not used (e.g. from the console). However, it may be more convenient to just spin it down to 0 as follows:

```
gcloud container clusters resize my-k8s-cluster --node-pool default-pool --num-nodes=0
```
This command can also be used to resize the cluster to the desired number of nodes.


## Configuring bare-metal Kubernetes installation
To properly configure a bare-metal Kubernetes installation (e.g. [minikube](https://kubernetes.io/docs/tasks/tools/install-minikube)) for a HyperFlow+nfs deployment, you need to do the following steps (commands for Ubuntu 18.04).

### Install packages
```
apt install nfs-kernel-server
apt install dnsmasq
```

### Configure NFS service resolution
The `nfs` service is not properly resolved in the cluster because the resolution goes through the host DNS. You can fix this quickly by changing `nfs-server.default` to the IP address (`kubectl get services`) in the `pv-pvc.yml` file. Alternatively, you can configure the name resolution using `dnsmasq` as follows: 

- Add the following to `/etc/dnsmasq.conf`: 
```
server=/cluster.local/10.96.0.10
server=8.8.8.8
listen-address=127.0.0.1
```
- Run this to add an entry to `/etc/hosts`:
```
echo "127.0.1.1 $HOSTNAME" >> /etc/hosts 
```
- Add these lines to `/etc/resolv.conf`:
```
search svc.cluster.local
options ndots:5 timeout:1
```
