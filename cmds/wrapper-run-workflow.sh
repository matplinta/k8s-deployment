#!/bin/bash

# for workflow in montage0.25 montage1.0 montage2.0 ; do

# soykb-workflow-data:size2
# soykb-workflow-data:size4
# soykb-workflow-data:size8
# soykb-workflow-data:size16
# soykb-workflow-data:size32
# soykb-workflow-data:size48
# montage-workflow-data:montage0.25
# montage-workflow-data:montage1.0
# montage-workflow-data:montage2.0
# montage2-workflow-data:degree0.01
# montage2-workflow-data:degree0.25
# montage2-workflow-data:degree1.0
# montage2-workflow-data:degree2.0




for workflow in soykb-workflow-data:size2 soykb-workflow-data:size4 soykb-workflow-data:size8 soykb-workflow-data:size16 soykb-workflow-data:size32 soykb-workflow-data:size48 montage-workflow-data:montage0.25 montage-workflow-data:montage1.0 montage-workflow-data:montage2.0 montage2-workflow-data:degree0.01 montage2-workflow-data:degree0.25 montage2-workflow-data:degree1.0 montage2-workflow-data:degree2.0; do
    for i in {1..1}; do
        ./cluster-k8s-check.sh || ./run-workflow.sh -o
        ./run-workflow.sh -p gcloud -n cluster-x -r $workflow
    done
done

./run-workflow.sh -p gcloud -d