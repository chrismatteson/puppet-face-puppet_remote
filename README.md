# puppet-face-remote

This module provides a manifest and puppet face to enable agentless control systems utilizing unmodified puppet code.

## class puppet_remote

Downloads agent packages and creates NFS servers to host /opt/puppetlabs files
and a seperate directory to host unique /etc/puppetlabs folders for each client

## puppet remote face

This face allows one function :run which will ssh into a client using the
provided credentials, make /etc/puppetlabs and /opt/puppetlabs directories, map
them back to the master, run puppet, and then clean up.

### To Do:

Currently the face does not create the /etc/puppetlabs folder, nor does it create
a unique nfs export, or build the puppet.conf. Those are handled in the remote.sh
bash script under lib but needs to be integrated into the face

Bug 1: If multithreading is enabled and the number of nodes to run is less than
the number of threads, the commands end up being run against the local system, 
which breaks it.
