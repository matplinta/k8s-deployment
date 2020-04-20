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
PROJECT_ID=automatize-added-account-token
PROVIDER=gcloud     #aws or gcloud

ALIASES=(
    montage0.25
    montage1.0
    montage2.0
    soykb-example
)

# init workflows: data container name corresponding to worker container appropriate
declare -A WORKFLOWS=( 
    ["hyperflowwms/montage-workflow-data:montage0.25-bf0b1b4450c201ee5f549c7f473d2ef0"]="hyperflowwms/montage-workflow-worker:v1.0.10"
    ["matplinta/montage-workflow-data:montage1.0-v1"]="hyperflowwms/montage-workflow-worker:v1.0.10"
    ["matplinta/montage-workflow-data:montage2.0-v1"]="hyperflowwms/montage-workflow-worker:v1.0.10"
    # ["matplinta/montage2-workflow-data:montage0.25-v1"]="hyperflowwms/montage2-worker:latest"
    ["matplinta/montage2-workflow-data:montage0.001-v3"]="matplinta/montage2-worker:v1"
    ["hyperflowwms/soykb-workflow-data:hyperflow-soykb-example-f6f69d6ca3ebd9fe2458804b59b4ef71"]="hyperflowwms/soykb-workflow-worker:v1.0.10-1-g95b7caf"
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
  -r\t<workflow>\t\trun specified workflow (you can check it with -l parameter)
  -n\t<cluster_name>\t\tto set cluster name
  -p\t<provider>\t\tspecify provider used. Defaults to gcloud
  -c\tto create new cluster
  -l\tlist all available workflows
  -k\tkill cluster in the end
  -w\twait for k8s; after completing workflow, leave k8s config
  -d\tONLY: delete cluster only
  -o\tONLY: reset kubernetes configuration on the cluster only
  -h\tdisplay this message"
exit 0 
}

function change_workflow() {
    if [[ 1 -eq `for i in "${!WORKFLOWS[@]}"; do echo $i; done | grep "$WORKFLOW_NAME" | wc -l` ]]; then
        W_DATA=`for i in "${!WORKFLOWS[@]}"; do echo $i; done | grep "$WORKFLOW_NAME"`
        W_WORKER=${WORKFLOWS[$W_DATA]}
        python3 cmds/changeWorker.py hyperflow-engine-deployment.yml $W_WORKER
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
    kubectl delete deployment,pod,svc,cm --all -n default --timeout 10s
    kubectl delete pv,pvc --all --timeout 10s || kubectl patch pvc nfs -p '{"metadata":{"finalizers":null}}'; kubectl patch pv  nfs -p '{"metadata":{"finalizers":null}}'
    # force delete after 30s timeout of hyperflow-engine pod
    kubectl delete deployment,pod,svc,pv,pvc,cm --all -n default --timeout 30s || kubectl delete pod --all -n default --force --grace-period=0

    # check if all config is gone
    [ `kubectl get pv,pvc,pod,deployment,svc -n default | wc -l` -eq 2 ] && log ":: Kubernetes config on cluster has been cleaned up" || log ":: Could not properly clean up Kubernetes config. Try it yoursefl:\n\"kubectl delete deployment,pod,svc,pv,pvc --all -n default --timeout 30s || kubectl delete pod --all -n default --force --grace-period=0\""
}

function delete_cluster() {
    if [ "$PROVIDER" = "gcloud" ]; then
        gcloud container clusters delete $CLUSTER_NAME --quiet && log ":: Cluster deleted successfully!"
    elif [ "$PROVIDER" = "aws" ]; then
        eksctl delete cluster --region eu-west-1 --name $CLUSTER_NAME --wait && log ":: Cluster deleted successfully!"
    fi
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

# set correct working directory
cd "$(dirname "$0")" && cd ..


while getopts "h?ckvwodln:r:p:" opt; do
    case "$opt" in
    h|\?)
        usage
        ;;
    n)  CLUSTER_NAME=$OPTARG
        [ -z "$CLUSTER_NAME" ] && log ":: Empty cluster name variable\nExiting..." && exit 1
        ;;
    p)  PROVIDER=$OPTARG
        [ -z "$PROVIDER" ] && log ":: Empty provider name, exiting..." && exit 1
        if [ "$PROVIDER" != "aws" ] && [ "$PROVIDER" != "gcloud" ]; then
            log ":: Wrong provider name, exiting..." && exit 1
        fi
        ;;
    r)  WORKFLOW_NAME=$OPTARG
        change_workflow
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
    d)  delete_cluster
        exit 0
        ;;
    esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# start of script

