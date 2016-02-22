# Class: bareos::params::client
#
# This class installs a backup client, and exports a definition to be
# used by the backup server.
#
class bareos::params::client {
  case $::osfamily {
    'windows': {
      $_impl = 'bareos'
      $root_user = 'Administrator'
      $root_group = 'Administrators'
    }
    default: {
      $_impl = 'bacula'
      $root_user = 'root'
      $root_group = 'root'
    }
  }
  $implementation = hiera('bareos::client::implementation', $_impl)

  case $::osfamily {
    'windows': {
      $service = 'Bareos-fd'
      $log_dir = false
      # Notice the use of UNC to get an "absolute path", this enables
      # us to run regression tests for Windows code on a Unix system.
      $config_file = "//localhost/c$/ProgramData/Bareos/${implementation}-fd.conf"
    }
    default: {
      $service = "${implementation}-fd"
      $log_dir = "/var/log/${implementation}"
      $config_file = "/etc/${implementation}/${implementation}-fd.conf"
    }
  }

  $name_suffix    = '-fd'
  $job_suffix     = '-job'
  # don't worry about Linux specific names for now
  $fstype = [
    'rootfs', 'ext2', 'ext3', 'ext4', 'jfs', 'reiserfs', 'xfs',
  ]
  $backup_dir = '/var/backups'
  $backup_dir_owner = 'root'
  $backup_dir_group = 'root'
  $backup_dir_mode = '0755'

  case $::osfamily {
    'RedHat': {
      $package     = "${implementation}-client"
      $working_dir = "/var/spool/${implementation}"
      $pid_dir     = '/var/run'
    }
    'Debian': {
      case $implementation {
        'bacula': {
          $package = "${implementation}-fd"
        }
        'bareos': {
          $package = "${implementation}-filedaemon"
        }
      }
      $working_dir = "/var/lib/${implementation}"
      $pid_dir     = "/var/run/${implementation}"
    }
    'windows': {
      $package     = "Bareos 13.2.2-2.1"
    }
    default: {
      $package     = undef
      $working_dir = "/var/spool/${implementation}"
      $pid_dir     = '/var/run'
    }
  }
}
