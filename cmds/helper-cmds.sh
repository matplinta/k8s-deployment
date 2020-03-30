# cluster alpha
gcloud beta container --project "automatize-added-account-token" clusters create "cluster-2" --zone "europe-west4-a" --no-enable-basic-auth --cluster-version "1.14.10-gke.27" --machine-type "e2-small" --image-type "COS" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --enable-kubernetes-alpha --num-nodes "3" --enable-stackdriver-kubernetes --enable-ip-alias --network "projects/automatize-added-account-token/global/networks/default" --subnetwork "projects/automatize-added-account-token/regions/europe-west4/subnetworks/default" --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing --no-enable-autoupgrade --no-enable-autorepair

# cluster normal
gcloud beta container --project "automatize-added-account-token" clusters create "cluster-2" --zone "europe-west4-a" --no-enable-basic-auth --cluster-version "1.14.10-gke.27" --machine-type "e2-small" --image-type "COS" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "3" --enable-stackdriver-kubernetes --enable-ip-alias --network "projects/automatize-added-account-token/global/networks/default" --subnetwork "projects/automatize-added-account-token/regions/europe-west4/subnetworks/default" --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing --enable-autoupgrade --enable-autorepair

# delete cluster 
gcloud container clusters delete <clustername> --quiet

# delete all kubernetes jobs
kubectl delete jobs `kubectl get jobs -o custom-columns=:.metadata.name`

# delete nfs storage
kubectl delete persistentvolumeclaim nfs

# cp from nfs to local host
kubectl cp -c nfs-server nfs-server-58ddd75874-4zrrq:exports/file_sizes.log file_sizes.log

# delete pods stuck at terminating indefinitely 
kubectl delete pod hyperflow-engine-77db7d666f-nmgjq -n default --force --grace-period=0

# condition waiting
kubectl wait --for=condition=Ready --selector=name=demo-deployment-hyperflow pod