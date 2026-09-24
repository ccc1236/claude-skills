# Verification recipes

Concrete ways to prove a finding before reporting it. Each recipe proves one claim; put the
command and the relevant output in the report as evidence. The "Test safely" rules in Step 4
apply to every one of these: prefer staging, get a yes before touching production, use test
accounts, and only probe hosts the user controls.

Replace `HOST`, `TOKEN_A`, ids and paths with real values. Examples assume a POSIX shell; note
the platform when a command differs.

## Transport and headers

Is plain HTTP redirected, and what does the response actually send?

```bash
curl -sI http://HOST/ | head -5          # expect 301/308 to https://
curl -sI https://HOST/                   # read HSTS, CSP, X-Content-Type-Options, frame options
```

Certificate issuer, subject and exact expiry date:

```bash
openssl s_client -connect HOST:443 -servername HOST </dev/null 2>/dev/null \
  | openssl x509 -noout -issuer -subject -dates
```

## What is listening and reachable

On the host, what is bound to which interface (look for `0.0.0.0` or `[::]` on things that
should be loopback):

```bash
ss -tlnp                                  # Linux
Get-NetTCPConnection -State Listen        # Windows PowerShell
docker ps --format '{{.Names}}  {{.Ports}}'   # 0.0.0.0:PORT means published past the firewall
```

From outside the expected network, against a host the user owns:

```bash
nc -zv HOST 5432                          # one suspected port
nmap -Pn --top-ports 1000 HOST            # broader, only with the owner's say-so
```

The firewall's own status output is a claim, not proof. Test from outside.

## Secrets

In git history, not just the current tree:

```bash
gitleaks detect --source . --log-opts="--all"
trufflehog git file://. --only-verified
```

In what actually ships to the browser. Build first, then search the output, not the source:

```bash
grep -rEn 'sk_live_|service_role|AKIA[0-9A-Z]{16}|-----BEGIN|secret' dist/ build/ .next/static/ 2>/dev/null
```

Then list every client-exposed env var (`NEXT_PUBLIC_*`, `VITE_*`, `REACT_APP_*`,
`PUBLIC_*`) and confirm each one is meant to be public.

## Authorization

Use two test accounts you control. Request a resource owned by B with A's credentials, then
with no credentials:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer $TOKEN_A" https://HOST/api/items/ID_OWNED_BY_B
curl -s -o /dev/null -w '%{http_code}\n' https://HOST/api/items/ID_OWNED_BY_B
```

Expect 403 or 404 for both. A 200 is the finding; repeat across sibling routes before reporting.

## Managed database rules

Supabase: call the REST API with only the public anon key, exactly as a stranger with the
browser console would. Read-only, one row:

```bash
curl -s "https://PROJECT.supabase.co/rest/v1/TABLE?select=*&limit=1" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $ANON_KEY"
```

Real rows back from a table that holds user data means row-level security is off or
permissive. Check every table, including join and audit tables. Don't test writes this way
against production.

Firebase Realtime Database public read:

```bash
curl -s "https://PROJECT.firebaseio.com/.json?shallow=true"
```

## Failure paths on public routes

Does the one unauthenticated surface crash on bad input? Expect a 4xx, never a 500:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://HOST/login -H 'Content-Type: application/json' -d '{}'
curl -s -o /dev/null -w '%{http_code}\n' -X POST https://HOST/login -H 'Content-Type: application/json' -d 'not json'
```

Account enumeration: compare the response to a reset or login request for a test address you
own versus one that doesn't exist. Any difference in status, body or timing is the finding.

Rate limiting: send a small burst with a test account and stop at the first 429. Don't keep
going to see whether lockout exists; that locks out whoever owns the account.

```bash
for i in $(seq 1 15); do curl -s -o /dev/null -w '%{http_code} ' -X POST https://HOST/login \
  -H 'Content-Type: application/json' -d '{"email":"TEST_ACCOUNT","password":"wrong"}'; done; echo
```

## File uploads

Upload a harmless test `.svg` or `.html` through the feature, then fetch it back and read how
it's served:

```bash
curl -sI https://HOST/uploads/TEST_FILE.svg | grep -iE 'content-type|content-disposition'
```

`image/svg+xml` or `text/html` served inline from the app's own origin is the finding.

## Outbound requests

On staging, point the URL feature at an endpoint you control and confirm the server fetches
it, then at `http://127.0.0.1:PORT/` and a private address. A response, a different error,
or a timing difference from the internal targets shows the server can reach inward.

## Dependencies

```bash
npm audit --omit=dev
pip-audit
cargo audit
osv-scanner -r .                          # any ecosystem
```

Report what's installed and reachable, not every advisory in the tree. If a tool can't run,
say so rather than eyeballing version numbers.

## Backups

A backup is proven valid only by restoring it or checking its integrity:

```bash
sqlite3 BACKUP.db "PRAGMA integrity_check;"      # expect: ok
pg_restore --list BACKUP.dump > /dev/null        # readable archive; then restore into a scratch DB
```

## Build and deploy pipeline

```bash
grep -rn "pull_request_target" .github/workflows/
grep -rnE "uses: [^@]+@(main|master|v?[0-9]+(\.[0-9]+)*)$" .github/workflows/   # not pinned to a commit SHA
```

A `pull_request_target` workflow that checks out the pull request's code and has secrets in
scope is the finding. Tag-pinned actions are a judgement call; branch-pinned ones are not.
