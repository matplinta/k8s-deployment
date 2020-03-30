#!/bin/bash
kubectl apply -f crb.yml
kubectl apply -f cm.yml
kubectl apply -f nfs-server-service.yml
kubectl apply -f redis-service.yml
kubectl apply -f redis.yml
kubectl apply -f nfs-server.yml
sed -i -E "s/server:.*/server: `kubectl get services | grep nfs-server | awk '{ print $3 }'`/" pv-pvc.yml
kubectl apply -f pv-pvc.yml
kubectl apply -f hyperflow-engine-deployment.yml
kubectl apply -f parser-job.yml