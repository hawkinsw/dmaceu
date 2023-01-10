#!/bin/bash
#
# execsnoop - snoop process execution as it occurs.
#             Written using DTrace (Solaris 10 3/05).
#
# 09-Jan-2022, ver 1.35
#
# USAGE:	execsnoop [-c command | -p pid]
#
#		execsnoop	# default output
#
#		-c command	# command name to snoop
#		-p pid		# only print executions from this parent pid
#	eg,
#		execsnoop 		# snoop all execs.
#		execsnoop -c ls		# snoop ls execs only.
#		execsnoop -p 518	# snoop execs from parent pid 518.
#
# FIELDS:
#		UID		User ID
#		PID		Process ID
#		PPID		Parent Process ID
#		COMM		command name for the process
#		ARGS		argument listing for the process
#
# SEE ALSO: BSM auditing.
#
# COPYRIGHT: Copyright (c) 2005 Brendan Gregg, 2023 Will Hawkins
#
# CDDL HEADER START
#
#  The contents of this file are subject to the terms of the
#  Common Development and Distribution License, Version 1.0 only
#  (the "License").  You may not use this file except in compliance
#  with the License.
#
#  You can obtain a copy of the license at Docs/cddl1.txt
#  or http://www.opensolaris.org/os/licensing.
#  See the License for the specific language governing permissions
#  and limitations under the License.
#
# CDDL HEADER END
#
# Author: Brendan Gregg  [Sydney, Australia]
#
# 27-Mar-2004	Brendan Gregg	Created this.
# 21-Jan-2005	   "	  "	Wrapped in sh to provide options.
# 08-May-2005 	   "      "	Rewritten for performance.
# 14-May-2005 	   "      "	Added zonename.
# 02-Jul-2005 	   "      "	Added projid, safe printing.
# 11-Sep-2005	   "      "	Increased switchrate.
# 09-Jan-2023	Will Hawkins	Updated/simplified for (modern) macOS


##############################
# --- Process Arguments ---
#

### default variables

declare -i filter=0
declare -i filter_pid=0
declare    filter_command=""

function usage {
cat <<-END >&2
		USAGE: execsnoop [-c command | -p pid]
		       execsnoop                # default output
		                -c command      # command name to snoop
		                -p pid		# only print executions from this parent pid
		  eg,
		        execsnoop 		# snoop all execs.
		        execsnoop -c ls         # snoop ls commands only
		        execsnoop -p 518	# snoop execs from parent pid 518.
END
}

### process options
while getopts c:p: name
do
	case $name in
	c)	filter+=1; filter_command=$OPTARG ;;
	p)	filter+=1; filter_pid=$OPTARG ;;
	h|?)	usage; exit 1 ;;
	esac
done

if [ $filter -gt 1 ]; then
	echo "Cannot specify a PID and a command to filter."
	usage;
	exit 1;
fi

#################################
# --- Main Program, DTrace ---
#
/usr/sbin/dtrace -n '
 /*
  * Command line arguments
  */
 inline int FILTER 	= '$filter';
 inline string COMMAND 	= "'$filter_command'";
 inline int PID 	= '$filter_pid';
 
 #pragma D option quiet
 #pragma D option switchrate=10hz
 
 /*
  * Print header
  */
 dtrace:::BEGIN 
 {
	/* print main headers */
	/* APPLE: Removed "ZONE" header, it has no meaning in darwin */
	printf("%5s %6s %6s %s %s\n", "UID", "PID", "PPID", "COMM", "ARGS");
 }

 /*
  * Print exec event
  */
 proc:::exec-success
 / (FILTER == 0) || 
   (strstr(execname, COMMAND) == strstr(COMMAND, execname) && 
    strstr(execname, COMMAND) != NULL) ||
   (ppid == PID)
 /
 {
	/* print main data */
	printf("%5d %6d %6d %s %s\n",
	        uid, pid, ppid, execname, curproc->p_comm);
 }
'
