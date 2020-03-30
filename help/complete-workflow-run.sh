#/bin/bash

CLUSTER_NAME=cluster-x

if [ "$(dirname "$0")" = "." ] ; then
  echo "This script is not meant to be run from this directory. Run it from main repository directory as: help/<script>"
  exit 0
fi

echo ":: Creating cluster $CLUSTER_NAME"
# gcloud config set project automatize-added-account-token
help/create-cluster.sh $CLUSTER_NAME
gcloud container clusters get-credentials $CLUSTER_NAME --zone europe-west4-a --project automatize-added-account-token
help/apply-full-k8s.sh

kubectl wait --for=condition=complete --timeout=-10s --selector=name=logs-parser job && echo ":: logs-parser job finished"
echo ":: Check for jpg file in nfs storage"

kubectl exec $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}') --container nfs-server /bin/ls /exports | grep -i jpg

# kubectl get pods -o go-template='{{- define "checkStatus" -}}name={{- .metadata.name -}};nodeName={{- .spec.nodeName -}};{{- range .status.conditions -}}{{- .type -}}={{- .lastTransitionTime }};{{- end -}}{{- printf "\n" -}}{{- end -}}{{- if .items -}}{{- range .items -}}{{ template "checkStatus" . }}{{- end -}}{{- else -}}{{ template "checkStatus" . }}{{- end -}}'

mkdir -p tmp && kubectl get pod -o=custom-columns=NODE:.spec.nodeName,NAME:.metadata.name -n default | grep job > tmp/nodes.log
kubectl cp tmp/nodes.log -c nfs-server $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'):/exports && rm -f tmp/*


# cluster kubernetes cleanup
# kubectl delete jobs `kubectl get jobs -o custom-columns=:.metadata.name`
# kubectl delete persistentvolumeclaim nfs
# kubectl delete pod hyperflow-engine-77db7d666f-nmgjq -n default --force --grace-period=0

# gcloud container clusters delete $CLUSTER_NAME --quiet