log ":: Working directory set to `pwd`"
log ":: Provider set to $PROVIDER"


if [ $CLUSTER_CREATE -eq 1 ]; then
    log ":: Creating cluster $CLUSTER_NAME"
    if [ "$PROVIDER" = "gcloud" ]; then
        # gcloud config set project automatize-added-account-token
        cmds/create-cluster.sh $CLUSTER_NAME
    elif [ "$PROVIDER" = "aws" ]; then
        eksctl create cluster --name cluster-aws --region eu-west-1 --nodegroup-name node-pool --node-type t3.small --nodes 3 --nodes-min 3 --nodes-max 3 --node-volume-size 20 --ssh-access
    fi
fi

log ":: Getting k8s cluster credentials"
if [ "$PROVIDER" = "gcloud" ]; then
    gcloud container clusters get-credentials $CLUSTER_NAME --zone europe-west4-a --project $PROJECT_ID
elif [ "$PROVIDER" = "aws" ]; then
    aws eks --region eu-west-1 update-kubeconfig --name $CLUSTER_NAME
fi

log ":: List all nodes"
kubectl get nodes

# start kubernetes
log ":: Applying k8s deployments"
# cmds/apply-full-k8s.sh
if [[ "$WORKFLOW_NAME" =~ "soykb" ]]
then
    log ":: SoyKB workflow; changing minimal container memory request of hyperflow"
    python3 cmds/changeMem.py hyperflow-engine-deployment.yml 1050Mi
    apply_k8s
    python3 cmds/changeMem.py hyperflow-engine-deployment.yml del
else
    apply_k8s
fi


log ":: Waiting for hyperflow-engine container to start..."
kubectl wait --for=condition=ready --timeout=-10s --selector=name=hyperflow-engine pod  && log ":: Container hyperflow-engine is running..."
kubectl get pods 

log ":: Show hyperflow env variables and indicate start of running workflow:"
kubectl logs $(kubectl get pods --selector=name=hyperflow-engine --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}') | grep -P 'HF_VAR|Running workflow'

log ":: Waiting for workflow to finish..."
kubectl wait --for=condition=complete --timeout=-10s --selector=name=logs-parser job && log ":: logs-parser job finished"

if [[ "$WORKFLOW_NAME" =~ "montage" ]]; then
    log ":: Check for jpg file in nfs storage"
    kubectl exec $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}') --container nfs-server /bin/ls /exports | grep -i jpg
fi
# kubectl get pods -o go-template='{{- define "checkStatus" -}}name={{- .metadata.name -}};nodeName={{- .spec.nodeName -}};{{- range .status.conditions -}}{{- .type -}}={{- .lastTransitionTime }};{{- end -}}{{- printf "\n" -}}{{- end -}}{{- if .items -}}{{- range .items -}}{{ template "checkStatus" . }}{{- end -}}{{- else -}}{{ template "checkStatus" . }}{{- end -}}'

log ":: Copy nodes.log to nfs server"
mkdir -p tmp && kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name -n default | grep -P 'job|NAME' > tmp/nodes.log
kubectl cp tmp/nodes.log -c nfs-server $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'):/exports

LOGS_DIR=logs/$PROVIDER/$WORKFLOW_NAME
mkdir -p $LOGS_DIR

log ":: Copying parsed logs to $LOGS_DIR"
for file in job_descriptions.jsonl metrics.jsonl sys_info.jsonl nodes.log logs-hf.tar.gz; do
    kubectl cp -c nfs-server $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'):exports/$file $LOGS_DIR/$file
done
ls -1 $LOGS_DIR

cmds/cp-logs-hf.sh tmp/logs-hf-newest

# leave k8s config after workflow finishes
[ $KUBERNETES_WAIT -eq 0 ] && kill_k8s
# kill cluster
[ $CLUSTER_KILL -eq 1 ] && delete_cluster

# aws eks delete-nodegroup --cluster-name cluster-a --nodegroup-name node-pool
# aws eks delete-cluster --name cluster-a