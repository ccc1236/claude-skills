---
name: ship-audit
description: Security and robustness audit for an app before or after you ship it - covers self-hosted internal tools, VPS and homelab services, and public-facing apps built on managed platforms like Supabase, Vercel, Firebase or Netlify. Use this whenever the user asks if their app is safe to launch or expose, wants a security review or pre-launch check of something they built, mentions hardening or locking down an app, asks "what should I fix before real users get on this", is working through a security checklist they found online, worries about leaked API keys, an unexpected cloud bill, spam signups or an open database, or is auditing infrastructure like TLS, certificates, dependencies or backups. Applies to AI-assisted and vibe-coded projects, side projects, and internal business tools alike. Prefer this over a generic code review whenever the subject is a deployed or about-to-be-deployed application, because the findings that matter most for those live outside the source code.
---

# Auditing an app you're about to ship (or already did)

The findings that actually hurt live in the gap between the code and the deployment. A
clean codebase on a misconfigured platform, or a careful platform serving an app that
trusts its own frontend, both fail in production while looking fine in review.

So the job is not to run a checklist top to bottom. It is to work out what this specific
app exposes, check those things, and prove each finding is real before saying it out loud.

Published checklists mislead in both directions: they assume one deployment shape, so most
items don't apply to yours, and the things that matter most for your shape are missing
entirely. Use Step 0 to decide which checks are even in scope.

## Step 0 - Establish the shape

Settle these before checking anything, and state the answers explicitly. Ask if unclear.

**Who can reach it?**
Public internet · VPN or private network · corporate LAN · single machine

**Who owns the infrastructure?**
- *Self-hosted* - you own the box: VPS, homelab, on-prem VM, container you operate. You are
  responsible for TLS, the OS, the firewall, backups and patching.
- *Managed platform* - Supabase, Vercel, Firebase, Netlify, Render, Fly. The platform handles
  transport and patching; you own configuration, and misconfiguration is the dominant failure
  mode.
- *Both* - common. A managed database behind a self-hosted app, or vice versa.

**Who are the users?**
A few known people · an organisation · strangers who can self-register

**What does it hold?**
Only your own data · internal business records · personal data about third parties ·
payment or health data

**What does a bad day look like?**
Data disclosure · data loss · outage · a surprise bill · a legal letter

Then read the matching reference file(s) for checks specific to that shape:

- `references/self-hosted.md` - you own the infrastructure
- `references/managed-platform.md` - Supabase/Vercel/Firebase-style hosting
- `references/public-exposure.md` - anyone on the internet can reach it, either way

Read only what applies. Say plainly which categories you're skipping and why - "no CAPTCHA
needed, there are no public forms" is a finding, not a gap. Noise is how audits become
wallpaper.

Two failure modes to avoid here. Treating "internal" as "safe" ignores the curious colleague,
the contractor on the guest VLAN, the compromised laptop and the honest admin mistake.
Treating "managed platform" as "secure by default" ignores that the platform secures *itself*,
not your configuration of it.

## Step 1 - Discover the deployment before checking anything

Don't assume a stack; find out what's actually running, because the interesting failures live
between components.

- How is it served, on what ports, bound to which interfaces?
- How does traffic reach it, and is it encrypted?
- How does it run, as what identity, with what write access?
- Where does data live, who can read it, and how is it backed up?
- What is configuration versus what is committed to the repo?
- What did the deploy actually put in production - is it the code you're reading?

Read the project's own docs too. They tell you what the operator *believes* is true, and the
gap between belief and reality is often the finding.

## Step 2 - Read the decisions ledger before reporting anything

Look for consciously accepted risks before raising them: `TODO.md`, `CLAUDE.md`, `AGENTS.md`,
README security sections, ADRs, comments explaining a tradeoff.

Re-raising a settled decision every audit is how audits stop being read. If CSRF was accepted
on a LAN deployment, acknowledge it in a line rather than presenting it as discovery. But if a
decision was recorded and its stated justification is no longer true - the app got exposed, the
data changed, users were added - that *is* worth raising.

## Step 3 - Audit the universal categories

These apply regardless of shape. Platform-specific checks live in the reference files.

### Authorization

Usually the richest source of real bugs in a working app.

- For every route or query returning data, ask what scopes it to the current user, and whether
  that scoping is *complete*. A filter that captures a primary relationship but forgets a
  secondary one - owner but not shared-with, author but not collaborator - returns wrong
  results silently rather than failing loudly.
- Compare sibling routes. Where one enforces a rule and another doesn't, one is wrong, and the
  fix usually belongs in one shared place rather than both.
- Check the route, not the navigation. A link hidden from a role is not access control.

### Input handling

- Is validation enforced server-side, or only in the browser? Client validation is UX. Anything
  can post directly to the endpoint.
- Do *all* entry points validate equally? Bulk import, API and CLI paths routinely bypass what a
  form enforces, and they write the most rows.
- Unguarded type conversions on user input - a cast that assumes a number gets a crash.
- Values that must hold an invariant for the system to keep working. If an identifier is parsed
  as a number elsewhere, one bad value can wedge the system permanently. Self-inflicted denial
  of service is easy to miss and expensive to hit.

