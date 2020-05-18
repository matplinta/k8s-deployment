#!/bin/bash

docker run -it \
    -v $(pwd):/tmp/certs \
    -v $(pwd)/logs:/logs \
    matplinta/k8s-runner:latest \
    ./run-workflow.sh -p gcloud -n cluster-x -r montage-workflow-data:degree0.25
    