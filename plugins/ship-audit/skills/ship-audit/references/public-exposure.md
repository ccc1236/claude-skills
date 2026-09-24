# Public exposure checks

Read this when anyone on the internet can reach the app, whether it's self-hosted or on a
managed platform. Public exposure adds a category of problem that internal apps don't have:
adversaries who are automated, patient, and not aiming at you personally. Scanners find new
hosts within minutes, and most of what follows is about surviving indiscriminate traffic
rather than a targeted attacker.

## Anonymous access

- **What can be reached with no credentials at all?** Enumerate it deliberately rather than
  assuming the login page is the only door. Health endpoints, metrics, API routes, admin
  panels on alternate ports, static file listings.
- **Are there predictable identifiers?** Sequential ids let someone walk your entire dataset
  if any endpoint is under-protected.
- **Is anything expensive reachable anonymously?** Anything that hits a paid API, sends mail,
  or runs a heavy query is a cost and availability problem before it's a security one.

## Registration and account abuse

- **Can anyone self-register?** If so, decide deliberately what an unverified account can do.
- **Is email verification enforced before access**, not just requested?
- **Bot protection on public forms** - signup, contact, password reset, waitlist. Without it,
  expect spam within days of being indexed. A privacy-respecting CAPTCHA is a ten-minute
  integration and is the difference between a working inbox and an unusable one.
- **Does registration reveal whether an address is already registered?** So does password
  reset, and so does login if the errors differ.
- **Disposable email domains**, if account cost matters.

## Rate limiting

Assume it's needed everywhere, then relax it where it isn't.

- **Login and password reset** - otherwise credential stuffing runs unimpeded.
- **Any endpoint reaching a metered service.**
- **Anything expensive to compute or query.**
- **Per-IP for anonymous traffic, per-account for authenticated.** IP alone is weak but not
  worthless; account alone lets anonymous abuse through.
- **Where is it enforced?** Application-level limits still consume application resources.
  Proxy or edge-level is cheaper and survives more.

## Transport and headers

- **HTTPS with a publicly trusted certificate**, and automated renewal. Self-signed is not
  viable here - users can't distinguish your warning from an attack.
- **Is renewal actually automated and tested?** A 90-day certificate with a manual renewal is
  a recurring outage waiting for the one time it's forgotten.
- **Plain HTTP redirects to HTTPS.**
- **HSTS** once TLS is stable - but understand that browsers cache it hard and it's painful to
  reverse, so it should follow a period of confidence rather than lead.
- **Security headers**: content type options, frame options or frame-ancestors, referrer
  policy. A content security policy is more work but is the one that actually constrains
  injected script.

## Data protection obligations

Public exposure usually means collecting data from people who aren't you, which brings
obligations that vary by jurisdiction and by what you hold.

- **What personal data is collected**, including incidentally - IP addresses in logs,
  analytics identifiers, email addresses in a waitlist.
- **Is there a privacy notice** saying what's collected and why, and is it accurate?
- **Where does the data physically live**, and does that matter for the users you serve?
- **How long is it kept**, and is there any deletion path?
- **Is there a way for someone to ask for their data to be removed?**

Flag the legal question rather than answering it - the specifics depend on jurisdiction and
on what's held, and that needs someone who knows the applicable regime. The technical
contribution is an accurate map of what's collected, where it lives, and who can export it.

## Operational readiness

- **Does anything monitor uptime from outside** the host?
- **Would you notice a spike in traffic, errors or spend** before a user or an invoice told you?
- **Is there a way to take the app down or into maintenance** quickly if something goes wrong?
- **Backups** - public exposure raises both the value of the data and the chance of losing it.
