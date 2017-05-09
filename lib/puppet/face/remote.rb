require 'puppet/indirector/face'

Puppet::Face.define(:remote, '0.0.1') do

  copyright 'Chris Matteson', 2017
  license 'Apache 2 license; see COPYING'

  action :run do
    summary 'Connects to an unmanaged system, mounts puppet directories, and runs puppet without installing a local agent'
    arguments "node"

    description <<-EOT
      Here is a ton of more useful information :)
    EOT

    when_invoked do |node, options|
    end
  end
end
