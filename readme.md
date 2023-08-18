

## Overview

This is a wrapper around `Invoke-AzVMRunCommand` that adds support for a few extra things.
Specifically it supports objects (for both input and output), streams, timeouts and parallelism.
And also compression on output to support sizes a bit larger than 4KB.


## Out-Of-Scope

The following features are out of scope, at least for now:

- no logging in the remote machine
- no encryption
- I don't enrich the output objects (for ex. add the computername)
