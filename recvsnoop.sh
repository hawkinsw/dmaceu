#/bin/bash

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

while getopts p:n: option "$@"; do
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
    ?)
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
	printf("%5s %6s %-12s %7s %7s %s\n",
	    "UID", "PID", "CMD", "BYTES", "TYPE", "FILE");
	self->ok = 0
 }

 /*
  * Check event is being traced
  */
 syscall::recvfrom:entry
 / self->ok == 0 /
 {
	self->ok = -1;

	/* check for exact name match */
	(OPT_filter_name == 1 && 
	 (this->name_match=strstr(execname, NAME)) == strstr(NAME, execname) &&
         this->name_match != NULL) ? self->ok = 1 : 1;
	(OPT_filter_pid == 1 && PID == pid) ? self->ok = 1 : 1;
 }

 syscall::recvfrom:entry
 / self->ok == 1 /
 {
	self->fd = arg0;
 }

 syscall::recvfrom:return
 / self->ok == 1/
 {
	this->fpp = (struct fileproc *)(curproc->p_fd.fd_ofiles[self->fd]);
	this->fg = (struct fileglob *)(this->fpp->fp_glob);
	this->socket  = (struct socket *)strip((struct socket *)(this->fg->fg_data), ptrauth_key_process_independent_code);
	this->path = (char*)((struct sockaddr_un*)(((struct unpcb*)this->socket->so_pcb)->unp_addr))->sun_path;
	this->recv_size = arg1;

	/*
	 * Print details
	 */
	printf("%5d %6d %-12.12s %7d %7x %s\n",
	    uid, pid, execname, (int)this->recv_size, 0, stringof(this->path));
	self->fd = 0
 }
'

/usr/sbin/dtrace -n "${script}"
