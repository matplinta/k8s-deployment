#!/bin/bash

while true
do
    echo "Start deleting..."
    for job in $(kubectl get job -o=jsonpath='{.items[?(@.status.succeeded==1)].metadata.name}'); do
        if ! [[ "$job" =~ "logs-parser" ]]
        then
            kubectl delete job $job
        fi
    done
done
