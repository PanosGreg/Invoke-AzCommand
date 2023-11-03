

## Overview

This is a wrapper around `Invoke-AzVMRunCommand` that adds support for a few extra things.
Specifically it supports objects (for both input and output), streams, timeouts and parallelism.
And also compression on output to support sizes a bit larger than 4KB. As well as output of remote error records onto the local machine.


## Out-Of-Scope

The following features are out of scope, at least for now:

- no logging in the remote machine
- no encryption
- I don't enrich the output objects (for ex. add the computername)


## Timeout settings:

- **Execution Timeout**  
Once the script reaches the remote host, then this is the time needed to run that script on that VM (but does not include the time needed to send the results back).  
When the Execution timeout expires then the runspace job that runs on the remote host is stopped and any output up to that point is collected.
- **Delivery Timeout**  
This is the time needed to reach the remote host, to communicate with the Az VM Guest agent service and send the code, and finally to also run the user's script to completion and for the agent to send the results back to your computer. Which means the Delivery Timeout includes the Execution Timeout.  
When the Delivery timeout expires then the `Invoke-AzVMRunCommand` that runs locally is stopped which means you don't get any output.