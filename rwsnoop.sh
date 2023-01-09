#!/bin/sh
# #!/usr/bin/ksh
#
# rwsnoop - snoop read/write events.
#           Written using DTrace (Solaris 10 3/05).
#
# This is measuring reads and writes at the application level. This matches
# the syscalls read, write, pread and pwrite.
#
# 08-Jan-2022, ver 0.80
#
# USAGE:	rwsnoop [-jPtvZ] [-n name] [-p pid]
# 
#		rwsnoop		# default output
#
#		-j		# print project ID
#		-P		# print parent process ID
#		-t		# print timestamp, us
#		-v		# print time, string
#		-Z		# print zone ID
#		-n name		# this process name only
#		-p PID		# this PID only
#	eg,
#		rwsnoop -Z		# print zone ID
#		rwsnoop -n bash 	# monitor processes named "bash"
#		rwsnoop > out.txt	# recommended
#
# NOTE:
# 	rwsnoop usually prints plenty of output, which itself will cause
#	more output. It can be better to redirect the output of rwsnoop
#	to a file to prevent this.
#
# FIELDS:
#		TIME		Timestamp, us
#		TIMESTR		Time, string
#		ZONE		Zone ID
#		PROJ		Project ID
#		UID		User ID
#		PID		Process ID
#		PPID		Parent Process ID
#		CMD		Process name
#		D		Direction, Read or Write
#		BYTES		Total bytes during sample, -1 for error
#		FILE		Filename, if file based
#
# Reads and writes that are not file based, for example with sockets, will
# print "<unknown>" as the filename.
#
# SEE ALSO:	rwtop
#
# COPYRIGHT: Copyright (c) 2005 Brendan Gregg, 2022 Will Hawkins
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
# TODO:
#  Track readv and writev.
#
# Author: Brendan Gregg  [Sydney, Australia]
#
# 24-Jul-2005   Brendan Gregg   Created this.
# 17-Sep-2005	   "      "	Increased switchrate.
# 08-Jan-2022	Will Hawkins	Support for (modern) macOS
#

function bad_parameter {
  bp=$1
  shift;
  program=$1
  echo "-${bp} is not a valid parameter to ${program}."
  return
}

function missing_argument {
  ma=$1
  shift;
  program=$1
  echo "-${ma} is missing a required parameter."
  return
}


function usage {
  zero=$1

  echo "usage: ${zero} [-p <PID to snoop>|-n <process name to snoop>]"
  return
}

filter_any=0
filter_name=0
filter_pid=0
pid="0"
name=""

while getopts :p:n: option "$@"; do
  case ${option} in
    p)
      pid=${OPTARG}
      filter_pid=1
      filter_any=1
      ;;
    n)
      name=${OPTARG}
      filter_name=1
      filter_any=1
      ;;
    '?')
      bad_param=${OPTARG}
      bad_parameter $bad_param $0
      usage $0
      exit 1
      ;;
    ':')
      missing_arg=${OPTARG}
      missing_argument $missing_arg $0
      usage $0
      exit 1
      ;;
  esac
done

if [ ${filter_pid} -eq 1 -a ${filter_name} -eq 1 ]; then
  echo "Only one of -p or -n can be set."
  usage $0
  exit 1
fi

if [ ${filter_any} -eq 0 ]; then
  echo 'One of -p or -n must be set.'
  usage $0
  exit 1
fi

script='
 /*
  * Command line arguments
  */
 inline int OPT_filter_name 	= '${filter_name}';
 inline int OPT_filter_pid 	= '${filter_pid}';
 inline int PID		= '${pid}';
 inline string NAME 	= "'${name}'";
  
 #pragma D option quiet
 #pragma D option switchrate=10hz

 /*
  * Print header
  */
 dtrace:::BEGIN 
 {
	/* print header */
	printf("%5s %6s %-12s %1s %7s %s\n",
	    "UID", "PID", "CMD", "D", "BYTES", "FILE");
 }

 /*
  * Check event is being traced
  */
 syscall::*read_nocancel:entry,
 syscall::*write_nocancel:entry,
 syscall::*read:entry,
 syscall::*write:entry
 / self->ok == 0 /
 {
	self->ok = -1;

	/* check for exact name match */
	(OPT_filter_name == 1 && 
	 (this->name_match=strstr(execname, NAME)) == strstr(NAME, execname) && 
         this->name_match != NULL) ? self->ok = 1 : 1;
	(OPT_filter_pid == 1 && PID == pid) ? self->ok = 1 : 1;

	self->fd = arg0;
 }

 /*
  * Save read details
  */
 syscall::*read_nocancel:return,
 syscall::*read:return
 / self->ok == 1 /
 {
	self->rw = "R";
	self->size = arg0;
 }

 /*
  * Save write details
  */
 syscall::*write_nocancel:entry,
 syscall::*write:entry
 / self->ok == 1 /
 {
	self->rw = "W";
	self->size = arg2;
 }

 /*
  * Process event
  */
 syscall::*read_nocancel:return,
 syscall::*write_nocancel:entry,
 syscall::read:return,
 syscall::write:entry,
 syscall::pread:return,
 syscall::pwrite:entry
/*
 syscall::*read:return,
 syscall::*write:entry
*/
 / self->ok == 1 /
 {
	/*
	 * Fetch filename
	 */
	this->fpp = &(curproc->p_fd.fd_ofiles[self->fd]);
	this->fg = (struct fileglob *)((*(this->fpp))->fp_glob);
	this->vnodep  = (struct vnode *)strip((struct vnode *)(this->fg->fg_data), ptrauth_key_process_independent_code);
	this->vpath = this->vnodep ? (this->vnodep->v_name != 0 ? 
	    this->vnodep->v_name : "<unknown>") : "<unknown>";

	/*
	 * Print details
	 */
	printf("%5d %6d %-12.12s %1s %7d %s\n",
	    uid, pid, execname, self->rw, (int)self->size, this->vpath);
	
	self->fd = 0;
	self->size = 0;
	self->rw = "";
 }
'
/usr/sbin/dtrace -n "${script}"
