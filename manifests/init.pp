# == Class: rstudio
#
# This class installs RStudio Server
#
# Actions:
#   - Install RStudio Server, install dependent libraries and CRAN packages
#
# Requires:
#
# puppet-r
#
# === Parameters
#
# [rstudio_pkg]
#   The name of the debian RStudio Server package file in the files directory
#
# [rstudio_user]
#   First UNIX user name for RStudio - default: rstudio
#
# [rstudio_pwd]
#   First UNIX user password - default: undef
#
# [time_zone]
#   Server timezone - default: 'Pacific/Auckland'
#
# [r_deb_repo]
#   Debian repository for R and prebuilt cran libs - default: "deb http://cran.stat.auckland.ac.nz/bin/linux/ubuntu trusty/"
#
# [cran_repo_key]
#   Debian repository key - default: undef
#
# [r_repo]
#   Default CRAN repository - default: "http://cran.stat.auckland.ac.nz/"
#
#
# === Examples
#
#  class { rstudio:
#              rstudio_pkg => 'rstudio-server-0.98.501-amd64.deb',
#              rstudio_user => 'rstudio',
#              rstudio_pwd => 'encoded password',
#              time_zone => 'Pacific/Auckland',
#              r_deb_repo => "deb http://cran.stat.auckland.ac.nz/bin/linux/ubuntu trusty/",
#              r_repo => "http://cran.stat.auckland.ac.nz/",
#              cran_repo_key => "the debian repo key"
#  }
#
# === Authors
#
# Piers Harding <piers@ompka.net>
#
# === Copyright
#
# Copyright 2014 Piers Harding.
#
#
class rstudio ($rstudio_pkg        = 'rstudio-server-0.98.501-amd64.deb',
               $rstudio_user       = 'rstudio',
               $rstudio_pwd        = undef,
               $time_zone          = 'Pacific/Auckland',
               $r_deb_repo         = "deb http://cran.stat.auckland.ac.nz/bin/linux/ubuntu trusty/",
               $r_repo             = "http://cran.stat.auckland.ac.nz/",
               $cran_repo_key      = undef) {

    $kpath = "/tmp/$rstudio_pkg"
    $rstudio_dependencies = [ "libapparmor1", "libssl0.9.8", "libcurl4-openssl-dev",
                              "postgresql-server-dev-all", "libmysqlclient-dev", "libgeos-dev" ]

    group { "$rstudio_user":
        ensure => "present"
    }

    user { "$rstudio_user":
        ensure => "present",
        password => "$rstudio_pwd",
        comment => "RStudio user created by puppet",
        managehome => true,
        shell   => "/bin/bash",
        gid => "$rstudio_user",
        require => [
          Group["$rstudio_user"]
        ]
    }

    file { "/etc/apt/sources.list.d/cran.list":
        content => "$r_deb_repo\n",
        owner   => root,
        group   => root,
        mode    => 0644,
        notify  => Exec["add_cran_key"]
    }

    # handle our specific source list
    exec { "add_cran_key":
        command => "apt-key adv --keyserver keyserver.ubuntu.com --recv-keys $cran_repo_key",
        path    => "/usr/local/bin/:/bin/:/usr/bin/",
        require => [
          File["/etc/apt/sources.list.d/cran.list"],
        ],
        unless => "/usr/bin/apt-key list | grep '$cran_repo_key' ",
        notify  => Exec["cran_apt_update"]
    }

    exec { "cran_apt_update":
        command => "/usr/bin/apt-get update && touch /tmp/cran_apt_update",
        refreshonly => true,
        require => [
          Exec["add_cran_key"],
        ],
        creates => "/tmp/cran_apt_update"
    }


    # install RStudio dependencies
    package { $rstudio_dependencies:
       ensure => present,
       require => [
          Exec["cran_apt_update"]
        ],
       notify  => Exec["install_rstudio"]
    }->

    # Install R and base set of packages
    class { 'r': }->
    r::package { 'devtools': repo => "$r_repo", dependencies => true }


    exec { "set_timezone":
        command => "/bin/echo '$time_zone' | sudo tee /etc/timezone && dpkg-reconfigure --frontend noninteractive tzdata",
        require => [
          Package["r-base"]
        ],
        unless => "/bin/grep '$time_zone' /etc/timezone",
       notify  => Exec["install_rstudio"]
    }

    # fix up the NZ locale
    exec { "gen_locale":
        command => "/usr/sbin/locale-gen en_NZ && /usr/sbin/locale-gen en_NZ.UTF-8 && /usr/sbin/dpkg-reconfigure locales",
        require => [
          Package["r-base"]
        ],
        unless => '/usr/bin/locale -a | grep en_NZ',
        notify  => Exec["install_rstudio"]
    }

    file { "$kpath":
        source => "puppet:///modules/rstudio/$rstudio_pkg",
        owner => root,
        notify  => Exec["install_rstudio"],
    }

    exec { "install_rstudio":
        command => "dpkg -i $kpath",
        path    => "/usr/local/bin/:/bin/:/usr/bin/:/sbin/",
        unless => '/usr/bin/dpkg -l rstudio-server',
        require => [
          Package["r-base", "libssl0.9.8", "libapparmor1"],
          Exec["gen_locale", "set_timezone"],
          File["$kpath"]
        ],
        notify  => File["/etc/rstudio/rserver.conf"]
    }

    file { "/etc/rstudio/rserver.conf":
        content => "www-address=127.0.0.1\nrsession-which-r=/usr/bin/R\nauth-required-user-group=rstudio\n#admin-enabled=1\n#admin-group=rstudio-admins\n#admin-superuser-group=rstudio-superuser-admins\n",
        owner   => root,
        group   => root,
        mode    => 0644,
        require => [
          Exec["install_rstudio"],
        ],
    }

    file { "/etc/rstudio/rsessions.conf":
        content => "session-timeout-minutes=0\nr-cran-repos=$r_repo\n",
        owner   => root,
        group   => root,
        mode    => 0644,
        require => [
          Exec["install_rstudio"],
        ],
    }
}
