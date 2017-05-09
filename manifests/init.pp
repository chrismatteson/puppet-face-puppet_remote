class puppet_remote (
  $platforms = ['el.4.i386', 'el.4.x86_64', 'el.5.i386', 'el.5.x86_64', 'el.6.i386', 'el.6.x86_64', 'el.7.x86_64'], # TODO: expand this to include non el platforms
  $version = 'master', #ignored for now
) {

  $baseurl = 'https://pm.puppetlabs.com/puppet-agent'

  file { ["${puppet_vardir}/remote", "${puppet_vardir}/remote/agents", "${puppet_vardir}/remote/nodes"]:
    ensure => directory,
  }
  class { 'nfs':
    server_enabled => true,
  } ->
  nfs::server::export { '/opt/puppetlabs':
    ensure  => 'mounted',
    clients => '*(rw,sync,no_root_squash)',
  }

  $platforms.each |String $platform| {
    $platform_array = split($platform, '[.]')
    staging::file { "puppet-agent-${aio_agent_build}-1.${platform_array[0]}${platform_array[1]}.${platform_array[2]}.rpm":
      target => "${puppet_vardir}/remote/agents/puppet-agent-${aio_agent_build}-1.${platform_array[0]}${platform_array[1]}.${platform_array[2]}.rpm",
      source => "${baseurl}/${pe_build}/${aio_agent_build}/repos/${platform_array[0]}/${platform_array[1]}/PC1/${platform_array[2]}/puppet-agent-${aio_agent_build}-1.${platform_array[0]}${platform_array[1]}.${platform_array[2]}.rpm",
      notify => Exec["rpm2cpio puppet-agent-${aio_agent_build}-1.${platform_array[0]}${platform_array[1]}.${platform_array[2]}"],
    }
    file { "${puppet_vardir}/remote/agents/puppet-agent-${aio_agent_build}-1.${platform_array[0]}${platform_array[1]}.${platform_array[2]}":
      ensure => directory,
    }
    exec { "rpm2cpio puppet-agent-${aio_agent_build}-1.${platform_array[0]}${platform_array[1]}.${platform_array[2]}":
      command => "/bin/rpm2cpio ../puppet-agent-${aio_agent_build}-1.${platform_array[0]}${platform_array[1]}.${platform_array[2]}.rpm | cpio -idmv ./opt/puppetlabs/*",
      refreshonly => true,
      cwd         => "${puppet_vardir}/remote/agents/puppet-agent-${aio_agent_build}-1.${platform_array[0]}${platform_array[1]}.${platform_array[2]}",
    }
  }
}
