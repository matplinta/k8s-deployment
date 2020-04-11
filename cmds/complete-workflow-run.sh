#/bin/bash

# A POSIX variable
OPTIND=1        # Reset in case getopts has been used previously in the shell.

# init variables
_V=1
COLOR="\e[36m"

CLUSTER_NAME=cluster-x
CLUSTER_CREATE=0
CLUSTER_KILL=0
KUBERNETES_WAIT=0
WORKFLOW_NAME=montage0.25

ALIASES=(
    montage0.25
    montage1.0
    montage2.0
)

# init workflows: data container name corresponding to worker container appropriate
declare -A WORKFLOWS=( 
    ["hyperflowwms/montage-workflow-data:montage0.25-bf0b1b4450c201ee5f549c7f473d2ef0"]="hyperflowwms/montage-workflow-worker:v1.0.9-1-gd61c86c"
    ["matplinta/montage-workflow-data:montage1.0-latest"]="hyperflowwms/montage-workflow-worker:v1.0.9-1-gd61c86c"
    ["matplinta/montage-workflow-data:montage2.0-latest"]="hyperflowwms/montage-workflow-worker:v1.0.9-1-gd61c86c"
)

function show_workflows() {
    printf "%20s %20s\n" 'Workflow name' 'Data container'
    for wflow in "${!WORKFLOWS[@]}"; do printf "%20s %20s\n" "$wflow" "${WORKFLOWS[$wflow]}"; done
}

# init functions
function log () {
    [[ $_V -eq 1 ]] && echo -e "$COLOR$@\e[0m"
}

function usage() { 
echo -e "Usage: complete-workflow-run.sh [OPTION]...
  -r <workflow>\t\trun specified workflow (you can check it with -l parameter)
  -n <cluster_name>\tto set cluster name
  -c\tto create new cluster
  -l\tlist all available workflows
  -k\tkill cluster in the end
  -d\tONLY: delete cluster only
  -w\twait for k8s; after completing workflow, leave k8s config
  -o\tONLY: reset kubernetes configuration on the cluster only
  -h\tdisplay this message"
exit 0 
}

function change_workflow() {
    if [[ 1 -eq `for i in "${!WORKFLOWS[@]}"; do echo $i; done | grep "$WORKFLOW_NAME" | wc -l` ]]; then
        W_DATA=`for i in "${!WORKFLOWS[@]}"; do echo $i; done | grep "$WORKFLOW_NAME"`
        W_WORKER=${WORKFLOWS[$W_DATA]}
        python3 cmds/changeWorker.py hyperflow-engine-deployment $W_WORKER
        python3 cmds/changeDataContainer.py nfs-server.yml $W_DATA
    else
        echo "Could not find specified workflow: \"$WORKFLOW_NAME\""
        exit 1
    fi
}

function apply_k8s() {
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
}

function kill_k8s() {
    # cluster kubernetes cleanup
    log ":: Begin cluster kubernetes cleanup"
    kubectl delete jobs `kubectl get jobs -o custom-columns=:.metadata.name`
    kubectl delete deployment,pod,svc --all -n default --timeout 10s
    kubectl delete pv,pvc --all --timeout 10s || kubectl patch pvc nfs -p '{"metadata":{"finalizers":null}}'; kubectl patch pv  nfs -p '{"metadata":{"finalizers":null}}'
    # force delete after 30s timeout of hyperflow-engine pod
    kubectl delete deployment,pod,svc,pv,pvc --all -n default --timeout 30s || kubectl delete pod --all -n default --force --grace-period=0

    # check if all config is gone
    [ `kubectl get pv,pvc,pod,deployment,svc -n default | wc -l` -eq 2 ] && log ":: Kubernetes config on cluster has been cleaned up" || log ":: Could not properly clean up Kubernetes config. Try it yoursefl:\n\"kubectl delete deployment,pod,svc,pv,pvc --all -n default --timeout 30s || kubectl delete pod --all -n default --force --grace-period=0\""
}

# set correct working directory
cd "$(dirname "$0")" && cd ..


while getopts "h?ckvwodln:r:" opt; do
    case "$opt" in
    h|\?)
        usage
        ;;
    n)  CLUSTER_NAME=$OPTARG
        [ -z "$CLUSTER_NAME" ] && echo -e "Empty cluster name variable\nExiting..."; exit 1
        ;;
    c)  CLUSTER_CREATE=1
        ;;
    k)  CLUSTER_KILL=1
        ;;
    v)  _V=1
        ;;
    w)  KUBERNETES_WAIT=1
        ;;
    o)  kill_k8s
        exit 0
        ;;
    l)  for i in "${ALIASES[@]}"; do 
            echo $i
        done
        exit 0
        ;;
    r)  WORKFLOW_NAME=$OPTARG
        change_workflow
        ;;
    d)  gcloud container clusters delete $CLUSTER_NAME --quiet
        exit 0
        ;;
    esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

log ":: Working directory set to `pwd`"

if [ $CLUSTER_CREATE -eq 1 ]; then
    log ":: Creating cluster $CLUSTER_NAME"
    # gcloud config set project automatize-added-account-token
    cmds/create-cluster.sh $CLUSTER_NAME
    gcloud container clusters get-credentials $CLUSTER_NAME --zone europe-west4-a --project automatize-added-account-token
fi

# start kubernetes
log ":: Applying k8s deployments"
# cmds/apply-full-k8s.sh
apply_k8s

log ":: Waiting for workflow to finish..."
kubectl wait --for=condition=complete --timeout=-10s --selector=name=logs-parser job && log ":: logs-parser job finished"

log ":: Check for jpg file in nfs storage"
kubectl exec $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}') --container nfs-server /bin/ls /exports | grep -i jpg

# kubectl get pods -o go-template='{{- define "checkStatus" -}}name={{- .metadata.name -}};nodeName={{- .spec.nodeName -}};{{- range .status.conditions -}}{{- .type -}}={{- .lastTransitionTime }};{{- end -}}{{- printf "\n" -}}{{- end -}}{{- if .items -}}{{- range .items -}}{{ template "checkStatus" . }}{{- end -}}{{- else -}}{{ template "checkStatus" . }}{{- end -}}'

log ":: Copy nodes.log to nfs server"
mkdir -p tmp && kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name -n default | grep -P 'job|NAME' > tmp/nodes.log
kubectl cp tmp/nodes.log -c nfs-server $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'):/exports

mkdir -p logs/$WORKFLOW_NAME

log ":: Copying parsed logs to logs/$WORKFLOW_NAME"
for file in job_descriptions.jsonl metrics.jsonl sys_info.jsonl nodes.log; do
    kubectl cp -c nfs-server $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'):exports/$file logs/$WORKFLOW_NAME/$file
done

[ $KUBERNETES_WAIT -eq 0 ] && kill_k8s
# kill cluster
[ $CLUSTER_KILL -eq 1 ] && gcloud container clusters delete $CLUSTER_NAME --quiet

