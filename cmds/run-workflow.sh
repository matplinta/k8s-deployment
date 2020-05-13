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
PROVIDER=gcloud                             # aws or gcloud
NODES=3                                     # no of nodes
MACHINE_TYPE=e2-small
# GCLOUD: e2-highcpu-4, e2-small, 
# AWS:    t3.medium

# SOYKB_MEM="1050Mi"
SOYKB_MEM="4096"

ALIASES=(
    montage0.25
    montage1.0
    montage2.0
    soykb-example
)

# init workflows: data container name corresponding to worker container appropriate
declare -A WORKFLOWS=( 
    ["matplinta/montage-workflow-data:degree0.25"]="matplinta/montage-workflow-worker"
    ["matplinta/montage-workflow-data:degree1.0"]="hyperflowwms/montage-workflow-worker"
    ["matplinta/montage-workflow-data:degree2.0"]="matplinta/montage-workflow-worker"

    ["matplinta/montage2-workflow-data:degree0.01"]="matplinta/montage2-workflow-worker"
    ["matplinta/montage2-workflow-data:degree0.25"]="matplinta/montage2-workflow-worker"
    ["matplinta/montage2-workflow-data:degree1.0"]="matplinta/montage2-workflow-worker"
    ["matplinta/montage2-workflow-data:degree2.0"]="matplinta/montage2-workflow-worker"

    ["matplinta/soykb-workflow-data:size2"]="matplinta/soykb-workflow-worker"
    ["matplinta/soykb-workflow-data:size4"]="matplinta/soykb-workflow-worker"
    ["matplinta/soykb-workflow-data:size8"]="matplinta/soykb-workflow-worker"
    ["matplinta/soykb-workflow-data:size16"]="matplinta/soykb-workflow-worker"
    ["matplinta/soykb-workflow-data:size32"]="matplinta/soykb-workflow-worker"
    ["matplinta/soykb-workflow-data:size48"]="matplinta/soykb-workflow-worker"
    
    # ["hyperflowwms/soykb-workflow-data:hyperflow-soykb-example-f6f69d6ca3ebd9fe2458804b59b4ef71"]="hyperflowwms/soykb-workflow-worker:v1.0.11"
)

function show_workflows() {
    printf "%20s %20s\n" 'Workflow name' 'Data container'
    for wflow in "${!WORKFLOWS[@]}"; do printf "%20s %20s\n" "$wflow" "${WORKFLOWS[$wflow]}"; done
}

# init functions
function log () {
    [[ $_V -eq 1 ]] && echo -e "$COLOR$@\e[0m"
}

function err () {
    [[ $_V -eq 1 ]] && echo -e "\e[31m$@\e[0m"
}

function usage() { 
echo -e "Usage: run-workflow.sh [OPTION]...
  -r\t<workflow>\t\trun specified workflow (you can check it with -l parameter)
  -n\t<cluster_name>\t\tto set cluster name
  -p\t<provider>\t\tspecify provider used. Defaults to gcloud
  -P\t<project_id>\tgcloud project id
  -N\t<node_no>\t\tspecify nodes quantity
  -m\t<machine_type>\tspecify compute machine type to use (EC2 or ComputeEngine)
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
    if [[ `for i in "${!WORKFLOWS[@]}"; do echo $i; done | grep "$WORKFLOW_NAME" | wc -l` -ge 1 ]]; then
        for i in "${!WORKFLOWS[@]}"; do echo $i; done | grep "$WORKFLOW_NAME"
        W_DATA=`for i in "${!WORKFLOWS[@]}"; do echo $i; done | grep "$WORKFLOW_NAME" | tail -n1`
        W_WORKER=${WORKFLOWS[$W_DATA]}
        python3 cmds/changeWorker.py hyperflow-engine-deployment-edit.yml $W_WORKER
        python3 cmds/changeDataContainer.py nfs-server-edit.yml $W_DATA
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
    kubectl apply -f nfs-server-edit.yml
    sed -i -E "s/server:.*/server: `kubectl get services | grep nfs-server | awk '{ print $3 }'`/" pv-pvc.yml
    kubectl apply -f pv-pvc.yml
    kubectl apply -f hyperflow-engine-deployment-edit.yml
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

function get_k8s_credentials {
    log ":: Getting k8s cluster credentials"
    if [ "$PROVIDER" = "gcloud" ]; then
        gcloud container clusters get-credentials $CLUSTER_NAME --zone europe-west4-a --project $PROJECT_ID
    elif [ "$PROVIDER" = "aws" ]; then
        aws eks --region eu-west-1 update-kubeconfig --name $CLUSTER_NAME
    fi
}

function create_cluster() {
    log ":: Creating cluster $CLUSTER_NAME"
    if [ "$PROVIDER" = "gcloud" ]; then
        # gcloud config set project automatize-added-account-token
        cmds/create-cluster.sh $CLUSTER_NAME $NODES $PROJECT_ID $MACHINE_TYPE
    elif [ "$PROVIDER" = "aws" ]; then
        eksctl create cluster --name $CLUSTER_NAME --region eu-west-1 --nodegroup-name node-pool --node-type "$MACHINE_TYPE" --nodes $NODES --nodes-min $NODES --nodes-max $NODES --node-volume-size 20 --ssh-access
    fi
}

function delete_cluster() {
    if [ "$PROVIDER" = "gcloud" ]; then
        gcloud container clusters delete $CLUSTER_NAME --quiet && log ":: Cluster deleted successfully!"
    elif [ "$PROVIDER" = "aws" ]; then
        eksctl delete cluster --region eu-west-1 --name $CLUSTER_NAME --wait && log ":: Cluster deleted successfully!"
    fi
    # aws eks delete-nodegroup --cluster-name cluster-a --nodegroup-name node-pool
    # aws eks delete-cluster --name cluster-a
}

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

# set correct working directory
cd "$(dirname "$0")" && cd ..


while getopts "h?ckvwodln:N:P:r:p:m:" opt; do
    case "$opt" in
    c)  CLUSTER_CREATE=1
        ;;
    d)  delete_cluster
        exit 0
        ;;
    h|\?)
        usage
        ;;
    P)  PROJECT_ID=$OPTARG
        ;;
    k)  CLUSTER_KILL=1
        ;;
    l)  for i in "${ALIASES[@]}"; do 
            echo $i
        done
        exit 0
        ;;
    m)  MACHINE_TYPE=$OPTARG
        ;;
    n)  CLUSTER_NAME=$OPTARG
        [ -z "$CLUSTER_NAME" ] && log ":: Empty cluster name variable\nExiting..." && exit 1
        ;;
    N)  if ! [[ $OPTARG =~ ^[0-9]+$ ]] ; then
            log ":: Error: Nodes value is not a number"; exit 1
        fi
        NODES=$OPTARG
        ;;
    o)  kill_k8s
        exit 0
        ;;
    p)  PROVIDER=$OPTARG
        [ -z "$PROVIDER" ] && log ":: Empty provider name, exiting..." && exit 1
        if [ "$PROVIDER" != "aws" ] && [ "$PROVIDER" != "gcloud" ]; then
            log ":: Wrong provider name, exiting..." && exit 1
        fi
        ;;
    r)  WORKFLOW_NAME=$OPTARG
        ;;
    w)  KUBERNETES_WAIT=1
        ;;
    v)  _V=1
        ;;
    esac
