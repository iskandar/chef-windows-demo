#
# Cookbook Name:: chef-windows-demo
# Recipe:: default
#
#

# Stop the default site
iis_site 'Default Web Site' do
  action [:stop]
end

# Create a new directory.
# We want this to be empty so our Load Balancer does not add this node into rotation.
directory "#{node['iis']['docroot']}/WebApplication1" do
  action :create
end

# Sets up logging
iis_config "/section:system.applicationHost/sites /siteDefaults.logfile.directory:\"D:\\logs\"" do
  action :set
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
