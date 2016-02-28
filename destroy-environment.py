#!/usr/bin/env python
from __future__ import print_function
import pyrax
import os
import time
import json
import sys
from jinja2 import Template
import urlparse
import urllib

'''
Example Env vars:

export OS_USERNAME=YOUR_USERNAME
export OS_REGION=LON
export OS_API_KEY=fc8234234205234242ad8f4723426cfe
'''

# Consume our environment vars
app_name = os.environ.get('NAMESPACE', 'win')
environment_name = os.environ.get('ENVIRONMENT', 'stg')

# Authenticate
pyrax.set_setting("identity_type", "rackspace")
pyrax.set_setting("region", os.environ.get('OS_REGION', "LON"))
pyrax.set_credentials(os.environ.get('OS_USERNAME'), os.environ.get('OS_API_KEY'))

# Set up some aliases
clb = pyrax.cloud_loadbalancers
au = pyrax.autoscale

# Derived names
asg_name = app_name + "-" + environment_name
lb_name = asg_name + '-lb'

# Other params
wait = True
wait_timeout = 1800

# Try to find the ASG by naming convention.
# This is brittle and we should be rummaging in the launch_configuration metadata
filtered = (node for node in au.list() if
            node.name == asg_name)

sg = None
for sg in filtered:
    break

if sg is not None:
    print("Deleting ASG", sg.name)
    sg.update(min_entities=0, max_entities=0)
    sg.delete()

# Find the LB by naming convention
filtered = (node for node in clb.list() if
            node.name == lb_name)

lb = None
for lb in filtered:
    break

if lb is not None:
    print("Deleting LB", lb.name)
    lb.delete()

# lb = clb.create(lb_name, port=80, protocol="HTTP",
#                 nodes=[], virtual_ips=[clb.VirtualIP(type="PUBLIC")],
#                 algorithm="ROUND_ROBIN", healthMonitor=health_monitor)
#
#
# if wait:
#     end_time = time.time() + wait_timeout
#     infinite = wait_timeout == 0
#     while infinite or time.time() < end_time:
#         state = sg.get_state()
#         print("Scaling Group State: ", json.dumps(state), file=sys.stderr)
#
#         if state["pending_capacity"] == 0:
#             break
#         time.sleep(10)
#
# print(json.dumps({
#     "id": sg.id,
#     "name": asg_name,
#     "metadata": metadata,
# }))