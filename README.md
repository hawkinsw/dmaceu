# DMaceU

Updated versions of Brendan Gregg's awesome DTrace tools for (modern) versions
of macOS.

See more about the original version of these scripts at [his website](https://www.brendangregg.com/dtrace.html).

## Usage

Each script works slightly differently. However, to use *any* of them,
you will have to disable SIP. In order to do that, follow [these instructions](https://developer.apple.com/documentation/security/disabling_and_enabling_system_integrity_protection).

Once you have disabled SIP, you can run any of these tools like

```console
$ sudo ./<tool>.sh [arguments]
```

See the follow sections for information about each tool.

## Tools

### recvsnoop.sh

This tool will report the pathname of the Unix socket on which a program is
`recv`ing data.

### rwsnoop.sh

This tool will report the pathname of the file (if any) associated with the
file descriptor on which a program is doing I/O.

### execsnoop.sh

This tool will report the command name (i.e., the name of the program) and
arguments of every process that is `exec`d on the system. Filters available
for the launching PID and the name of the program `exec`d.

## LICENSE

Files bearing their own licenses (in the header of the file) are
licensed according to those terms. Files without their own licenses are
licensed according to [GPLv3](./LICENSE).
