# Self-hosted checks

Read this when the operator owns the infrastructure - VPS, homelab, on-prem VM, a container
they run. The defining characteristic is that nothing is handled for you: TLS, the OS,
the firewall, backups and patching are all yours, and each is a place where a perfectly
good application fails in production.

## Transport

This is the category generic checklists omit entirely, because they assume managed hosting
where TLS is automatic. On self-hosted infrastructure it is routinely the single largest
real exposure, and source-code review will never surface it.

- **Is traffic encrypted at all?** If credentials cross any network in cleartext, anyone able
  to capture packets on that network reads them. "It's only the office LAN" includes
  contractors, guest VLANs, compromised laptops and anyone who plugs into a wall port.
- **Certificate validity and expiry date.** Note the actual date.
- **Is expiry monitored?** A five-year certificate nobody is watching is a scheduled outage.
  If there's a monitoring stack, is this host actually in it?
- **Does plaintext redirect to encrypted**, or is the plain port still serving the app?
- **Certificate trust model.** A self-signed certificate encrypts traffic but clients can't
  verify it, so it defeats passive capture but not an active man-in-the-middle. That's often
  an acceptable trade internally - but check whether it has quietly pushed people into
  disabling verification in their tooling, because that habit spreads to hosts where it
  matters.
- **Cookie flags versus transport.** Secure-only cookies require working TLS. If TLS is ever
  removed, that flag must come back off or every login silently fails with no error.

## Network exposure

- **What is actually listening, on which interfaces?** An app server intended to sit behind a
  reverse proxy should bind to loopback, not `0.0.0.0`. Check rather than assume - `ss -tlnp`
  or equivalent.
- **Firewall state versus what is genuinely needed.** Ports opened during debugging tend to
  stay open.
- **Admin interfaces** - database ports, management consoles, metrics endpoints - reachable
  from further than intended.
- **Is the host reachable from further than the operator believes?** Verify from outside the
  expected network if you can.

## Service isolation

- **What identity does it run as?** A dedicated service account, not root, and not a login user.
- **What can it write to?** Sandboxing directives that restrict the filesystem to only the
  paths it genuinely needs.
- **What happens on crash or reboot** - does it come back automatically?
- **Secrets in the environment file**, with permissions that exclude other local users.

## Backups

- **Do they exist, and do they run unattended?**
- **Are they valid?** This matters more than existence. A file-level copy of a live database
  can capture a torn write and be silently corrupt - and that is precisely the artifact you
  would restore from in an emergency. Use the database's own backup mechanism, and verify one
  backup with an integrity check rather than assuming.
- **Has a restore ever been tested?** An untested restore is a hypothesis.
- **Where do they live?** Backups on the same disk as the data protect against corruption but
  not against losing the machine.
- **Do they rotate**, or will they eventually fill the disk?

## Platform

- **Does the OS still receive security updates?** Check the release's support status.
- **Are updates applied**, and is there a reboot process for kernel updates?
- **Is the runtime a supported version?**
- **Dependency pinning.** Unpinned dependencies mean a rebuild installs whatever is current
  that day - nondeterministic, and how vulnerable or breaking versions arrive silently.
- **Known vulnerabilities in installed packages.** Language ecosystems have audit tooling
  (`pip-audit`, `npm audit`, `cargo audit`); run it rather than eyeballing version numbers,
  and be honest when you cannot check.

## Operational

- **Can the service be rebuilt from scratch** using only what's documented?
- **Do the runbook's commands actually work?** Run them. Documented commands drift silently
  as the deployment changes, and a runbook that fails during an incident is worse than none.
- **Is anything monitored that fails quietly** - certificate expiry, disk space, backup
  success, service restarts?
- **Where do logs go, and does anything read them?**
