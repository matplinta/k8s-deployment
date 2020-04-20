#!/bin/bash

kubectl cp -c nfs-server $(kubectl get pods --selector=role=nfs-server --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'):exports/logs-hf/ $1