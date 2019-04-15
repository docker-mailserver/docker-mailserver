## What do we want to test?

### Demo mode

[x] When setting demo mode, does chart get deployed with expected demo data? (I.e., it's ready for use)
[ ] When disabling demo mode, does chart correctly input the expected config variables?

### HA Proxy mode

[x] When setting haproxy mode to "enabled", do the appropriate settings make their way into configmaps? Is the reverse true?
[ ] If in external-auto mode, do the correct SEND_PROXY environment variables get set? Is the reverse true?
[ ] If in ingress mode, do the correct SEND_PROXY settings get set?

### Disable SPF

[ ] User is able to disable SPF checks (if they don't want to use haproxy)

If haproxy is disabled altogether, do..