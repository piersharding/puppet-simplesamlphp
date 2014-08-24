#
# Copyright (C) 2014 Catalyst IT Limited.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# Author: Piers Harding <piers@catalyst.net.nz>
#
# == Class: simplesamlphp::module
#
# Activate a SimpleSAMLphp module
#
# === Parameters
#
# [*ensure*]
#   The ensure the module is activated
#   Could be "enabled", or "disabled"
#
# === Variables
#
# [*simplesamlphp_ensure*]
#   The ensure of APC to install
#
# === Examples
#
# simplesamlphp::module { "aggregator": }
#
# templates can be held in hiera (e)yaml - a look up is done for a block value with the name
# simplesamlphp::config_module_<module name>_php_template
# substitute values into the template using %{hiera variable lookup} eg:
#    %{hiera('simplesamlphp::cron_passwd')}
#
# === Authors
#
# piers@catalyst.net.nz
#
define simplesamlphp::module(
  $ensure = 'enabled'
) {

  # default-enable file overides default-disable, so remove it if we want disabled
  if $ensure == 'enabled' {
    $present = 'present'
  }
  else {
    $present = 'absent'
  }

  file { "${::simplesamlphp::target}/idp/modules/${name}/default-enable":
    ensure => $present,
    content => '',
    owner   => $::simplesamlphp::clone_owner,
    group   => $::simplesamlphp::clone_owner,
    mode    => '0644',
    require      => [
      Class['::simplesamlphp'],
    ],
  }

  file { "${::simplesamlphp::target}/idp/modules/${name}/default-disable":
    # notify  => Service['php5-fpm'],
    content => '',
    ensure => "present",
    owner   => $::simplesamlphp::clone_owner,
    group   => $::simplesamlphp::clone_owner,
    mode    => '0644',
    require      => [
      Class['::simplesamlphp'],
    ],
  }

  # Is there a module specific hiera template?
  $config_module_module = hiera("simplesamlphp::config_module_${name}_php_template", "")

  if $config_module_module != "" {
    file { "${::simplesamlphp::target}/idp/config/module_${name}.php":
      content => inline_template($config_module_module),
      owner   => $::simplesamlphp::clone_owner,
      group   => $::simplesamlphp::clone_owner,
      mode    => '0644',
      require      => [
        File["${::simplesamlphp::target}/idp/config/"],
      ],
    }
  }
}
