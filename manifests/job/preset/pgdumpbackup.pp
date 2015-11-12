# This preset has the following params
#
# +instance+: name of instance.  will be added as argument to
#   pgdumpbackup unless it is default.
#
# The rest will be stored in configuration file
# (/etc/default/pgdumpbackup or /etc/default/pgdumpbackup-$instance)
#
# +keep_backup+: how many days to keep backup
# +backupdir+: where to store backups (file resource must be managed separately)
# +server+: server name to connect to (default is local socket)
# +initscript+: to check if service is running
# +cluster+: what cluster to dump (default "", which means connect to port 5432)
# +skip_databases+: array of databases to skip
# +log_method+: where to log.  default is "console" (ie., stderr)
# +syslog_facility+: where to log.  default is 'daemon'
# +environment+: array of extra environment variables (example: ["HOME=/root"])
#
define bareos::job::preset::pgdumpbackup(
  $jobdef,
  $fileset,
  $sched,
  $params,
)
{
  if ($jobdef == '') {
    $_jobdef = 'DefaultPgSQLJob'
  } else {
    $_jobdef = $jobdef
  }

  ensure_resource('file', '/usr/local/sbin/pgdumpbackup', {
    source => 'puppet:///modules/bareos/preset/pgdumpbackup',
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  })

  if $params['instance'] {
    $instance = "pgdumpbackup-${params['instance']}"
    $command = "/usr/local/sbin/pgdumpbackup -c ${instance}"
  } else {
    $instance = 'pgdumpbackup'
    $command = "/usr/local/sbin/pgdumpbackup -c"
  }

  if (count(keys($params)) > 0) {
    ensure_resource('file', "/etc/default/${instance}", {
      content => template('bareos/preset/pgdumpbackup.conf.erb'),
      mode    => '0400',
      owner   => 'root',
      group   => 'root',
    })
  }

  @@bareos::job_definition {
    $title:
      client_name => $bareos::client::client_name,
      name_suffix => $bareos::client::name_suffix,
      jobdef      => $_jobdef,
      fileset     => $fileset,
      runscript   => [ { 'command' => $command } ],
      sched       => $sched,
      tag         => "bareos::server::${bareos::director}"
  }
}

  