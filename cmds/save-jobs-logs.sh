#!/bin/bash

for job in `kubectl get pods | grep job | awk '{ print $1 }'`; do  kubectl logs $job; done | tee jobs.log