### Authentication and session

- Test failure paths, not the happy path: absent fields, malformed input, repeated attempts.
  Login is reachable by anyone who can reach the app, so a crash there is the one
  unauthenticated fault available.
- Does the response distinguish "no such user" from "wrong password"? Does password reset or
  signup reveal whether an address is registered?
- Rate limiting or lockout on repeated failures.
- Session lifetime, idle timeout, what logout actually invalidates.
- Password rules - and whether they're the *same* rules everywhere passwords get set.

### Secrets and disclosure

- Do error messages leak internals to the user? Full detail belongs in the log; the user gets
  something generic.
- Secrets in source, in git *history*, in config, in logs, in backups, in the frontend bundle.
  History matters: rotating a key doesn't unpublish it.
- Is a real database or data dump tracked anywhere it shouldn't be?
- What personal data is held, about whom, for how long. Third-party personal data carries
  obligations that a tool holding only your own data does not.

### Data integrity

- Are backups *valid*, not merely present? A copy taken the wrong way from a live database can
  be silently corrupt - and that's precisely the artifact you'd restore from. Verify one.
- Can you actually restore? Test it, don't assume it.
- What happens to related records when something is deleted?

### Dependencies

- Are versions pinned? Unpinned dependencies make rebuilds non-reproducible and are how you
  silently acquire a breaking or vulnerable version.
- Known vulnerabilities in what's actually installed, especially anything parsing untrusted
  input - document, image and archive parsers.

## AI-assisted and vibe-coded projects

These have characteristic failure modes worth checking directly, because the code reads well
and the demo works:

- **Validation stops at the form.** The generated client-side validation looks thorough, and
  there's nothing behind it.
- **Keys reach the browser.** A secret key placed in frontend code or a public env var because
  it made the call work. Assume anything that reached the browser is compromised.
- **Database rules are permissive or absent**, because the app was built before auth existed
  and never revisited.
- **Authorization was never implemented** - every user's data is one predictable id away.
- **Dependencies were added freely** and nothing has ever audited them.
- **The docs describe intent, not behaviour.** Generated READMEs confidently describe security
  properties the code doesn't have.

None of this is an argument against building this way. It's that the speed which makes a
weekend app possible also makes a weekend liability possible, and the gap is almost always in
what's *behind* the UI rather than in it.

## Step 4 - Prove every finding before reporting it

The credibility of the whole audit rests here.

**Reproduce, don't infer.** If you believe a route crashes on bad input, send the bad input and
read the status code. Plenty of things that look broken are handled somewhere you haven't read,
and reporting those costs you trust for the findings that are real.

**Check claims against the real environment.** If a finding depends on the shape of the data -
"no user is affected", "this only matters at scale" - verify against actual production data, not
a dev copy, fixture, or empty local database. An empty dev database will happily confirm any
claim about data. This mistake is quiet and produces confidently wrong conclusions.

**Distrust documentation as evidence.** Docs describe intent. When a doc says something is
handled and the code disagrees, you've found a bug hiding behind its own documentation.

**When you find a bug, look for its siblings immediately.** The same mistake is rarely made
once. Grep for the pattern before moving on - a scoping bug fixed in one query is usually
present in two more written by the same hand on the same day.

## Step 5 - Report

Rank by realistic impact **in this app's shape**, not by generic severity labels. A crash
reachable by anyone who can hit the host outranks a theoretical injection behind an admin-only
route.

- **Clean** - categories checked that came back genuinely fine, briefly. Real information, and
  it stops the report reading as a wall of complaints.
- **Findings**, ranked, each with what it is, how it fails concretely, how you verified it, and
  what fixing it takes.
- **Not applicable** - what you skipped and why.
- **Decisions needed** - choices rather than defects: a permissions question, a policy call, a
  cost tradeoff. Present the tradeoff; don't pick silently.

Then give one clear recommendation for what to do first, and why. One recommendation beats a
ranked list of ten.

## Step 6 - Fix on approval

Don't fix during the audit. Report first, let the user choose, then work through what they pick.

- **Mind the order of operations.** Some fixes depend on others being live - enabling a
  secure-only cookie before TLS exists locks everyone out. Sequence deliberately and say so.
- **Fix the cause, not the instance.** Where a rule is duplicated across routes and has drifted,
  the fix is one shared definition, or it drifts again.
- **Verify each fix the way you verified the finding** - reproduce the original failure and
  watch it not happen.
- **Preserve deliberate behaviour.** Routes differ for good reasons; match each one's existing
  convention rather than homogenising.
- **Write down what you didn't fix**, with reasoning, into the project's `TODO.md`. An unfixed
  finding with a rationale is a decision; without one it's a bug you'll rediscover.
- **Update the docs the change invalidates**, and re-run any command you put in a runbook.

## Anti-patterns

- Running a checklist written for a different deployment shape
- Reporting inspection as if it were verification
- Confirming data-shape claims against an empty or non-production database
- Re-raising decisions the project already settled
- Treating "it's internal" or "it's managed" as the end of the analysis
- Fixing during the audit, so the user never sees the whole picture
- Homogenising routes that differ deliberately
