#!/usr/bin/env python3

import yaml, sys
# usage: <deployment yaml file to change> <full container path> 

if len(sys.argv) != 3:
    print("usage: <deployment yaml file to change> <memory value>")
    sys.exit(1)

FILE = sys.argv[1]
MEM = sys.argv[2]

    
with open(FILE) as f:
     yaml_instance = yaml.load(f, Loader=yaml.FullLoader)
index = None
for idx, elem in enumerate(yaml_instance['spec']['template']['spec']['containers'][0]['env']):
    if elem['name'] == 'HF_VAR_MEM_REQUEST':
        index = idx
if MEM == 'del':
    if index:
        yaml_instance['spec']['template']['spec']['containers'][0]['env'].pop(index)
    else:
        sys.exit(0)
elif index:
    yaml_instance['spec']['template']['spec']['containers'][0]['env'][index]['value'] = MEM
else: 
    yaml_instance['spec']['template']['spec']['containers'][0]['env'].append({'name': 'HF_VAR_MEM_REQUEST', 'value':MEM})
    
with open(FILE, "w") as f:
    yaml.dump(yaml_instance, f)
