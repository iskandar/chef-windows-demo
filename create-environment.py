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
export NODE_CALLBACK_URL="http://jenkins.server/buildByToken/buildWithParameters?job=chef-windows-demo/chef-bootstrap&token=1234123123&NODE_IP=\$PublicIp&NODE_NAME=\$Hostname"
export NODE_PASSWORD=iojl3458lkjalsdfkj
'''

# Consume our environment vars
app_name = os.environ.get('NAMESPACE', 'win')
environment_name = os.environ.get('ENVIRONMENT', 'stg')
initial_policy = os.environ.get('INITIAL_POLICY', 'Set to 2')
node_username = os.environ.get('NODE_USERNAME', 'localadmin')
node_password = os.environ.get('NODE_PASSWORD', 'Q1w2e3r4')
image_id = os.environ.get('NODE_IMAGE_ID', "a35e8afc-cae9-4e38-8441-2cd465f79f7b")
flavor_id = os.environ.get('NODE_FLAVOR_ID', "general1-2")

# Set up a callback URL that our node will request after booting up. This can be used to trigger bootstrapping.
# $PublicIp and $Hostname vars are populated in the Powershell 'run.txt' script.
default_node_callback_url = "http://requestb.in/18vsdkl1?NODE_IP=$PublicIp&NODE_NAME=$Hostname"
node_callback_url = os.environ.get('NODE_CALLBACK_URL', default_node_callback_url)

# Parse the callback URL and add new vars
url_parts = urlparse.urlparse(node_callback_url)

query_vars = urlparse.parse_qsl(url_parts.query)
query_vars.append(['NAMESPACE', app_name])
query_vars.append(['ENVIRONMENT', environment_name])
query_vars.append(['INITIAL_POLICY', initial_policy])
query_vars.append(['NODE_IMAGE_ID', image_id])
query_vars.append(['NODE_FLAVOR_ID', flavor_id])
query_vars.append(['NODE_USERNAME', node_username])

node_callback_url = urlparse.urlunparse([
    url_parts.scheme,
    url_parts.netloc,
    url_parts.path,
    url_parts.params,
    urllib.urlencode(query_vars).replace('%24', '$').replace('%2F', '/'),
    None
])

# Authenticate
pyrax.set_setting("identity_type", "rackspace")
pyrax.set_setting("region", os.environ.get('OS_REGION', "LON"))
pyrax.set_credentials(os.environ.get('OS_USERNAME'), os.environ.get('OS_API_KEY'))

# Set up some aliases
cs = pyrax.cloudservers
cnw = pyrax.cloud_networks
clb = pyrax.cloud_loadbalancers
au = pyrax.autoscale

# Derived names
asg_name = app_name + "-" + environment_name
lb_name = asg_name + '-lb'
node_name = asg_name

# Other params
wait = True
wait_timeout = 1800

# Prepare data for server 'personalities', which is the only way to inject files and bootstrap Windows Servers
# in the Rackspace Public Cloud (as of 2016-03)
personalities = [
    {"source" : "./bootstrap/personality/bootstrap.cmd", "destination": "C:\\cloud-automation\\bootstrap.cmd"},
    {"source" : "./bootstrap/personality/run.txt", "destination": "C:\\cloud-automation\\run.txt"},
]

# Use templating with our personality files
template_vars = {
    "rackspace_username": os.environ.get('OS_USERNAME'),
    "app_name": app_name,
    "environment_name": environment_name,
    "asg_name": asg_name,
    "lb_name": lb_name,
    "node_base_name": node_name,
    "node_username": node_username,
    "node_password": node_password,
    "node_callback_url": node_callback_url,
}
print("", file=sys.stderr)
print("--- Params", file=sys.stderr)
print(json.dumps(template_vars), file=sys.stderr)
print("---", file=sys.stderr)

# Build personality list with content
personality_list = []
for p in personalities:
    with open(p["source"], 'r') as content_file:
        content = content_file.read()
    template = Template(content)
    personality_list.append({
        "path": p["destination"],
        "contents": template.render(template_vars),
    })

print("", file=sys.stderr)
print("--- Personalities", file=sys.stderr)
print(json.dumps(personality_list), file=sys.stderr)
print("---", file=sys.stderr)

# Create a load balancer with a Health monitor
health_monitor = {
    "type": "HTTP",
    "delay": 10,
    "timeout": 5,
    "attemptsBeforeDeactivation": 2,
    "path": "/",
    "statusRegex": "^[23][0-9][0-9]$", # We do NOT want to match 4xx responses
    "bodyRegex": ".*CHEF_WINDOWS_DEMO_APP.*" # Parse for a specific string to avoid default IIS page false positives
}

lb = clb.create(lb_name, port=80, protocol="HTTP",
                nodes=[], virtual_ips=[clb.VirtualIP(type="PUBLIC")],
                algorithm="ROUND_ROBIN", healthMonitor=health_monitor)

# Add Scaling Policies
policies = [
    { "name": "Up by 1", "change": 1, "desired_capacity": None, "is_percent": False },
    { "name": "Up by 50%", "change": 50, "desired_capacity": None, "is_percent": True },
    { "name": "Up by 100%", "change": 100, "desired_capacity": None, "is_percent": True },
    { "name": "Up by 200%", "change": 200, "desired_capacity": None, "is_percent": True },
    { "name": "Down by 1", "change": -1, "desired_capacity": None, "is_percent": False },
    { "name": "Down by 50%", "change": -50, "desired_capacity": None, "is_percent": True },
    { "name": "Set to 0", "change": None, "desired_capacity": 0, "is_percent": False },
    { "name": "Set to 1", "change": None, "desired_capacity": 1, "is_percent": False },
    { "name": "Set to 2", "change": None, "desired_capacity": 2, "is_percent": False },
    { "name": "Set to 4", "change": None, "desired_capacity": 4, "is_percent": False },
    { "name": "Set to 6", "change": None, "desired_capacity": 6, "is_percent": False },
    { "name": "Set to 8", "change": None, "desired_capacity": 8, "is_percent": False },
]
# print repr(policies)

metadata = {
    "environment": environment_name,
    "role": "web",
    "app": app_name,
}
sg = au.create(asg_name,
               cooldown=60,
               min_entities=0, max_entities=16,
               launch_config_type="launch_server",
               server_name=node_name,
               image=image_id,
               flavor=flavor_id,
               disk_config="MANUAL",
               metadata=metadata,
               personality=personality_list,
               networks=[{ "uuid": cnw.PUBLIC_NET_ID }, { "uuid": cnw.SERVICE_NET_ID }],
               load_balancers=(lb.id, 80))

for p in policies:
    policy = sg.add_policy(p["name"], 'webhook', 60, p["change"],
                           p["is_percent"], desired_capacity=p["desired_capacity"])
    webhook = policy.add_webhook(p["name"] + ' webhook')
    if p["name"] == initial_policy:
        print("Executing policy", policy.id)
        policy.execute()

'''
Try to update the LB error page with a friendlier version.
'''
error_page = '''
<html><head><meta http-equiv="Content-Type" content="text/html;charset=utf-8">
<title>No servers available yet</title>
<style type="text/css">
body, p, h1 {font-family: Verdana, Arial, Helvetica, sans-serif;}
h2 {font-family: Arial, Helvetica;}
</style>
</head><body>
<h2>No servers available yet</h2>
<p>Hang in there! Servers are doing stuff right behind the scenes right now.</p>
</body></html>
'''
# @FIXME This is timing-based - it should wait for the LB to come out of the 'immutable' state!
# lb.set_error_page(error_page)
# lb_state = lb.get_state()
# print(repr(lb_state))

if wait:
    end_time = time.time() + wait_timeout
    infinite = wait_timeout == 0
    while infinite or time.time() < end_time:
        state = sg.get_state()
        print("Scaling Group State: ", json.dumps(state), file=sys.stderr)

        if state["pending_capacity"] == 0:
            if state["active_capacity"] == 0:
                print("ASG pending_capacity went to zero, but no active nodes! Something has gone wrong")
                sys.exit(1)
            break
        time.sleep(10)

print(json.dumps({
    "id": sg.id,
    "name": asg_name,
    "metadata": metadata,
}))