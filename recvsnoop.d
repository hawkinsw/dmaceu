 /*
  * Command line arguments
  */
 inline int OPT_proj 	= 0;
 inline int OPT_zone 	= 0;
 inline int OPT_bytes 	= 1;
 inline int OPT_name 	= 1;
 inline int OPT_ppid 	= 0;
 inline int OPT_pid 	= 0;
 inline int OPT_time 	= 0;
 inline int OPT_timestr	= 0;
 inline int FILTER 	= 1;
 inline int PID		= 0;
 inline string NAME 	= "mDNSResponder";
 
 #pragma D option quiet
 #pragma D option switchrate=10hz

 /*
  * Print header
  */
 dtrace:::BEGIN 
 {
	/* print header */
	OPT_time    ? printf("%-14s ", "TIME") : 1;
	OPT_timestr ? printf("%-20s ", "TIMESTR") : 1;
	OPT_proj    ? printf("%5s ", "PROJ") : 1;
	OPT_zone    ? printf("%5s ", "ZONE") : 1;
	OPT_ppid    ? printf("%6s ", "PPID") : 1;
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
	/* Default is to trace unless filtering. If
	 * filtering, start by assuming that we failed
	 * to match. */
	self->ok = FILTER ? -1 : 1;

	/* check for exact name match */
	(FILTER == 1 && 
	 OPT_name == 1 && 
	 (self->name_match=strstr(execname, NAME)) == strstr(NAME, execname) && 
         self->name_match != NULL) ? self->ok = 1 : 1;
	(OPT_pid == 1 && PID == pid) ? self->ok = 1 : 1;
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
	OPT_time    ? printf("%-14d ", timestamp / 1000) : 1;
	OPT_timestr ? printf("%-20Y ", walltimestamp) : 1;
	OPT_proj    ? printf("%5d ", curpsinfo->pr_projid) : 1;
	OPT_zone    ? printf("%5d ", curpsinfo->pr_zoneid) : 1;
	OPT_ppid    ? printf("%6d ", ppid) : 1;
	printf("%5d %6d %-12.12s %7d %7x %s\n",
	    uid, pid, execname, (int)this->recv_size, 0, stringof(this->path));
 }
