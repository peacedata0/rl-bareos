Bareos
======

1. [Server](#server)
2. [Client](#client)
   1. [Client parameters](#client-parameters)
   2. [Jobs](#jobs)
   3. [Job presets](#job-presets)
      1. [mysqldumpbackup](#mysqldumpbackup)
      2. [pgdumpbackup](#pgdumpbackup)
      3. [Writing your own](#writing-your-own)
   4. [Filesets](#filesets)
   5. [Complex examples](#complex-examples)
      1. [Pre- and post jobs](#pre-and-post-jobs)
      2. [Service address](#service-address)

# Server

The `bareos::server` class installs the software and collects exported
resources associated with it.

In order to get a working setup, a few common Hiera keys must be set:

__`bareos::secret`__: A random string which is hashed with a seed
value for each client to create its password.

__`bareos::director`__: The name of the director.  Not necessarily a
hostname.  It is essentially the director's username when
authenticating with a FD.  It is also used in the tag of exported
resources.  Default: "dump-dir"

__`bareos::schedules`__: A hash containing sets of schedules.  Each
key defines a set, the value for that key is an array of schedule
names.  The schedules themselves must be defined in the Bareos
configuration outside Puppet.


# Client

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
Either `bacula` or `bareos`.  Default: "bacula"

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

## Jobs

Jobs are defined in the `bareos::client::jobs` hash.

Each key in the hash becomes the name of the resource.  This is added
to the client name and used as the name of the job.  A
`bareos::job_definition` with that name will be exported for the
director to pick up.

__`job_name`__: Specify the full job name explicitly.

__`jobdef`__: The name of the job defaults.  Default: DefaultJob

__`fileset`__: The (full) name of the fileset.  Overrides the fileset
defined in the jobdef.

__`schedule_set`__: The name of the list of schedules to pick randomly
from.  Default: normal

__`sched`__: Explicit name of schedule, overrides random selection.
(`schedule` is a reserved word in Puppet, hence the strange parameter name.)

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

    bareos::client::jobs:
       system: []

This example also runs a normal full backup, but later than normal:

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
           backupdir:   /srv/mysql/backup

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
        $jobdef,
        $fileset,
        $sched,
        $params,
    )

`title` for the define will be the full job name.

`jobdef` will be the empty string if the user didn't specify a jobdef
explicitly.  You should respect the user's wishes, but replace the
value of '' with a value which works for your preset.  (New job
defaults can not be defined in Puppet code, contact MS0 to add it to
main Git repo.)

`fileset` will normally be empty, and should just be passed on.

`sched` is the chosen schedule for this job.

`params` is the hash passed by the user as `preset_params`.  The
preset is free to specify its format and content.

A normal job exports a `bareos::job_define` which `bareos::server`
picks up.  When a _preset_ is used, exporting that declaration must be
done by its define.

This should be done like this:

    $_jobdef = $jobdef ? { '' => 'WidgetJob', default => $jobdef }
    @@bareos::job_definition {
        $title:
            client_name => $bareos::client::client_name,
            name_suffix => $bareos::client::name_suffix,
            jobdef      => $_jobdef,
            fileset     => $fileset,
            sched       => $sched,
            runscript   => [ { 'command' => '/usr/local/bin/widgetdump' } ],
            tag         => "bareos::server::${bareos::director}"
    }

Almost all of the above code must be copied more or less verbatim.  If
you don't need a runscript, you must pass an empty array.

You should try to write your define so it can be used more than once
per client, i.e., consider using `ensure_resource('file', { ... })`
instead of just `file` to avoid duplicate declarations.


## Filesets

The support for filesets is not complete, it is kept simple to focus
on filesets with static include and exclude rules.

The name of the resource is added to the client name and used as the
name of the fileset.  This will export a fileset_definition which the
director will pick up.

__`fileset_name`__: Specify the fileset name explicitly.

__`include_paths`__: Array of paths to include in backup.  Mandatory,
no default.

__`exclude_paths`__: Array of paths to exclude.

__`exclude_dir_containing`__: Directories containing a file with this
name will be skipped.  Set to "" to disable functionality.  Default:
".nobackup".

__`ignore_changes`__: If fileset changes, rerun Full backup if this is
set to `false`.  Default: true

__`acl_support`__: Include information about ACLs in backup.  Causes
an extra system call per file.  Default: true

### Example:

    bareos::client::filesets:
        only_srv:
            include_paths:
                - /srv
            exclude_paths:
                - /srv/cache

## Complex examples

### Pre- and post jobs

The following will install the software and register two jobs,
"system" and "srv".  Before the "srv" job runs, the prepare script
will run, and if it fails, backup will be aborted.  After the "srv"
job finishes, the cleanup script will run.

    bareos::client::jobs:
        system:
            fileset: "%{::fqdn}-system"
        srv:
            fileset: "%{::fqdn}-srv"
            runscript:
                -
                  command:      "/usr/local/sbin/prepare"
                  abortonerror: true
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

### Service address

When doing backup of a service which can run on more than one node, it
is essential to set `bareos::client::password` to the same value on
each of the nodes.  However, you do not / can not declare the same job
on more than one node, since that will cause duplicate definitions in
PuppetDB.  You must pick one node to register the common job.

In a common yaml file:

    bareos::client::password: common-secret
    bareos::client::jobs:
        system:
            fileset: "%{domain}-without_archive"

In a yaml file only read by a single node:

    bareos::client::filesets:
        without_archive:
            fileset_name: "%{domain}-without_archive"
            include_paths:
                - /
            exclude_paths:
                - /srv/archive
        archive:
            fileset_name:  "%{domain}-archive"
            include_paths:
                - /srv/archive

    bareos::client::service_addr:
        archive.example.com: []

    bareos::client::jobs:
        archive_service:
            client_name:  archive.example.com
            fileset_name: "%{domain}-archive"
