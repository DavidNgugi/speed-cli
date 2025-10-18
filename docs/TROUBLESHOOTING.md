# Troubleshooting Guide

## Common Issues

If the service is not running, run this to verify:

```sh
launchctl list | grep internet.monitor
```

if you need to force an immediate start:

```sh
launchctl start com.user.internet.monitor
```