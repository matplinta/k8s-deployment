# HyperFlow deployment on Kubernetes

## Running the workflow
From cmds directory run: `./run-workflow.sh ...`
```sh
➜  cmds git:(master) ✗ ./run-workflow.sh
Usage: complete-workflow-run.sh [OPTION]...
  -r	<workflow>		run specified workflow (you can check it with -l parameter)
  -n	<cluster_name>		to set cluster name
  -p	<provider>		specify provider used. Defaults to gcloud
  -N	<node_no>		specify nodes quantity
  -c	to create new cluster
  -l	list all available workflows
  -k	kill cluster in the end
  -w	wait for k8s; after completing workflow, leave k8s config
  -d	ONLY: delete cluster only
  -o	ONLY: reset kubernetes configuration on the cluster only
  -h	display this message
```

### Resize the cluster

To minimize cost, you can delete the cluster when not used (e.g. from the console). However, it may be more convenient to just spin it down to 0 as follows:

```
gcloud container clusters resize my-k8s-cluster --node-pool default-pool --num-nodes=0
```
This command can also be used to resize the cluster to the desired number of nodes.
