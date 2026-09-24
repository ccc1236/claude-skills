# Managed platform checks

Read this when the app runs on Supabase, Vercel, Firebase, Netlify, Render, Fly or similar.
The platform handles transport, patching and uptime. What it does *not* handle is your
configuration - and misconfiguration, not exploitation, is how these apps actually fail.

The dangerous property of managed platforms is that the defaults are tuned for getting
started quickly, and "it works" arrives well before "it's safe". An app can be fully
functional, beautifully designed, and readable by anyone with the browser console open.

## Database access rules

The single highest-impact category. Managed databases are commonly reachable directly from
the browser using a key that ships in the frontend by design - which is fine, *provided*
row-level rules restrict what that key can see. Without them, the key is a full read
credential handed to every visitor.

- **Are row-level security rules enabled on every table holding real data?** Check per table.
  Enabling it on the obvious ones and missing a join table or an audit table is common.
- **Do the policies actually restrict correctly?** Enabled-but-permissive is worse than
  disabled, because it produces false confidence. Test by reading as a different user, and as
  no user at all.
- **Does every policy cover all four operations** - select, insert, update, delete? A read
  policy without a matching write policy leaves writes open.
- **Are there tables that were created later and never got policies?** New tables are the
  usual gap.
- **Storage buckets** have their own access rules, separate from the database. Check them too.

## Keys and environment variables

- **Know which keys are meant to be public.** Anon/publishable keys are designed to ship to the
  browser and are safe *only* because access rules constrain them. Service-role, secret and
  admin keys bypass those rules entirely and must never leave the server.
- **Check what actually reached the browser.** Framework env-var prefixes decide this - a
  variable exposed to the client bundle is public, whatever its name suggests. Search the built
  output, not just the source.
- **Assume anything exposed is compromised** and rotate it rather than hoping. Public
  repositories are scraped for keys continuously.
- **Check git history**, not just current files. Rotating a key doesn't unpublish it.
- **Server-only code paths** - serverless functions, route handlers, server actions - are where
  secret keys belong, with the secret stored in the platform's secret store rather than in the
  repo.

## Serverless and edge functions

- **Do they verify who is calling?** A function deployed without an auth check is a public
  endpoint, regardless of how obscure its URL is.
- **Do they validate input** before using it in a query or passing it to a paid API?
- **Are they rate limited?** Platform functions scale automatically, which means they also
  scale your bill automatically.
- **Do webhooks verify their signature?** An unverified webhook endpoint is an unauthenticated
  write path into your data.

## Cost and abuse

Managed platforms bill by usage, which turns abuse into an invoice rather than an outage.

- **Rate limits on any endpoint that reaches a metered service** - model APIs, email, SMS,
  storage, the database itself.
- **Hard spend caps configured in each provider's dashboard**, not just alerts. An alert tells
  you it happened; a cap stops it.
- **Alerts well below the cap**, so a spike is visible before it's expensive.
- **Is there anything expensive reachable without authentication?** That's the combination that
  produces the overnight bill.

## Platform auth

If using the platform's built-in authentication:

- **Is email verification enforced**, or can anyone register an address they don't control?
- **What can an unverified or newly registered account reach?**
- **Are redirect URLs restricted** to your domains?
- **Which providers are enabled** - including any left on from testing?
- **Does the client trust user metadata?** Fields writable by the user are not authorization.
  A role stored in user metadata is a claim, not a permission.

## Deployment surface

- **Preview and branch deployments** - are they protected, or is a staging build with real data
  publicly indexed?
- **Are source maps published**, and does that matter for what's in the bundle?
- **CORS configuration** - permissive-by-default in development, and frequently shipped that way.
- **Is the production database being used by preview environments?**
