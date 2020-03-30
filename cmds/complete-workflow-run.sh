#/bin/bash

# A POSIX variable
OPTIND=1        # Reset in case getopts has been used previously in the shell.

# init variables
CLUSTER_NAME=cluster-x
CLUSTER_CREATE=0
CLUSTER_KILL=0

# set correct working directory
cd "$(dirname "$0")" && cd ..

while getopts "h?nck:" opt; do
    case "$opt" in
    h|\?)
        echo -e "Usage: ./complete-workflow-run.sh [OPTS]:\n\t-n [<cluster_name>]\tto set cluster name\n\t-c\tto create new cluster\n\t-k\tkill cluster in the end\t-h\tdisplay this message"
        exit 0
        ;;
    n)  CLUSTER_NAME=$OPTARG
        [ -z "$CLUSTER_NAME" ] && echo "Empty cluster name variable\nExiting..."; exit 1
        ;;
    c)  CLUSTER_CREATE=1
        ;;
    k)  CLUSTER_KILL=1
        ;;
    esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

if [ $CLUSTER_CREATE -eq 1 ]; then
    echo ":: Creating cluster $CLUSTER_NAME"
    # gcloud config set project automatize-added-account-token
    help/create-cluster.sh $CLUSTER_NAME
    gcloud container clusters get-credentials $CLUSTER_NAME --zone europe-west4-a --project automatize-added-account-token
fi

# start kubernetes
echo ":: Applying k8s deployments"
help/apply-full-k8s.sh

echo ":: Waiting for workflow to finish..."
kubectl wait --for=condition=complete --timeout=-10s --selector=name=logs-parser job && echo ":: logs-parser job finished"

echo ":: Check for jpg file in nfs storage"
kubectl exec $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}') --container nfs-server /bin/ls /exports | grep -i jpg

# kubectl get pods -o go-template='{{- define "checkStatus" -}}name={{- .metadata.name -}};nodeName={{- .spec.nodeName -}};{{- range .status.conditions -}}{{- .type -}}={{- .lastTransitionTime }};{{- end -}}{{- printf "\n" -}}{{- end -}}{{- if .items -}}{{- range .items -}}{{ template "checkStatus" . }}{{- end -}}{{- else -}}{{ template "checkStatus" . }}{{- end -}}'

echo ":: Copy nodes.log to nfs server"
mkdir -p tmp && kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name -n default | grep job > tmp/nodes.log
kubectl cp tmp/nodes.log -c nfs-server $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'):/exports

echo ":: Copying jsonl parsed logs"
for file in job_descriptions.jsonl metrics.jsonl sys_info.jsonl nodes.log; do
    kubectl cp -c nfs-server $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'):exports/$file tmp/$file
done

# cluster kubernetes cleanup
echo ":: Begin cluster kubernetes cleanup"
kubectl delete jobs `kubectl get jobs -o custom-columns=:.metadata.name`
kubectl patch pvc nfs -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl patch pv  nfs -p '{"metadata":{"finalizers":null}}' --type=merge
kubectl delete pvc nfs
kubectl delete pv nfs
# force delete after 30s timeout of hyperflow-engine pod
kubectl delete deployment,pod,svc --all -n default --timeout 30s || kubectl delete pod --all -n default --force --grace-period=0

# check if all config is gone
[ `kubectl get pv,pvc,pod,deployment,svc -n default | wc -l` -eq 2 ] && echo ":: Kubernetes config on cluster has been cleaned up"

# kill cluster
[ $CLUSTER_KILL -eq 1 ] && gcloud container clusters delete $CLUSTER_NAME --quiet