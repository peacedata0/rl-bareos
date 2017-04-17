Bareos
======

1. [Overview](#overview)
2. [Common setup](#common-setup)
3. [Server](#server)
4. [Client](#client)
   1. [Client parameters](#client-parameters)
   2. [Jobs](#jobs)
   3. [Job presets](#job-presets)
      1. [mysqldumpbackup](#mysqldumpbackup)
      2. [mylvmbackup](#mylvmbackup)
      3. [percona](#percona)
      3. [pgdumpbackup](#pgdumpbackup)
      4. [Writing your own](#writing-your-own)
   4. [Filesets](#filesets)
   5. [Complex examples](#complex-examples)
      1. [Pre- and post jobs](#pre-and-post-jobs)
      2. [Service address](#service-address)


Overview
--------

This module is intended to supplement the configuration of a Bareos
(or Bacula) server with the "dynamic" bits, e.g., the definitions of
clients, jobs and filesets.  The basic configuration (database
settings, logging etc.) must be managed in a handwritten
`bareos-dir.conf`.  This file should include the configuration
generated by Puppet using the following snippet:

    # Puppet clients and jobs
    @|"bash -c 'ls -d /etc/bareos/{clients,jobs,filesets}.d/*.conf | sed s/^/@/'"

## Non-module

Some pieces of the configuration must be written by hand or handled
otherwise.  This includes schedules and jobdefs.


Common setup
------------

In order to get a working setup, a few common Hiera keys must be set:

__`bareos::secret`__: A random string which is hashed with a seed
value for each client to create its password.

__`bareos::director`__: The name of the director.  Not necessarily a
hostname.  It is essentially the director's username when
authenticating with a FD.  It is also used in the tag of exported
resources.  Default: "dump-dir"

__`bareos::schedules`__: A hash containing sets of schedules.  Each
key defines a set, the value for that key is an array of schedule
names.  A declared job will look for the set called `normal` by
default.  The schedules themselves must be [defined outside this module](#non-module).

## Optional configuration

__`bareos::default_jobdef`__: Name of default job definition.
Defaults to `DefaultJob`.  The jobdef itself must be
[defined outside this module](#non-module).

__`bareos::security_zone`__: A tag identifying which secret the
director should use to generate the password for this client.

When security zone is unset, `bareos::secret` will be used on both
client and server.  If security zone is set, the client will still use
the `bareos::secret` as seen in its view of Hiera, but the server will
instead look for the alternate secret in `bareos::server::secrets`.


Server
------

The `bareos::server` class installs the software and collects exported
resources associated with it.

## Server parameters

__`bareos::server::secrets`__: Hash containing secrets for other
security zones.  Default: {}

__`bareos::server::client_file_prefix`__: Where to put collected
client resources.  Default: '/etc/bareos/clients.d/'

__`bareos::server::job_file_prefix`__: Where to put collected job
resources.  Default: '/etc/bareos/jobs.d/'

__`bareos::server::fileset_file_prefix`__: Where to put collected
fileset resources.  Default: '/etc/bareos/filesets.d/'


Client
------

The `bareos::client` class will install the file daemon and configure
it with passwords.  It will also export resources (Client, Job, and
Fileset) which the director collects.

## Client parameters

__`bareos::client::password`__:
Set this parameter to get the same password on several clients.  This
is not the actual password used in the configuration files, this is
just a seed which is hashed with `${bareos::secret}`.  We do that
extra step to avoid putting the actual password in PuppetDB.  Default: FQDN

__`bareos::client::concurrency`__:
How many jobs can run at the same time on this client.  Default: 10

__`bareos::client::implementation`__:
Either `bacula` or `bareos`.  This needs to be set via Hiera to affect
defaults which are based on this value.  Default: "bacula"

__`bareos::client::client_name`__:
The name of the client, without the "-fd" suffix.  Default: FQDN

__`bareos::client::name_suffix`__:
The suffix to use.  Default: "-fd"

__`bareos::client::address`__:
The address or hostname the director should connect to.  Default: FQDN

__`bareos::client::job_retention`__:
How long to keep jobs from this client in the database.  Default: "180d"

__`bareos::client::file_retention`__:
How long to keep detailed information about backup job contents in the
database.  Default: "60d"

__`bareos::client::monitors`__:
Additional list of monitors to add to bacula-fd.conf.  Typical use:

    bareos::client::monitors:
      tray-mon:
        password: password-in-plain-text

Use eyaml to protect "password-in-plain-text".  All keys in the hash
are added as parameters to the Director directive.

__`bareos::client::compression`__: This variable is __only__ used as a
default for [filesets](#filesets) declared on this host.

__`bareos::client::fstype`__: This variable is __only__ used as a
default for [filesets](#filesets) declared on this host.

__`bareos::client::exclude_paths`__: This variable is __only__ used as
a default for [filesets](#filesets) declared on this host.

__`bareos::client::exclude_patterns`__: This variable is __only__ used as
a default for [filesets](#filesets) declared on this host.

__`bareos::client::backup_dir`__: The default parent directory where
the preset jobs will dump data.  Default: "/var/backups"

__`bareos::client::manage_backup_dir`__: Create and manage the default
parent directory.  Default: true

__`bareos::client::backup_dir_owner`__: Owner of above directory
Default: "root"

__`bareos::client::backup_dir_group`__: Group of above directory
Default: "root"

__`bareos::client::backup_dir_mode`__: Mode of above directory
Default: "0755"

__`bareos::client::systemd_limits`__: Hash of resource limits which
needs overriding.  Only works for systemd, but no check is done to see
if systemd manages the service.  Example: { 'nofiles' => 16384 }.
Default is to do nothing.

In addition, you can manage the service, the location of the log file,
the pid file and the working directory, but this should not be
necessary to do.

## Jobs

Jobs are defined in the `bareos::client::jobs` hash.

By default, a "system" job will be enabled for the client, using the
default jobdef.

Each key in the hash becomes the name of the resource.  This is added
to the client name and used as the name of the job.  A
`bareos::job_definition` with that name will be exported for the
director to pick up.

__`job_name`__: Specify the full job name explicitly.

__`jobdef`__: The name of the job defaults.  Default: `$bareos::default_jobdef`

__`fileset`__: The name of the fileset.  When set, overrides the
fileset defined in the jobdef.  This can be the full name of the
fileset, but also the abbreviated name used in
`bareos::client::filesets`.

__`schedule_set`__: The name of the list of schedules to pick randomly
from.  Default: normal

__`sched`__: Explicit name of schedule, overrides random selection.
(`schedule` is a reserved word in Puppet, hence the strange parameter name.)

__`accurate`__: Whether to turn Accurate on or off.  When set to '',
don't include directive in configuration (job defaults are used).
Default: ''

__`order`__: Give a hint to in what order jobs should run.  This
should be a value consisting of one capital letter and two digits.
Jobs with "A00" will be scheduled first, "Z99" will be scheduled last.
The default is "N50".

__`runscript`__: Array of script specifications to run before or after
job.  Each element is a hash containing values for `command` and
optional other parameters.  `command` can be a single command or an
array of strings.  `runswhen` is either `before` or `after`, by
default it is `before`.  Other parameters are written verbatim as `Key
= value` to bareos configuration.

__`preset`__: Use specified class to export the job.  See next
section.

__`preset_params`__: Parameters to pass to preset class.

### Example:

The following example installs a backup agent and registers a job with
all the default settings:

    include bareos::client

To only install the client without running any jobs, add to Hiera:

    bareos::client::jobs: {}

This example also runs a normal full backup, but later than normal
(this assumes that a set called `late` is defined in
`bareos::schedules`):

    bareos::client::jobs:
       system:
           schedule_set: late

## Job presets

A _preset_ define can install scripts or other software on the client
in addition to exporting configuration for the backup server.

### mysqldumpbackup

This preset installs the script mysqldumpbackup and installs a
configuration file for it.  See
[code](manifests/job/preset/mysqldumpbackup.pp) for full list of
parameters.

Example usage:

    bareos::client::jobs:
      system:
         preset:        bareos::job::preset::mysqldumpbackup
         preset_params:
           keep_backup: 5
           backup_dir:  /srv/mysql/backup

### mylvmbackup

This preset installs the package mylvmbackup and installs a
configuration file for it.  See
[code](manifests/job/preset/mylvmbackup/config.pp) for full list of
parameters.

Example usage:

    bareos::client::jobs:
      system:
         preset:        bareos::job::preset::mylvmbackup
         preset_params:
           keep_backup: 5
           vgname:      sysvg
           lvname:      mysql

### percona

This preset installs the package percona-xtrabackup and the percona plugin
from [bareos-contrib](https://github.com/bareos/bareos-contrib.git).
(Since the plugin is not packaged, we distribute a copy of it in this
module.)  The backup will include a "virtual" file in xbstream format and
the binary logs.  You should still include a normal system backup.

Available settings in `preset_params` include:

__`mycnf`__: location of my.cnf to use

__`skip_binlog`__: do not include binlogs in backup, default is `false`

__`xtrapackage_package`__: name of package containing xtrabackup(1).
On Ubuntu Xenial you may need to specify "percona-xtrabackup-24".
Default: "percona-xtrabackup"

Example usage:

    bareos::client::jobs:
      system: {}
      db:
         preset:        bareos::job::preset::percona
         preset_params:
           mycnf:       /etc/mysql/mysql-db02.cnf

### pgdumpbackup

This preset installs the script pgdumpbackup and installs a
configuration file for it.  See [code](manifests/job/preset/pgdumpbackup.pp) for details.

Example usage:

    bareos::client::jobs:
      system:
         preset:        bareos::job::preset::pgdumpbackup
         preset_params:
           cluster:     9.2/main


### Writing your own preset

The signature for a preset should be this:

    define widget::backup::preset::widgetdump(
        $client_name,
        $jobdef,
        $fileset,
        $sched,
        $order,
        $runscript,
        $params,
    )

`title` for the define will be the full job name.

`client_name` is the name of the client, and should be passed on.

`jobdef` will be the empty string if the user didn't specify a jobdef
explicitly.  You should respect the explicit value, but replace the
empty string with a value which works for your preset (possibly
`$bareos::default_jobdef`).  New job defaults can not be defined in
Puppet code, they must be added to the main Bareos configuration
manually.

`fileset` will normally be empty, and should just be passed on.

`sched` is the chosen schedule for this job, pass it on.

`order` should just be passed on.

`params` is the hash passed by the user as `preset_params`.  The
preset is free to specify its format and content.

`runscript` is an array of additional pre- or post commands.

A normal job exports a `bareos::job_define` which `bareos::server`
picks up.  When a _preset_ is used, exporting that declaration must be
done by its define.

This should be done like this:

    $_jobdef = $jobdef ? { '' => 'WidgetJob', default => $jobdef }
    @@bareos::job_definition {
        $title:
            client_name => $client_name,
            name_suffix => $bareos::client::name_suffix,
            jobdef      => $_jobdef,
            fileset     => $fileset,
            sched       => $sched,
            order       => $order,
            runscript   => flatten([ $runscript,
                                     [{ 'command' => '/usr/local/bin/widgetdump' }]
                                   ]),
            tag         => "bareos::server::${bareos::director}"
    }

Almost all of the above code must be copied more or less verbatim.
`flatten()` is used to concatenate arrays, which is otherwise only
available when the future parser is enabled.  If you don't need a
runscript, you just pass `$runscript` on.

You should try to write your define so it can be used more than once
per client, i.e., consider using `ensure_resource('file', { ... })`
instead of just `file` to avoid duplicate declarations.


## Filesets

The support for filesets is not complete, it is kept simple to focus
on filesets with static include and exclude rules.

Since the normal filesets *should* contain `Exclude dir containing`
`.nobackup`, an alternative to making a custom fileset may be to
manage strategically placed `.nobackup` files using Puppet.

The name (title) of the `bareos::client::fileset` instance is added to
the client name and used as the name of the fileset in the Bareos
configuration.  The define exports a `fileset_definition` which the
director will pick up.

__`fileset_name`__: Specify the fileset name explicitly.

__`client_name`__: Used as the first part of a fully qualified fileset
name.  Doesn't need to relate to any host or client names as long as
the result is unique.  Default is bareos::client::client_name.

__`include_paths`__: Array of paths to include in backup.  Mandatory,
no default.

__`exclude_paths`__: Array of paths to exclude.  If unset, use the
client's default (bareos::client::exclude_paths).  If one of the
values is "defaults", the default exclude list will be added to the
array.

__`exclude_patterns`__: Hash of different kinds of patterns to
exclude.  If unset, use the client's default
(bareos::client::exclude_patterns).  The possible keys are `wild_dir`,
`wild_file`, `regex_dir` and `regex_file`.  Each key in the hash can
have a list of patterns as its value.

__`exclude_dir_containing`__: Directories containing a file with this
name will be skipped.  Set to "" to disable functionality.  Default:
".nobackup".

__`include_patterns`__: Hash of different kinds of patterns to
include.  Default is empty (no special rules).  The possible keys are
`wild_dir`, `wild_file`, `regex_dir` and `regex_file`.  Each key in
the hash can have a list of patterns as its value.  In Bareos, all
files will be included by default, so specifying an extra include rule
changes nothing.  Therefore, an exclude rule matching all files will
be added to the configuration as well.  It is recommended to manually
inspect the result on the server to see if it works as intended.  This
is especially important for the `wild_dir` and `regex_dir` directives.

__`ignore_changes`__: If fileset changes, rerun Full backup if this is
set to `false`.  Default: true

__`acl_support`__: Include information about ACLs in backup.  Causes
an extra system call per file.  Default: true

__`compression`__: What compression algorithm to use.  To disable
compression, set to `false`.  Default: "GZIP"

__`sparse`__: Whether to store information about the holes in sparse
files or just store the holes as plain NUL bytes.  Default: true

__`onefs`__: Whether to recurse into mount points.  Default:
false (do not recurse).

__`fstype`__: If `onefs` is false (the default), this array lists the
filesystem types which should be recursed into (and backed up).  The
default (from `bareos::client::fstype`) contains the normal local
filesystems, like `ext4` and `xfs`, but not `nfs` or `cifs`.

### Example:

    bareos::client::filesets:
        only_srv:
            include_paths:
                - /srv
            exclude_paths:
                - /srv/cache

If this configuration is used on node `foo.example.com`, a fileset
called "foo.example.com-only_srv" will be exported.


## Complex examples

### Pre- and post jobs

The following will install the software and register two jobs,
"system" and "srv".  Before the "srv" job runs, the prepare script
will run, and if it fails, backup will be aborted.  After the "srv"
job finishes, the cleanup script will run.

    bareos::client::jobs:
        system:
            fileset: "system"
        srv:
            fileset: "srv"
            runscript:
                -
                  command:      "/usr/local/sbin/prepare"
                  abortjobonerror: true
                -
                  command:      "/usr/local/sbin/cleanup"
                  runswhen:     after
    bareos::client::filesets:
        system:
            include_paths:
                - /
            exclude_paths:
                - /srv
        srv:
            include_paths:
                - /srv

### NFS

The default fileset will not traverse into NFS file systems, so it
needs to be specified explicitly.  Here we define a separate job for
NFS paths.  We set OneFS to true, since the default fstype list does
not include nfs.  Alternatively, if we want to recurse into other NFS
filesystems, we could set `fstype: ["nfs"]`

    bareos::client::filesets:
        nfs:
            onefs: true
            include_paths:
                - /srv/data

We add another job which uses the new fileset (the system job still
uses the default fileset specified in the ``$bareos::default_jobdef``)

    bareos::client::jobs:
        system: {}
        nfs:
            fileset: "nfs"


### Service address

When doing backup of a service which can run on more than one node, it
is essential to set `bareos::client::password` to the same value on
each of the nodes.  It is also important that the job and fileset
definitions agree across nodes, so it is best to put the configuration
in a single Hiera file read by the relevant nodes.

Example:

    bareos::client::password: common-secret

    bareos::client::jobs:
        system:
            fileset:      without_archive
        archive_service:
            client_name:  archive.example.com
            fileset_name: archive

    bareos::client::filesets:
        without_archive:
            client_name:  archive.example.com
            include_paths:
                - /
            exclude_paths:
                - /srv/archive
        archive:
            client_name:  archive.example.com
            include_paths:
                - /srv/archive

    bareos::client::service_addr:
        archive.example.com: {}

This will make one job "${fqdn}-system-job" for each node using this
configuration, and one job "archive.example.com-archive_service-job".
The latter job will run on the extra client, "archive.example.com".
(The name must resolve in DNS, otherwise specify "address".)

It will declare one fileset, "archive.example.com-without_archive",
which all the "${fqdn}-system-job" jobs use.  If the fileset didn't
specify "client_name", each node would declare its own copy of the
fileset called "${fqdn}-without_archive".  This would work fine, but
it is always good to avoid duplication.

Finally, it will declare one fileset "archive.example.com-archive",
which the "archive.example.com-archive_service-job" uses.
