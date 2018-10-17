#!/bin/sh /etc/rc.common
#
# alias definitions for the "DSL CPE Control Application"
# to simplify the usage of the pipe interface
#

xDSL_BinDir=@dsl_bin_dir@

path_found=`echo $PATH | grep ${xDSL_BinDir}`

if [ ! -z ${path_found} ]; then
   export PATH=$PATH:${xDSL_BinDir}
fi

echo "... run alias defs for DSL Subsystem (type 'dsl' for a list of CLI commands)"

alias dsl='dsl_cpe_pipe'

# definitions for message-dumps and events
alias dsl_log_dump_cout='tail -f /tmp/pipe/dsl_cpe0_dump &'
alias dsl_log_dump='tail -f /tmp/pipe/dsl_cpe0_dump > dump.txt &'
alias dsl_log_event_cout='tail -f /tmp/pipe/dsl_cpe0_event &'
alias dsl_log_event='tail -f /tmp/pipe/dsl_cpe0_event > event.txt &'
