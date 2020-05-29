#!/bin/bash
while true
do
    echo top cluster: 
    for node in $(kubectl get nodes | grep cluster | cut -d' ' -f1); do
        kubectl top node $node | grep -v NAME
    done
done