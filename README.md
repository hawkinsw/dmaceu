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

## LICENSE

Files bearing their own licenses (in the header of the file) are
licensed according to those terms. Files without their own licenses are
licensed according to [GPLv3](./LICENSE).
