#/bin/bash
if [ $# -eq 0 ]; then
    echo "No arguments provided"
    exit 1
fi
gcloud beta container --project "automatize-added-account-token" clusters create "$1" --zone "europe-west4-a" --no-enable-basic-auth --cluster-version "1.14.10-gke.27" --machine-type "e2-small" --image-type "COS" --disk-type "pd-standard" --disk-size "100" --metadata disable-legacy-endpoints=true --scopes "https://www.googleapis.com/auth/devstorage.read_only","https://www.googleapis.com/auth/logging.write","https://www.googleapis.com/auth/monitoring","https://www.googleapis.com/auth/servicecontrol","https://www.googleapis.com/auth/service.management.readonly","https://www.googleapis.com/auth/trace.append" --num-nodes "$2" --enable-stackdriver-kubernetes --enable-ip-alias --network "projects/automatize-added-account-token/global/networks/default" --subnetwork "projects/automatize-added-account-token/regions/europe-west4/subnetworks/default" --default-max-pods-per-node "110" --no-enable-master-authorized-networks --addons HorizontalPodAutoscaling,HttpLoadBalancing --enable-autoupgrade --enable-autorepair

