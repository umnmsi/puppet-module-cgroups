# == Class: cgroups
#
# Manage cgroups configuration service and files.
#
class cgroups (
  $config_file_path = '/etc/cgconfig.conf',
  $service_name     = 'cgconfig',
  $package_name     = undef,
  $cgconfig_content = undef,
  $user_path_fix    = undef,
  $mounts           = {},
  $groups           = {},
) {

  # variables preparation
  case $::osfamily {
    'RedHat': {
      case $::operatingsystemmajrelease {
        '6','7','8': {
          $package_name_default = 'libcgroup'
        }
        default: {
          fail('cgroups is only supported on EL 6 and 7.')
        }
      }
    }
    'Suse': {
      case $::operatingsystemrelease {
        /11\.[2-9]/: {
          $package_name_default = 'libcgroup1'
        }
        default: {
          fail('cgroups is only supported on Suse 11 with SP2 and up.')
        }
      }
    }
    default: {
      fail('cgroups is not supported on this platform.')
    }
  }

  $package_name_real = $package_name ? {
    undef   => $package_name_default,
    default => $package_name,
  }

  # variables validation
  validate_absolute_path($config_file_path)

  if is_string($service_name) == false {
    fail('cgroups::service_name is not a string.')
  }

  if is_string($package_name_real) == false and is_array($package_name_real) == false {
    fail('cgroups::package_name is not a string or an array.')
  }

  if is_string($cgconfig_content) == false {
    fail('cgroups::cgconfig_content is not a string.')
  }

  if $user_path_fix != undef {
    validate_absolute_path($user_path_fix)
  }

  validate_hash($mounts)
  validate_hash($groups)

  # functionality
  package { $package_name_real:
    ensure => present,
  }

  file { $config_file_path:
    ensure  => file,
    notify  => Service[$service_name],
    content => template('cgroups/cgroup.conf.erb'),
    require => Package[$package_name_real],
  }

  service { $service_name:
    ensure  => running,
    enable  => true,
    require => Package[$package_name_real],
  }

  create_resources('cgroups::group', $groups)

  if ($user_path_fix != undef) and ($::osfamily == 'Suse') {
    file { 'cgroups_path_fix':
      ensure  => directory,
      path    => $user_path_fix,
      mode    => '0775',
      require => Service[$service_name],
    }
  }
}
