# Define: bareos::job_definition
#
# This define installs a configuration file on the backup server.
#
define bareos::job_definition(
  $client_name,
  $jobdef,
  $fileset,
)
{
  $filename = "${bareos::server::job_file_prefix}${title}.conf"

  file { $filename:
    content => template('bareos/server/job.erb');
  }

  if $fileset != '' {
    File[$filename] {
      require => Bareos::Fileset_definition[$fileset]
    }
  }
}
