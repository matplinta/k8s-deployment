#!/bin/bash

./run-workflow.sh -p gcloud -n cluster-c2 -P hyperflow-268022 -R europe-west2-a -g
# ./run-workflow.sh -p aws -n cluster-x -R eu-central-1 -g

for i in {1..10}; do
    for workflow in montage2-workflow-data:degree2.0 soykb-workflow-data:size4 soykb-workflow-data:size8 soykb-workflow-data:size16 soykb-workflow-data:size32 soykb-workflow-data:size48; do
        ./cluster-k8s-check.sh || ./run-workflow.sh -p gcloud -o
        ./run-workflow.sh -p gcloud -n cluster-c2 -P hyperflow-268022 -R europe-west2-a -r $workflow
    done
done

./run-workflow.sh -p gcloud -n cluster-c2 -P hyperflow-268022 -R europe-west2-a -d


# soykb-workflow-data:size2 soykb-workflow-data:size4 soykb-workflow-data:size8 soykb-workflow-data:size16 soykb-workflow-data:size32 soykb-workflow-data:size48 montage-workflow-data:degree0.25 montage-workflow-data:degree1.0 montage-workflow-data:degree2.0 montage2-workflow-data:degree0.01 montage2-workflow-data:degree0.25 montage2-workflow-data:degree1.0 montage2-workflow-data:degree2.0

# soykb-workflow-data:size2
# soykb-workflow-data:size4
# soykb-workflow-data:size8
# soykb-workflow-data:size16
# soykb-workflow-data:size32
# soykb-workflow-data:size48
# montage-workflow-data:degree0.25
# montage-workflow-data:degree1.0
# montage-workflow-data:degree2.0
# montage2-workflow-data:degree0.01
# montage2-workflow-data:degree0.25
# montage2-workflow-data:degree1.0
# montage2-workflow-data:degree2.0