# Client-side app checks

Read this when the code runs on the user's device rather than on a server you operate:
browser extensions, desktop apps (Electron, Tauri, native) and mobile apps. The trust
boundary moves. Anything shipped to the device can be read, modified and replayed, and the
most dangerous input often comes from web pages or other apps the user happens to open,
not from your users.

## Messaging between parts

Extensions and desktop apps are several processes with different privileges talking to each
other. The bugs live in who is allowed to send what.

- **Map the privilege levels.** Extension: content scripts (inside hostile pages) · background
  or service worker (holds permissions and storage) · popup and options pages. Electron:
  renderer versus main process. Mobile: the app versus deep links and intents from other apps.
- **Does the privileged side check the sender?** A background handler that acts on any
  `runtime.onMessage` without checking `sender.id`, `sender.tab` or `sender.url` lets a
  compromised content script, or any page if `externally_connectable` is broad, drive it.
- **`window.postMessage` is a public channel.** A content script listening for page messages
  must check `event.source === window` and validate the payload; the page, and every script
  on it, can send the same messages.
- **Electron**: `contextIsolation` on, `nodeIntegration` off, `sandbox` on, and the preload
  exposes narrow functions, not `ipcRenderer` itself. An IPC handler that takes a path or a
  command from the renderer is a remote code execution waiting for one XSS.
- **Deep links and custom URL schemes** are input from any web page or app. Treat every
  parameter as hostile, and never let one trigger a sensitive action without confirmation.

## Sinks in content scripts and renderers

- **Page data reaching the DOM.** A content script that reads text from the page and writes it
  back with `innerHTML` runs the page's markup with the extension's privileges. Use
  `textContent` or build elements.
- **Page data reaching privileged code.** Data scraped from a page and passed to the
  background, to storage or to your server is attacker-controlled; validate it there.
- **Remote code.** Loading scripts from a server, `eval`, or `new Function` in an extension
  breaks store policy (Manifest V3 forbids remote code) and hands your privileges to whoever
  controls that server.
- **Content Security Policy.** Extension pages and Electron windows should have a strict CSP;
  loosening it to make something work is a finding.

## Permissions

- **Least privilege.** Every host permission and API permission is attack surface and a
  reason for store review to reject or users to decline. `<all_urls>` or `*://*/*` when the
  extension only needs one site is the common case.
- **Optional permissions** for features not everyone uses, requested at the moment of need.
- **Mobile and desktop**: camera, location, contacts, file system and accessibility access,
  each justified by a feature that uses it.

## Secrets and local data

- **Nothing shipped is secret.** API keys in an extension, app bundle or mobile binary are
  public. If the key must stay private, put it behind a server you control.
- **Local storage is readable** by anyone with access to the device and, for extensions, by
  any code running in the extension. Tokens belong in the platform keychain or secure storage
  on desktop and mobile; keep what an extension stores to what it needs.
- **Update channel.** How does a new version reach users, and is it signed? An auto-updater
  that fetches over plain HTTP or skips signature checks is a way to push code to every
  install.

## Store policy

The store can remove the app, and that's often the realistic bad day.

- **Read the current policy** for each store you publish to (Chrome Web Store, Firefox Add-ons,
  App Store, Play Store) and check the app against it: remote code, data disclosure, single
  purpose, permission justification.
- **Privacy disclosures** in the store listing must match what the code actually collects and
  sends. A mismatch is a removal reason on its own.
- **Is there a privacy policy URL**, and does it describe this app?

## Third-party services you depend on

Client-side apps often work by reading or automating someone else's site or API.

- **Terms of service.** Does the site or API permit scraping, automation or the use you make of
  it? A cease-and-desist or a revoked key ends the product.
- **Rate limits and blocking.** Every install hits the upstream from a user's IP with a user's
  session. Do many installs together look like abuse? What happens when the upstream starts
  returning 429s or changes its markup - graceful failure, or a broken extension and a flood of
  one-star reviews?
- **Is the user's own account at risk?** Automation that runs under the user's login can get
  that user banned. Say so in the report if it applies.
- **Don't probe the upstream to find out.** It's not the user's system; read its published
  terms and limits instead.
