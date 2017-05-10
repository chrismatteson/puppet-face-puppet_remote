require 'thread'
require 'facter'
require 'puppet/indirector/face'
require 'puppet/util/terminal'
require 'chloride'
require 'rfacter/node'
require 'rfacter/util/collection'

Puppet::Face.define(:remote, '0.0.1') do

  action :run do
    summary 'Run puppet on a system without a puppet agent'
    arguments '<node> [<node> ...]'
    description <<-DESC
      This face connects to an agentless system, mounts /etc/puppetlabs
      and /opt/puppetlabs directories, and triggers a puppet run without
      installing a local agent.
    DESC

    option '--credentials=' do
      summary 'A JSON file that contains the bulk agent configuration'

      default_to { 'credentials.json' }
    end

    option '--sudo' do
      summary 'Use sudo to run commands on remote systems. Sudo is automatically used if the credentials hash contains a `sudo_password` key or a non root username'
    end

    option '--threads=' do
      summary 'the number of threads to use [defaults to processors times 2]'
      default_to { 1 } #Facter.value('processors')['count'] * 2 }
    end

    option '--nodes=' do
      summary 'Path to a new line seperated file containing nodes or [-] for stdin'
      default_to { 'nodes.txt' }
    end

    when_invoked do |*args|
      options = args.pop

      raise "Configuration File missing: #{options[:credentials]}" unless File.exist?(options[:credentials])

      @config = Hash[JSON.parse(IO.read(options[:credentials])).map { |k, v| [k.to_sym, v] }]
      Puppet.debug("Credentials File: #{@config}")

      if File.exist?(options[:nodes]) || options[:nodes] == '-'
        Puppet.debug($stdin)
        nodes = (options[:nodes] == '-' ? $stdin.each_line : File.foreach(options[:nodes])).map { |line| line.chomp!.split }.flatten
      else
        nodes = args
      end
      Puppet.debug("Nodes:#{nodes}")
      Puppet.debug("Options: #{options}")

      if @config.key?(:sudo_password) || (@config[:username] != 'root')
        use_sudo = true
        Puppet.debug('Using sudo to run the Puppet install script')
      else
        use_sudo = options[:sudo]
      end

      raise ArgumentError, 'Please provide at least one node via arg or [--nodes NODES_FILE]' if nodes.empty?

      thread_count    = options[:threads].to_i
      completed_nodes = []
      failed_nodes    = []
      results         = []
      mutex           = Mutex.new
      hostname        = Facter.value('fqdn')
      server          = Puppet.settings[:server]
      aio_agent_build = Facter.value('aio_agent_build')

      Array.new(thread_count) do
        Thread.new(nodes, completed_nodes, options) do |nodes_thread, completed_nodes_thread, options_thread|
          target = mutex.synchronize { nodes_thread.pop }
#          while target
            Puppet.notice("Processing target: #{target}")
            begin
              node = Chloride::Host.new(target, @config)
              dirname = "/opt/puppetlabs/puppet/cache/remote/nodes/#{node}/puppet"
              unless File.directory?(dirname)
                FileUtils.mkdir_p(dirname)
              end
              File.open("#{dirname}/puppet.conf", "w+") {|f|
                f << "[main]\n"
                f << "certname = #{node}\n"
                f << "server = #{server}\n"
              }
              rfacter = RFacter::Node.new("ssh://#{@config[:username]}:#{@config[:sudo_password]}@#{node}")
              facts = RFacter::Util::Collection.new
              @os_info = Hash[JSON.parse(facts.value('os', rfacter).to_json).map { |k, v| [k.to_sym, v] }]
              osfamily = @os_info[:family]
              architecture = @os_info[:architecture]
              @release = Hash[JSON.parse(@os_info[:release].to_json).map { |k, v| [k.to_sym, v] }]
              Puppet.debug(@os_info)
              node.ssh_connect
              Puppet.debug("SSH status: #{node.ssh_status}")
              if [:error, :disconnected].include? node.ssh_status
                mutex.synchronize { failed_nodes << Hash[target => node.ssh_connect.to_s] }
                next
              end
              # Allow user to pass in -s arguments as hash and reformat for
              # bash to parse them via the -s, such as the csr_attributes
              # custom_attributes:challengePassword=S3cr3tP@ssw0rd
              bash_arguments = @config[:arguments].map { |k, v| v.map { |subkey, subvalue| format('%s:%s=%s', k, subkey, subvalue) }.join(' ').to_s }.unshift('-s').join(' ') unless @config[:arguments].nil?
              install = Chloride::Action::Execute.new(
                host: node,
                sudo: use_sudo,
                cmd:  "bash -c \"\
                  mkdir -p /opt/puppetlabs  &&\
                  mkdir -p /etc/puppetlabs &&\
                  if mount | grep '/opt/puppetlabs '; then echo '/opt/puppetlabs already mounted'; else mount #{hostname}:/opt/puppetlabs/puppet/cache/remote/agents/puppet-agent-#{aio_agent_build}-1.el#{@release[:major]}.#{architecture}/opt/puppetlabs /opt/puppetlabs; fi &&\
                  if mount | grep '/etc/puppetlabs '; then echo '/etc/puppetlabs already mounted'; else mount #{hostname}:/opt/puppetlabs/puppet/cache/remote/nodes/#{node} /etc/puppetlabs; fi &&\
                  /opt/puppetlabs/bin/puppet agent -t &&\
                  umount /opt/puppetlabs &&\
                  umount /etc/puppetlabs &&\
                  rmdir /opt/puppetlabs &&\
                  rmdir /etc/puppetlabs\""
              )
              install.go do |event|
                event.data[:messages].each do |data|
                  Puppet::Util::Log.with_destination(:syslog) do
                    message = [
                      target,
                      data.message
                    ].join(' ')
                    # We lose exit codes with curl | bash  so curl errors must
                    # be scraped out of the message in question. We could do
                    # the curl separately and then the install in later
                    # versions of this code to catch curl errors better
                    curl_errors = [
                      %r{Could not resolve host:.*; Name or service not known},
                      %r{^.*curl.*(E|e)rror}
                    ]
                    re = Regexp.union(curl_errors)
                    severity = data.message.match(re) ? :err : data.severity
                    Puppet::Util::Log.newmessage(Puppet::Util::Log.new(level: severity, message: message))
                  end
                end
              end
              if install.success?
                mutex.synchronize { completed_nodes << Hash[target => install.results[target][:exit_status]] }
              else
                mutex.synchronize { failed_nodes << Hash[target => install.results[target][:exit_status]] }
                Puppet.err "Node: #{target} failed"
              end
#            rescue => e
#              Puppet.err("target:#{target} error:#{e}")
#              mutex.synchronize { failed_nodes << Hash[target => e.to_s] }
            end
#          end
        end
      end.each(&:join)
      results << completed_nodes
      results << failed_nodes
      results.flatten
    end
  end
end
