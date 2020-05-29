#!/bin/bash

docker run -it \
    -v $(pwd):/tmp/certs \
    -v $(pwd)/logs:/logs \
    matplinta/k8s-runner:latest \
    bash
    # ./wrapper-run-workflow.sh
    # ./run-workflow.sh -p gcloud -n cluster-x -P hyperflow-268022 -R europe-west2-a -r montage-workflow-data:degree1.0
    