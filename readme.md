

## Overview

This is a wrapper around `Invoke-AzVMRunCommand` that adds support for a few extra things.
Specifically it supports objects (for both input and output), streams, timeouts and parallelism.
And also compression on output to support sizes a bit larger than 4KB.


## Out-Of-Scope

The following features are out of scope, at least for now:

- no logging in the remote machine
- no encryption
- I don't enrich the output objects (for ex. add the computername)


## Some explanations:

- Execution Timeout = once the script reaches the remote host, then this is the time needed to run that script on that VM.
- Delivery Timeout = this is the time needed to reach the remote host, to communicate with the Az VM Guest agent service and send the code, and finally to also run the user's script to completion. Which means the Delivery Timeout includes the Execution Timeout. 