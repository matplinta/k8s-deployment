#!/usr/bin/env python3

import yaml, sys
# usage: <deployment yaml file to change> <full container path> 

if len(sys.argv) != 4:
    print("usage: <deployment yaml file to change> <HF_VARIABLE> <value>\
           if value=\"del\", the variable is deleted from deployment.")
    sys.exit(1)
    
# VARS
# HF_VAR_CPU_REQUEST 0.5
# HF_VAR_MEM_REQUEST 50Mi

FILE     = sys.argv[1]
VARIABLE = sys.argv[2]
VALUE    = sys.argv[3]

    
with open(FILE) as f:
     yaml_instance = yaml.load(f, Loader=yaml.FullLoader)
index = None
for idx, elem in enumerate(yaml_instance['spec']['template']['spec']['containers'][0]['env']):
    if elem['name'] == VARIABLE:
        index = idx
if VALUE == 'del':
    if index:
        yaml_instance['spec']['template']['spec']['containers'][0]['env'].pop(index)
    else:
        sys.exit(0)
elif index:
    yaml_instance['spec']['template']['spec']['containers'][0]['env'][index]['value'] = VALUE
else: 
    yaml_instance['spec']['template']['spec']['containers'][0]['env'].append({'name': VARIABLE, 'value':VALUE})
    
with open(FILE, "w") as f:
    yaml.dump(yaml_instance, f)
