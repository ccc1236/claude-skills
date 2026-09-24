# AI feature checks

Read this when the app itself calls a language model: chat, summarising, classification,
agents, anything with tool use. This is separate from whether the app was *built* with AI.
The model is an input you don't control, reading content you don't control, so treat its
output with the same suspicion as user input.

## Prompt injection

- **Whose text reaches the prompt?** User messages, but also documents, web pages, emails,
  file contents and database rows the model is asked to process. Any of these can carry
  instructions, and the model can't reliably tell data from commands.
- **What can injected instructions do?** The question is not whether injection is possible -
  assume it is - but what an injected instruction could make the app do. That's decided by the
  tools and data the model can reach, not by the system prompt.
- **System prompts are not access control.** "Never reveal other users' data" in a prompt is a
  request, not a restriction. Enforce limits in code.

## Tools and data access

- **Does the model act with the user's permissions or the app's?** A tool that queries the
  database with a service credential lets any user who can steer the model read anything that
  credential can. Scope tool calls to the requesting user.
- **Which tools have side effects** - sending email, writing data, spending money, calling
  external APIs? Those need confirmation or tight limits, because injected text can trigger
  them.
- **Can the model reach the network?** A fetch tool plus private data is an exfiltration path:
  injected instructions ask it to fetch a URL with the data in the query string.

## Output handling

- **Is model output rendered as HTML or markdown** without sanitising? Model output is
  attacker-influenced text; rendering it raw is XSS by proxy. Markdown images are a common
  exfiltration path, because the browser fetches the image URL automatically.
- **Is output used as code, a query or a command?** Generated SQL, shell or code that runs
  without review carries every injection risk at once.

## Cost and abuse

- **Per-user limits on model calls and on tokens**, not just requests. One request can carry a
  very large prompt.
- **Is any model call reachable without authentication?** That's a free LLM proxy on your bill.
- **Caps on output length and on agent loops**, so a runaway tool loop stops.
- **Spend caps at the provider**, as with any metered API.

## Data

- **What goes to the model provider**, and does their retention and training policy fit what
  you're sending? Personal or confidential data in prompts is data shared with a third party.
- **Are prompts and completions logged?** Those logs contain whatever users typed, often more
  sensitive than the rest of the app's data.
