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
# == Class: simplesamlphp
#
# This class installs SimpleSAMLphp as an IDP or SP
#
# Actions:
#   - Install SimpleSAMLphp, install dependent libraries and activate required modules
#
# Requires:
#
# puppet-apache
# git@github.com:jippi/puppet-php.git
# puppetlabs-vcsrepo
# git@github.com:puppetlabs/puppetlabs-stdlib.git
#
#
# === Where is the data and config
#
# SimpleSAMLphp is a real pain to manage configuration wise - it's own configuration
# and customisable components are spread across multiple places.
# modules are typically switched on with 'touch modules/statistics/default-enable'
# and often have a compainion configuration file 'config/module_statistics.php'.
#
# The application itself, is stored in the Catalyst git repository, and there is
# frequently a specific branch required per instance to cater for instance specific
# themes and custom module development.
#
# Core configuration is held in config/config.hp and the primary SAML metadata
# configuration is in config/authsources.php.
# secondary and tertiary metadata are in metadata/saml20-* and metadata/<XML file locations>.
#
# On top of this, the core X509 certificate data that might accompany SAML
# metadata is in cert/.
#
# There are also temporary data/file storage locations that are either in tmp/ or data/
#
# This all, makes things rather challenging from the point of view of organising
# customisation of an install.
# There private key certificate data, and passwords need to be securely managed,
# and there is a need to have defaults for every install, and instance (fqdn) specific
# config.  This applies to both config elements, configuration files, metadata and certificates.
#
# To try and make some sense of this and to keep configuration flexible, the various
# elements are handled like this:
#  - tmp/ and data/ - default directories and contents are supplied from
#    module files - puppet:///modules/simplesamlphp/*
#
#  - public certificates required by and instance are sourced from instance specific
#    puppet files directories - puppet:///files/${::fqdn}/simplesamlphp/cert/
#
#  - private keys for the SSL cert for Apache and the SAML server cert are expected to
#    be handled separately with eyaml.  This is handled in profiles::simplesamlphp
#
#  - Configuration files:
#    config/config.php
#    config/authsources.php
#    config/config-metarefresh.php
#    metadata/saml20-idp-hosted.php
#    metadata/saml20-idp-remote.php
#    metadata/saml20-sp-remote.php
#    are handled through inline erb templates held in the instance specific yaml config.
#    This enables complete flexbility while also enabling the use of eyaml for passwords, salts etc.
#
#
# === Parameters
#
# [fqdn]
#   The domain name that ssphp will be served from
#
# [clone_owner]
#   user name and group used for git clone - default: simplesamlphp
#
# [target]
#   target base directory where repository will be cloned into
#
# [clone_path]
#   git repository source - default: 'git://git.catalyst.net.nz/simplesamlphp.git'
#
# [repo_revision]
#   tag or branch that will be cloned - default: "simplesamlphp-1.12"
#
# [idp]
#   Is this an IdP? - default: 'false'
#
# [debug]
#   Activate ssphp debugging - default: 'false'
#
# [technicalcontact_email]
#   contact email address on errors
#
# [auth_adminpassword]
#   password for login to ssphp admin features
#
# [secretsalt]
#   salt for XML encryption
#
# [memcache_host]
#   memcache server eg: tcp://localhost:11211
#
# [proxy]
#   ssphp proxy for all backend calls such as aggregator eg: tcp://some.host:8123
#
# [ignore_ssl_errors]
#   Ignore SSL errors on file_get_contents (backend calls) - default: 'false'
#
# [ssl_cert]
#   SSL cert passed to apache
#
# [ssl_key]
#   SSL key passed to apache
#
# === Examples
#
# class { '::simplesamlphp':
#   fqdn                        => hiera('simplesamlphp::fqdn'),
#   clone_owner                 => $simplesamlphp_owner,
#   target                      => $simplesamlphp_target,
#   clone_path                  => hiera('simplesamlphp::simplesamlphp_clone_path'),
#   repo_revision               => hiera('simplesamlphp::repo_revision'),
#   idp                         => hiera('simplesamlphp::simplesamlphp_idp'),
#   debug                       => hiera('simplesamlphp::debug', 'false'),
#   technicalcontact_email      => hiera('simplesamlphp::technicalcontact_email'),
#   auth_adminpassword          => hiera('simplesamlphp::auth_adminpassword'),
#   secretsalt                  => hiera('simplesamlphp::secretsalt'),
#   memcache_host               => hiera('simplesamlphp::memcache_host'),
#   proxy                       => hiera('simplesamlphp::proxy', ''),
#   ignore_ssl_errors           => hiera('simplesamlphp::ignore_ssl_errors'),
#   ssl_cert                    => $ssl_cert,
#   ssl_key                     => $ssl_key,
#   server_private_key          => hiera('simplesamlphp::cert_server_key')
# }
#
# === Authors
#
# Piers Harding <piers@catalyst.net.nz>
#
#
class simplesamlphp ( $fqdn,
                      $clone_owner               = 'simplesamlphp',
                      $target                    = false,
                      $clone_path                = 'git://git.catalyst.net.nz/simplesamlphp.git',
                      $repo_revision             = 'simplesamlphp-1.12',
                      $idp                       = 'false',
                      $debug                     = 'false',
                      $technicalcontact_email    = 'false',
                      $auth_adminpassword        = false,
                      $secretsalt                = false,
                      $memcache_host             = false,
                      $proxy                     = undef,
                      $ignore_ssl_errors         = 'false',
                      $ssl_cert                  = false,
                      $ssl_key                   = false,
                      $server_private_key        = false) {

# git clone ssh+git://gitprivate.servers.catalyst.net.nz/git/private/simplesamlphp.git

     # Basic validation
    validate_string($fqdn)
    validate_string($target)
    validate_string($auth_adminpassword)
    validate_string($secretsalt)
    validate_array($memcache_host)
    validate_string($ssl_cert)
    validate_string($ssl_key)
    validate_string($server_private_key)

    # juggle the empty value for proxy
    if ($proxy == undef) {
      $backend_proxy = 'NULL'
    }
    else {
      $backend_proxy = "'${proxy}'"
    }

    ensure_packages([
      'git',
      'subversion',
    ])

    include apache
    include apache::mod::php
    include php
    include php::params
    include php::pear
    include php::composer
    include php::composer::auto_update

    class { ['php::dev', 'php::cli']:
    }->
    # PHP extensions
    class {
    [
      'php::extension::curl', 'php::extension::gd', 'php::extension::imagick',
      'php::extension::mcrypt', 'php::extension::mysql', 'php::extension::ldap',
      'php::extension::opcache', 'php::extension::memcache', 'php::extension::apc',
      'php::extension::sqlite'
    ]:
    }->
    php::extension{'gmp':
        ensure   => "latest",
        package  => "php5-gmp",
    }->
    php::apache::config { 'memory_limit=256M':
      }->


    vcsrepo { "${target}/idp":
      ensure   => 'latest',
      source   => $clone_path,
      revision => $repo_revision,
      provider => 'git',
      require  => [
                    Package['git'],
                    File["${target}"],
                    ],
      user     => $clone_owner,
    }

    # this is not automatically enabling on install
    exec { 'enable_mcrypt':
      command => '/usr/bin/sudo  php5enmod mcrypt',
      # path => "${target}/idp",
      require  => [
              Class['php::extension::mcrypt'],
            ],
    }

    exec { 'run_composer':
      command => "/usr/bin/sudo /usr/local/bin/composer --working-dir=${target}/idp update",
      # path => "${target}/idp",
      require  => [
              Exec['enable_mcrypt'],
              Vcsrepo["${target}/idp"],
              Class["php::cli"],
              Class["php::composer"],
            ],
    }


    file { "${target}/idp/config/":
        ensure       => directory,
        source       => "puppet:///files/${::fqdn}/simplesamlphp/config/",
        owner        => $clone_owner,
        group        => $clone_owner,
        sourceselect => all,
        recurse      => true,
        require      => [
              Vcsrepo["${target}/idp"],
            ],
    }

    file { "${target}/idp/cert/":
        ensure       => directory,
        source       => "puppet:///files/${::fqdn}/simplesamlphp/cert/",
        owner        => $clone_owner,
        group        => $clone_owner,
        sourceselect => all,
        recurse      => true,
        require      => [
              Vcsrepo["${target}/idp"],
            ],
    }

  # configure the syslog for SimpleSAMLphp stats
  include rsyslog

  file { "/etc/rsyslog.d/60-simplesamlphp.conf":
      ensure       => present,
      source       => "puppet:///modules/simplesamlphp/etc/rsyslog.d/60-simplesamlphp.conf",
      require      => [
            Vcsrepo["${target}/idp"],
          ],
      notify  => Service["rsyslog"],
  }

  # Install the private key for the ssphp server
  file { "${target}/idp/cert/server.key":
    ensure => file,
    owner => $clone_owner,
    group => $clone_owner,
    mode => '0444',
    content => $server_private_key,
    require  => [
      File["${target}/idp/cert/"],
    ],
  }

  file { "${target}/idp/metadata/":
      ensure       => directory,
      source       => "puppet:///files/${::fqdn}/simplesamlphp/metadata/",
      owner        => 'www-data',
      group        => 'www-data',
      sourceselect => all,
      recurse      => true,
      require      => [
            Vcsrepo["${target}/idp"],
          ],
  }


  file { "${target}/idp/data/":
      ensure       => directory,
      source       => "puppet:///modules/simplesamlphp/data/",
      owner        => 'www-data',
      group        => 'www-data',
      sourceselect => all,
      recurse      => true,
      require      => [
            Vcsrepo["${target}/idp"],
          ],
  }

  file { "${target}/idp/tmp/":
      ensure       => directory,
      source       => "puppet:///modules/simplesamlphp/tmp/",
      owner        => 'www-data',
      group        => 'www-data',
      sourceselect => all,
      recurse      => true,
      require      => [
            Vcsrepo["${target}/idp"],
          ],
  }

  $config_config = hiera('simplesamlphp::config_config_php_template')

  file { "${target}/idp/config/config.php":
    content => inline_template($config_config),
    owner   => $clone_owner,
    group   => $clone_owner,
    mode    => '0644',
    require      => [
      File["${target}/idp/config/"],
    ],
  }

  $config_authsource = hiera('simplesamlphp::config_authsource_php_template')

  file { "${target}/idp/config/authsources.php":
    content => inline_template($config_authsource),
    owner   => $clone_owner,
    group   => $clone_owner,
    mode    => '0644',
    require      => [
      File["${target}/idp/config/"],
    ],
  }

  # this module has a non-standard config file name so we do it here
  $config_config_metarefresh = hiera('simplesamlphp::config_config_metarefresh_php_template')

  file { "${target}/idp/config/config-metarefresh.php":
    content => inline_template($config_config_metarefresh),
    owner   => $clone_owner,
    group   => $clone_owner,
    mode    => '0644',
    require      => [
      File["${target}/idp/config/"],
    ],
  }

  $metadata_saml20_idp_hosted = hiera('simplesamlphp::metadata_saml20_idp_hosted_php_template')

  file { "${target}/idp/metadata/saml20-idp-hosted.php":
    # notify  => Service['php5-fpm'],
    content => inline_template($metadata_saml20_idp_hosted),
    owner   => $clone_owner,
    group   => $clone_owner,
    mode    => '0644',
    require      => [
      File["${target}/idp/config/"],
    ],
  }

  $metadata_saml20_idp_remote = hiera('simplesamlphp::metadata_saml20_idp_remote_php_template')

  file { "${target}/idp/metadata/saml20-idp-remote.php":
    # notify  => Service['php5-fpm'],
    content => inline_template($metadata_saml20_idp_remote),
    owner   => $clone_owner,
    group   => $clone_owner,
    mode    => '0644',
    require      => [
      File["${target}/idp/config/"],
    ],
  }

  $metadata_saml20_sp_remote = hiera('simplesamlphp::metadata_saml20_sp_remote_php_template')

  file { "${target}/idp/metadata/saml20-sp-remote.php":
    # notify  => Service['php5-fpm'],
    content => inline_template($metadata_saml20_sp_remote),
    owner   => $clone_owner,
    group   => $clone_owner,
    mode    => '0644',
    require      => [
      File["${target}/idp/config/"],
    ],
  }


  apache::vhost { "${::fqdn}":
    port    => '443',
    docroot => '/var/www',
    ssl     => true,
    ssl_cert => $ssl_cert,
    ssl_key => $ssl_key,
    aliases => [
      { alias      => '/simplesaml',
        path       => "${target}/idp/www",
      },
    ],
  }

  host { 'localhost':
    ensure => 'present',
    target => '/etc/hosts',
    ip => '127.0.0.1',
    host_aliases => ['localhost.localdomain', "${::fqdn}"]
  }

  $cron_passwd = hiera('simplesamlphp::cron_passwd')

  cron { 'simplesamlphp_daily':
    command => "curl -k --silent 'https://${::fqdn}/simplesaml/module.php/cron/cron.php?key=${cron_passwd}&tag=daily' > /dev/null 2>&1",
    user    => root,
    hour    => 18,
    minute  => 0,
    require      => [
      Apache::Vhost["${::fqdn}"],
    ],
  }
}
