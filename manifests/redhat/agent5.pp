# Class: datadog_agent::redhat
#
# This class contains the DataDog agent installation mechanism for Red Hat derivatives
#
# Parameters:
#   $baseurl:
#       Baseurl for the datadog yum repo
#       Defaults to http://yum.datadoghq.com/rpm/${::architecture}/
#
# Actions:
#
# Requires:
#
# Sample Usage:
#
#
class datadog_agent::redhat::agent5(
  String $baseurl = $datadog_agent::params::agent5_default_repo,
  String $gpgkey = 'https://yum.datadoghq.com/DATADOG_RPM_KEY_E09422B3.public',
  Boolean $manage_repo = true,
  String $agent_version = 'latest',
  String $service_ensure = 'running',
  Boolean $service_enable = true,
) inherits datadog_agent::params {

  validate_legacy('Boolean', 'validate_bool', $manage_repo)
  validate_legacy('Boolean', 'validate_bool', $service_enable)
  if $manage_repo {
    $public_key_local = '/etc/pki/rpm-gpg/DATADOG_RPM_KEY.public'

    validate_legacy('String', 'validate_string', $baseurl)

    file { 'DATADOG_RPM_KEY.public':
        owner  => root,
        group  => root,
        mode   => '0600',
        path   => $public_key_local,
        source => $gpgkey
    }

    exec { 'install-gpg-key':
        command => "/bin/rpm --import ${public_key_local}",
        onlyif  => "/usr/bin/gpg --quiet --with-fingerprint -n ${public_key_local} | grep \'A4C0 B90D 7443 CF6E 4E8A  A341 F106 8E14 E094 22B3\'",
        unless  => '/bin/rpm -q gpg-pubkey-e09422b3',
        require => File['DATADOG_RPM_KEY.public'],
    }

    if ($facts['yum_agent6_repo'] or $facts['yum_datadog_legacy_repo']) and $agent_version == 'latest' {
      exec { 'datadog_yum_remove_agent6':
        command     => '/usr/bin/yum -y -q remove datadog-agent',
      }
    } else {
      exec { 'datadog_yum_remove_agent6':
        command     => ':',  # NOOP builtin
        noop        => true,
        refreshonly => true,
        provider    => 'shell',
      }
    }

    yumrepo {'datadog':
      ensure => absent,
      notify => Exec['datadog_yum_remove_agent6'],
    }

    yumrepo {'datadog6':
      ensure => absent,
      notify => Exec['datadog_yum_remove_agent6'],
    }

    yumrepo {'datadog5':
      enabled  => 1,
      gpgcheck => 1,
      gpgkey   => 'https://yum.datadoghq.com/DATADOG_RPM_KEY.public',
      descr    => 'Datadog, Inc.',
      baseurl  => $baseurl,
      require  => Exec['install-gpg-key'],
    }

    Package { require => Yumrepo['datadog5']}
  }

  package { 'datadog-agent-base':
    ensure => absent,
    before => Package[$datadog_agent::params::package_name],
  }

  package { $datadog_agent::params::package_name:
    ensure  => $agent_version,
  }

  service { $datadog_agent::params::service_name:
    ensure    => $service_ensure,
    enable    => $service_enable,
    hasstatus => false,
    pattern   => 'dd-agent',
    require   => Package[$datadog_agent::params::package_name],
  }

}