done

shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# start of script

log ":: Working directory set to `pwd`"
log ":: Provider set to $PROVIDER"


if [ $CLUSTER_CREATE -eq 1 ]; then
    create_cluster
fi

get_k8s_credentials

log ":: List all nodes"
kubectl get nodes


# make working copies of ymls & configure k8s deployments
cp hyperflow-engine-deployment.yml hyperflow-engine-deployment-edit.yml
cp nfs-server.yml nfs-server-edit.yml
change_workflow

log ":: Showing container versions"
(printf "Deployment Image\n" ; grep -rP ':\s+(hyperflowwms|matplinta)' . | grep -P 'edit|parser' | awk '{ print $1, $3 }') | column -t

# start kubernetes
log ":: Applying k8s deployments"
if [[ "$WORKFLOW_NAME" =~ "soykb" ]]
then
    log ":: SoyKB workflow; changing minimal container memory request of hyperflow"
    python3 cmds/changeMem.py hyperflow-engine-deployment-edit.yml $SOYKB_MEM
    apply_k8s
    python3 cmds/changeMem.py hyperflow-engine-deployment-edit.yml del
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

PARSED_DIR_REMOTE_NAME="$(kubectl exec -c nfs-server $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}') ls /exports/parsed)"
# handle if PARSED_DIR_REMOTE_NAME is empty
if [ -z "$PARSED_DIR_REMOTE_NAME" ]; then
    err "## Remote logs dir is non-existant! Parsing must have gone wrong."
    # leave k8s config after workflow finishes
    [ $KUBERNETES_WAIT -eq 0 ] && kill_k8s
    # kill cluster
    err "## Exiting..."
    [ $CLUSTER_KILL -eq 1 ] && delete_cluster
    exit 1
fi

mkdir -p logs/$PROVIDER
LOGS_DIR=logs/$PROVIDER/$PARSED_DIR_REMOTE_NAME

log ":: Copying parsed logs to $LOGS_DIR"
kubectl cp -c nfs-server $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'):exports/parsed/$PARSED_DIR_REMOTE_NAME logs/$PROVIDER/$PARSED_DIR_REMOTE_NAME
for name in  logs-hf.tar.gz workflow.json; do
    kubectl cp -c nfs-server $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'):exports/$name logs/$PROVIDER/$PARSED_DIR_REMOTE_NAME/$name
done

log ":: Create nodes.log"
kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name -n default | grep -P 'job|NAME' > $LOGS_DIR/nodes.log
# cmds/cp-logs-hf.sh tmp/logs-hf-newest
files_no=$(ls -1 $LOGS_DIR | wc -l)

log ":: Copying data to the remote bucket"
# aws s3 sync $LOGS_DIR s3://exec-prediction-data/$PROVIDER/$PARSED_DIR_REMOTE_NAME
gsutil -m cp -r $LOGS_DIR gs://hyperflow-parsed-data/$PROVIDER/$PARSED_DIR_REMOTE_NAME >/dev/null 2>&1
# copied_files_no=$(aws s3 ls s3://exec-prediction-data/$PROVIDER/$PARSED_DIR_REMOTE_NAME | wc -l)
copied_files_no=$(gsutil ls gs://hyperflow-parsed-data/$PROVIDER/$PARSED_DIR_REMOTE_NAME | wc -l)
if [ $files_no -eq $copied_files_no ]; then
    log ":: All logs successfully copied"
    ls $LOGS_DIR
else
    err "## Not all logs copied, something went wrong!"
    err "## Listing local collected logs"
    ls -1 $LOGS_DIR
    err "## Listing gcloud collected logs"
    gsutil ls gs://hyperflow-parsed-data/$PARSED_DIR_REMOTE_NAME
fi

# leave k8s config after workflow finishes
[ $KUBERNETES_WAIT -eq 0 ] && kill_k8s
# kill cluster
[ $CLUSTER_KILL -eq 1 ] && delete_cluster
