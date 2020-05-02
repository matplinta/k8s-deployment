#!/bin/bash

output="$(kubectl get pods 2>&1)" 
echo $output
if [[ $output = *No?resources* ]] ; then 
# if [[ $output =~ .*resources.* ]] ; then 
    exit 0
else 
    exit 1
fi