---
name: ship-audit
description: "Security and robustness audit of an app you're about to ship or already have: self-hosted and homelab services, or apps on Supabase, Vercel, Firebase and similar. Use when the user asks if their app is safe to launch or expose, wants a pre-launch security check, is working through a security checklist, or worries about leaked keys, a surprise cloud bill, spam signups or an open database. Prefer over a generic code review when the subject is a deployed or about-to-deploy app."
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
Data disclosure · data loss · outage · a surprise bill · a legal letter · blocked by an upstream
you don't control (an app store, a browser extension store, a third-party API revoking access)

Then read the matching reference file(s) for checks specific to that shape:

- `references/self-hosted.md` - you own the infrastructure
- `references/managed-platform.md` - Supabase/Vercel/Firebase-style hosting
- `references/public-exposure.md` - anyone on the internet can reach it, either way
- `references/ai-features.md` - the app itself calls an LLM (chat, summarising, agents, tool use)
- `references/client-side.md` - the code runs on the user's device: browser extensions, desktop
  and mobile apps

Read only what applies. Say plainly which categories you're skipping and why - "no CAPTCHA
needed, there are no public forms" is a finding, not a gap. Noise is how audits become
wallpaper.

The same goes for the Step 3 categories. Where the shape rules one out entirely - no file
uploads, no login, no server of your own - list it now as not applicable, with the reason, and
don't revisit it in Step 3. Only rule out what the shape settles; if you'd need to read the code
to know, it stays in.

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

Check the ledger's facts as well as its decisions. An open item that is no longer true - a
"no LICENSE" entry for a repo that now has one, a TODO for a fix that already shipped - should
be flagged as stale so the ledger can be pruned. A ledger nobody trusts stops being read too.

## Step 3 - Audit the universal categories

These apply to most shapes; work through the ones Step 0 didn't rule out. Platform-specific
checks live in the reference files.

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

### Injection and output

Validation decides what gets in; this is about what the data does once it's in.

- **Queries built from strings.** Any SQL, NoSQL filter or search query assembled by
  concatenating user input instead of using parameters or the ORM's safe API. Check raw-query
  escape hatches especially - every ORM has one, and it's where generated code reaches when the
  safe API was awkward.
- **Shell, eval and templates.** User input reaching a shell command, `eval`, or a server-side
  template is executed as code, not handled as data.
- **Output rendered as HTML.** Anything that writes user content without escaping -
  `innerHTML`, `dangerouslySetInnerHTML`, `v-html`, `|safe`, markdown rendered without
  sanitising - is stored XSS waiting for its first malicious user. Frameworks escape by default;
  the bugs live where someone opted out.

### File uploads

- **Type and size limits enforced server-side**, by content rather than by file extension or
  the client's declared type.
- **How uploads are served.** User files served from the app's own origin with their original
  content type let an uploaded SVG or HTML file run script as your site. Serve with a safe
  content type and `Content-Disposition: attachment`, or from a separate domain.
- **Filenames are user input.** A name like `../../config` written to disk unsanitised is path
  traversal. Generate your own storage names.
- **Can one user reach another's files?** Upload URLs are often guessable, public, or never
  expire.

### Outbound requests

Features that fetch a URL the user supplies - link previews, "import from URL", webhook
targets, avatar-by-URL - make your server a proxy into wherever it can reach.

- **Can the URL point inward?** `localhost`, private address ranges and the cloud metadata
  endpoint (`169.254.169.254`) are reachable from the server even when they aren't from the
  internet. Metadata endpoints can hand out cloud credentials.
- **Are redirects followed?** Validating the first URL is useless if the server then follows a
  redirect somewhere internal.
- **Is the response shown back to the user?** That turns a blind request into a read.

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

### Build and deploy pipeline

The pipeline usually holds more power than the app: deploy keys, cloud credentials, publish
tokens.

- **Can untrusted code reach secrets?** Workflows triggered by pull requests from forks
  (`pull_request_target` on GitHub Actions is the classic) can run a stranger's code with your
  secrets in the environment.
- **Are third-party actions and build steps pinned** to a commit or version, or do they track a
  branch someone else can move?
- **How much can each credential do?** A deploy key or token scoped to everything turns one
  leaked secret into a full compromise. Least privilege, per environment.

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

**Test safely.** Proving a finding means touching a real system, so decide where and how
before you start:

- **Ask before active testing against production.** Prefer a staging copy. If production is
  the only option, say exactly what you intend to send and get a yes first.
- **Never run destructive probes.** Don't exercise a delete path, an import or a migration
  against real data to see what happens. Reason from the code, or reproduce on a copy.
- **Mind side effects.** Lockout and rate-limit tests can lock out real users; abuse tests
  against metered endpoints produce a real bill; signup and reset tests send real email. Use a
  test account, stop at the first confirmation, and keep volume minimal.
- **Only probe what the user controls.** Scans and fuzzers against someone else's host - a
  shared platform, a third-party API, a neighbouring tenant - can breach their terms or the
  law. Managed platforms often publish a testing policy; check it.
- **If you can't verify safely, say so.** Report the finding as unverified, with the reason.
  That's more useful than a guess presented as a result.

**Reproduce, don't infer.** If you believe a route crashes on bad input, send the bad input and
read the status code. Plenty of things that look broken are handled somewhere you haven't read,
and reporting those costs you trust for the findings that are real. Concrete commands for the
common checks are in `references/verification.md`.

When the runtime isn't yours to probe - a third-party site your extension runs on, a
platform API with terms against testing - "only probe what the user controls" wins over
"reproduce, don't infer". The bar then is a code-read finding plus a unit test that exercises
the vulnerable path with the hostile input. Say in the report that it was verified that way
rather than against the live system.

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
- Active testing against production without permission, or with side effects nobody agreed to
- Confirming data-shape claims against an empty or non-production database
- Re-raising decisions the project already settled
- Treating "it's internal" or "it's managed" as the end of the analysis
- Fixing during the audit, so the user never sees the whole picture
- Homogenising routes that differ deliberately
