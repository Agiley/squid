#
# Author:: Matt Ray <matt@chef.io>
# Author:: Sean OMeara <someara@chef.io>
# Cookbook Name:: squid
# Recipe:: default
#
# Copyright 2013-2014, Chef Software, Inc
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# variables
ipaddress = node['squid']['ipaddress']
listen_interface = node['squid']['listen_interface']
version = node['squid']['version']
netmask = node['network']['interfaces'][listen_interface]['addresses'][ipaddress]['netmask'] rescue nil #Throws undefined method `[]' for nil:NilClass

# squid/libraries/default.rb
acls = squid_load_acls(node['squid']['acls_databag_name'])
host_acl = squid_load_host_acl(node['squid']['hosts_databag_name'])
url_acl = squid_load_url_acl(node['squid']['urls_databag_name'])

# Log variables to Chef::Log::debug()
Chef::Log.debug("Squid listen_interface: #{listen_interface}")
Chef::Log.debug("Squid ipaddress: #{ipaddress}")
Chef::Log.debug("Squid netmask: #{netmask}")
Chef::Log.debug("Squid version: #{version}")
Chef::Log.debug("Squid host_acls: #{host_acl}")
Chef::Log.debug("Squid url_acls: #{url_acl}")
Chef::Log.debug("Squid acls: #{acls}")

# packages
package node['squid']['package']

# rhel_family sysconfig
template '/etc/sysconfig/squid' do
  source 'redhat/sysconfig/squid.erb'
  notifies :restart, "service[squid]", :delayed
  mode 00644
  only_if { platform_family? 'rhel', 'fedora' }
end

# squid config dir
directory node['squid']['config_dir'] do
  action :create
  recursive true
  owner 'root'
  mode 00755
end

# squid mime config
cookbook_file "#{node['squid']['config_dir']}/mime.conf" do
  source 'mime.conf'
  mode 00644
end

# TODO:  COOK-3041 (manage this file appropriately)
file "#{node['squid']['config_dir']}/msntauth.conf" do
  action :delete
end

# squid config
template node['squid']['config_file'] do
  source 'squid.conf.erb'
  notifies :reload, "service[squid]"
  mode 00644
  variables(
    :host_acl => host_acl,
    :url_acl => url_acl,
    :acls => acls,
    :directives => node['squid']['directives']
    )
end

template "/etc/systemd/system/squid.service" do
  source 'systemd/squid.service.erb'
  owner 'root'
  group 'root'
  mode 00644
  notifies :run, 'execute[systemctl daemon-reload]', :immediately
  only_if { platform?('ubuntu') && Chef::VersionConstraint.new('>= 15.04').include?(node['platform_version']) }
end

execute 'systemctl daemon-reload' do
  action :nothing
end

# services
service 'squid' do
  service_name node['squid']['service_name']
  provider squid_find_provider
  supports :restart => true, :status => true, :reload => true
  action [:enable, :start]
end
