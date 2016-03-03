#
# Cookbook Name:: chef-windows-demo
# Recipe:: default
#
#

# Stop the default site
iis_site 'Default Web Site' do
  action [:stop]
end

# Set up logging
directory "C:\\logs" do
  action :create
end
iis_config "/section:system.applicationHost/sites /siteDefaults.logfile.directory:\"C:\\logs\"" do
  action :set
end

# Write to a file
file "C:\\logs\\test.txt" do
  content 'Here is some test text'
end

# Add a registry key
registry_key 'HKEY_LOCAL_MACHINE\SOFTWARE\CHEF_WINDOWS_DEMO' do
  values [{
              :name => 'HELLO',
              :type => :expand_string,
              :data => 'OMG WTF BBQ'
          }]
  action :delete
end

# Create a new directory.
# We want this to be empty so our Load Balancer does not add this node into rotation.
directory "#{node['iis']['docroot']}/WebApplication1" do
  action :create
end

# Create a new IIS Pool
iis_pool 'WebApplication1' do
  runtime_version "4.0"
  pipeline_mode :Integrated
  pool_identity :ApplicationPoolIdentity
  start_mode :AlwaysRunning
  auto_start true
  load_user_profile true
  action :add
end

# Create a new IIS site
iis_site 'WebApplication1' do
  protocol :http
  port 80
  path "#{node['iis']['docroot']}/WebApplication1"
  application_pool 'WebApplication1'
  action [:add,:start]
end

service 'w3svc' do
  action [:enable, :start]
end

include_recipe 'webpi'

webpi_product 'WDeployPS' do
  accept_eula true
  action :install
end

# octopus_deploy_tentacle 'Tentacle' do
#   action [:install, :configure]
#   version '3.2.24'
#   trusted_cert "#{node['octopus']['tentacle']['instance']['trusted_cert']}"
# end
