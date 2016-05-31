define rsnapshot::server::config (

  $config_path = $rsnapshot::params::server_config_path,
  $backup_path = $rsnapshot::params::server_backup_path,
  $log_path = $rsnapshot::params::server_log_path,
  $lock_path = $rsnapshot::params::lock_path,
  $server_user = $rsnapshot::params::server_user,
  $client_user = $rsnapshot::params::client_user,
  $directories = {},
  $includes = {},
  $excludes = {},
  $include_files = {},
  $exclude_files = {},
  $server = $::fqdn,
  $no_create_root = $rsnapshot::params::no_create_root,
  $verbose = $rsnapshot::params::verbose,
  $log_level = $rsnapshot::params::log_level,
  $link_dest = $rsnapshot::params::link_dest,
  $sync_first = $rsnapshot::params::sync_first,
  $use_lazy_deletes = $rsnapshot::params::use_lazy_deletes,
  $rsync_numtries = $rsnapshot::params::rsync_numtries,
  $stop_on_stale_lockfile = $rsnapshot::params::stop_on_stale_lockfile,
  $backup_hourly_cron = $rsnapshot::params::backup_hourly_cron,
  $backup_time_minute = $rsnapshot::params::backup_time_minute,
  $backup_time_hour = $rsnapshot::params::backup_time_hour,
  $backup_time_weekday = $rsnapshot::params::backup_time_weekday,
  $backup_time_dom = $rsnapshot::params::backup_time_dom,
  $cmd_preexec = $rsnapshot::params::cmd_preexec,
  $cmd_postexec = $rsnapshot::params::cmd_postexec,
  $cmd_rsnapshot = $rsnapshot::server::cmd_rsnapshot,
  $cmd_ssh = $rsnapshot::server::cmd_ssh,
  $retain_hourly = $rsnapshot::params::retain_hourly,
  $retain_daily = $rsnapshot::params::retain_daily,
  $retain_weekly = $rsnapshot::params::retain_weekly,
  $retain_monthly = $rsnapshot::params::retain_monthly,
  $one_fs = $rsnapshot::params::one_fs,
  $rsync_short_args = $rsnapshot::params::rsync_short_args,
  $rsync_long_args = $rsnapshot::params::rsync_long_args,
  $ssh_args = $rsnapshot::params::ssh_args,
  $wrapper_path = $rsnapshot::params::wrapper_path,
  $du_args = $rsnapshot::params::du_args,
  $use_sudo = false,
  $wrapper_sudo = $rsnapshot::params::wrapper_sudo,
  $wrapper_rsync_sender = $rsnapshot::params::wrapper_rsync_sender,
  $wrapper_rsync_ssh = $rsnapshot::params::wrapper_rsync_ssh,
  $cmd_cp = $rsnapshot::server::cmd_cp,
  $cmd_rm = $rsnapshot::server::cmd_rm,
  $cmd_rsync = $rsnapshot::server::cmd_rsync,
  $cmd_ssh = $rsnapshot::server::cmd_ssh,
  $cmd_logger = $rsnapshot::server::cmd_logger,
  $cmd_du = $rsnapshot::server::cmd_du,
  $cmd_rsnapshot = $rsnapshot::server::cmd_rsnapshot,
  $cmd_rsnapshot_diff = $rsnapshot::server::cmd_rsnapshot_diff,
  $linux_lvm_cmd_lvcreate = $rsnapshot::server::linux_lvm_cmd_lvcreate,
  $linux_lvm_cmd_lvremove = $rsnapshot::server::linux_lvm_cmd_lvremove,
  $linux_lvm_cmd_mount = $rsnapshot::server::linux_lvm_cmd_mount,
  $linux_lvm_cmd_umount = $rsnapshot::server::linux_lvm_cmd_umount,
  ) {

  # Remove trailing slashes.
  $log_path_norm = regsubst($log_path, '\/$', '')
  $lock_path_norm = regsubst($lock_path, '\/$', '')
  $config_path_norm = regsubst($config_path, '\/$', '')
  $backup_path_norm = regsubst($backup_path, '\/$', '')
  $wrapper_path_norm = regsubst($wrapper_path, '\/$', '')

  $log_file = "${log_path_norm}/${name}-rsnapshot.log"
  $lock_file = "${lock_path_norm}/${name}-rsnapshot.pid"
  $config_file = "${config_path_norm}/${name}-rsnapshot.conf"
  $snapshot_root = "${backup_path_norm}/${name}"

  if($ssh_args) {
    $ssh_args_processed = "-e 'ssh ${ssh_args}'"
  } else {
    $ssh_args_processed = ''
  }

  if($use_sudo) {
    $rsync_wrapper_processed = "--rsync-path=\"${wrapper_path_norm}/${wrapper_sudo}\""
  } else {
    $rsync_wrapper_processed = "--rsync-path=\"${wrapper_path_norm}/${wrapper_rsync_ssh}\""
  }

  $rsync_long_args_final = "${ssh_args_processed} ${rsync_long_args} ${rsync_wrapper_processed}"


  file { $snapshot_root :
    ensure  => directory,
    require => File[$backup_path]
  } ->

  file { $log_file :
    ensure  => present,
    require => File[$log_path]
  }

  if($retain_hourly > 0) {
    File[$log_file] -> Cron["rsnapshot-${name}-hourly"]
  } elsif($retain_daily > 0) {
    File[$log_file] -> Cron["rsnapshot-${name}-daily"]
  } elsif($retain_weekly > 0) {
    File[$log_file] -> Cron["rsnapshot-${name}-weekly"]
  } elsif($retain_monthly > 0) {
    File[$log_file] -> Cron["rsnapshot-${name}-monthly"]
  }

  # cronjobs

  ## hourly
  if($retain_hourly > 0) {
    notify { "rsnapshot ${name} hourly: $retain_hourly": }
    cron { "rsnapshot-${name}-hourly" :
      command => "${cmd_rsnapshot} -c ${config_file} hourly",
      user    => $server_user,
      hour    => $backup_hourly_cron,
      minute  => $backup_time_minute
    }
    if($retain_daily > 0) {
      Cron["rsnapshot-${name}-hourly"] -> Cron["rsnapshot-${name}-daily"]
    } elsif($retain_weekly > 0) {
      Cron["rsnapshot-${name}-hourly"] -> Cron["rsnapshot-${name}-weekly"]
    } elsif($retain_monthly > 0) {
      Cron["rsnapshot-${name}-hourly"] -> Cron["rsnapshot-${name}-monthly"]
    }
  }

  ## daily
  if($retain_daily > 0) {
    cron { "rsnapshot-${name}-daily" :
      command => "${cmd_rsnapshot} -c ${config_file} daily",
      user    => $server_user,
      hour    => $backup_time_hour,
      minute  => ($backup_time_minute + 50) % 60
    }
    if($retain_weekly > 0) {
      Cron["rsnapshot-${name}-daily"] -> Cron["rsnapshot-${name}-weekly"]
    } elsif($retain_monthly > 0) {
      Cron["rsnapshot-${name}-daily"] -> Cron["rsnapshot-${name}-monthly"]
    }
  }

  ## weekly
  if($retain_weekly > 0) {
    cron { "rsnapshot-${name}-weekly" :
      command => "${cmd_rsnapshot} -c ${config_file} weekly",
      user    => $server_user,
      hour    => ($backup_time_hour + 3) % 24,
      minute  => ($backup_time_minute + 50) % 60,
      weekday => $backup_time_weekday
    }
    if($retain_monthly > 0) {
      Cron["rsnapshot-${name}-weekly"] -> Cron["rsnapshot-${name}-monthly"]
    }

  ## monthly
  cron { "rsnapshot-${name}-monthly" :
    command  => "${cmd_rsnapshot} -c ${config_file} monthly",
    user     => $server_user,
    hour     => ($backup_time_hour + 7) % 24,
    minute   => ($backup_time_minute + 50) % 60,
    monthday => $backup_time_dom
  }

  $programs = {
    cmd_cp => $cmd_cp,
    cmd_rm => $cmd_rm,
    cmd_rsync => $cmd_rsync,
    cmd_ssh => $cmd_ssh,
    cmd_logger => $cmd_logger,
    cmd_du => $cmd_du,
    cmd_rsnapshot_diff => $cmd_rsnapshot_diff,
    linux_lvm_cmd_lvcreate => $linux_lvm_cmd_lvcreate,
    linux_lvm_cmd_lvremove => $linux_lvm_cmd_lvremove,
    linux_lvm_cmd_mount => $linux_lvm_cmd_mount,
    linux_lvm_cmd_umount => $linux_lvm_cmd_umount,
  }

  $options = {
    lockfile => $lock_file,
    logfile => $log_file,
    no_create_root => $no_create_root,
    verbose => $verbose,
    loglevel => $log_level,
    link_dest => $link_dest,
    sync_first => $sync_first,
    use_lazy_deletes => $use_lazy_deletes,
    rsync_numtries => $rsync_numtries,
    stop_on_stale_lockfile => $stop_on_stale_lockfile,
    cmd_preexec => $cmd_preexec,
    cmd_postexec => $cmd_postexec,
    one_fs => $one_fs,
    rsync_short_args => $rsync_short_args,
    rsync_long_args => $rsync_long_args_final,
    du_args => $du_args,
  }

  $lockfile = "${rsnapshot::server::lock_path}${name}"
  $logfile = "${rsnapshot::server::log_path}${name}"

  # config file
  concat { $config_file :
    owner => $server_user,
    group => $server_user,
    mode  => '0644',
    warn  => true
  }

  concat::fragment { "${config_file}_body" :
    target  => $config_file,
    content => template('rsnapshot/config.erb'),
    order   => 01
  }

  Rsnapshot::Server::Backup_config <<| host == $name |>> {
    config_file => $config_file
  }

}
