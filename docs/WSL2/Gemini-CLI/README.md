# bootstrapping the gemini second brain: a wsl2 survival guide

### authored by squf && gemini

so you wanted to build a peer-ai inside your obsidian vault. you installed the gemini cli on arch linux via wsl2, hooked up the obsidian terminal plugin, and then... nothing. just a blinking cursor and a lot of frustration.

i spent several hours in the dark so you don't have to. here is the full post-mortem of how we got gemini cli fully authed and agentic in a headless wsl2 environment.

---

## 1. the primary obstacles

before we get to the fix, here are the three walls we hit simultaneously. understanding these is key to why standard "just run the command" advice fails in wsl2.

### the tty / raw mode trap

the gemini cli is built on node.js. by default, it tries to initialize an interactive terminal (tty) to show you a pretty menu for selecting your auth method.

* **the symptom:** the terminal just hangs or goes blank after running `gemini /auth`.
* **the cause:** obsidian’s terminal (and sometimes wsl2 backends) doesn't provide a "real" tty handshake that node's `setRawMode` expects. it crashes silently or waits forever for a response that the terminal can't send.

### the truncated url (401 invalid_client)

even when we forced the cli to spit out an auth link, clicking it resulted in a google `401: invalid_client` error.

* **the cause:** wsl2 terminal windows often have limited column widths. the oauth url is massive. the terminal was "wrapping" or "chopping" the url, meaning we were only copying about 80% of the client id.

### the node.js v24/v25 regression

recent versions of node.js (v24 and v25) introduced a regression regarding file locking (`ecompromised` errors) when interacting with windows file systems (like your `d:` drive via `/mnt/d/`).

---

## 2. the red herrings (what didn't work)

we chased a few ghosts before finding the light. don't waste your time on these:

* **echoing the browser:** setting `export BROWSER=echo` helped see the link, but it didn't solve the underlying tty hang.
* **reverting networking:** we tried switching wsl2 to nat mode and forcing ipv4 dns. while good for general wsl2 stability, it didn't fix the internal cli auth logic.
* **manual settings.json editing:** trying to manually write the `oauth_creds.json` is a nightmare because of the way tokens are hashed and exchanged.

---

## 3. the definitive solution

the secret to fixing this is a two-step process: downgrading node for stability and using the "headless" auth flag.

### step a: the node v22 downgrade

node v22 (lts) is the stability sweet spot for this cli on wsl2. use `nvm` to swap it out.

```bash
# install nvm if you don't have it
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc

# move to v22
nvm install 22
nvm use 22

# reinstall the cli globally for the new node version
npm install -g @google/gemini-cli

```

### step b: the no_browser skeleton key

this is the single most important setting. `NO_BROWSER=true` tells the cli: "don't try to be smart. don't try to open a window. just give me the link and wait for me to paste the code."

to make this permanent, add it to your `.bashrc`:

```bash
echo 'export NO_BROWSER=true' >> ~/.bashrc
echo 'export GEMINI_AUTH_METHOD=google_login' >> ~/.bashrc
source ~/.bashrc

```

### step c: the auth flow

now, run the interactive cli:

```bash
gemini

```

1. ✦ the cli will detect you aren't logged in.
2. ✦ because of the flags above, it will skip the interactive menu and print a long url.
3. ✦ copy the **entire** url. if it spans multiple lines, make sure you join them with no spaces.
4. ✦ paste it into your windows browser, auth, and copy the **authorization code** provided at the end.
5. ✦ paste that code back into the terminal.

---

## 4. workspace integration (the "senses")

once authed, you need to enable the google workspace extension to allow squf (the ai) to see your drive and gmail.

```bash
gemini extensions install https://github.com/gemini-cli-extensions/workspace

```

### the "pro plan" lag

if you have a google ai pro plus plan, you might still see `429: resource_exhausted` errors immediately after authing. this is normal. it takes a few hours for your "pro" status to propagate from the web-tier account to the backend cloud-code api used by the cli. give it a nap and try again in the morning.

---

## 5. finalized configuration

here is what a healthy `~/.gemini/settings.json` looks like for a "second brain" setup:

```json
{
  "selectedAuthType": "oauth-personal",
  "theme": "default-dark",
  "general": {
    "previewFeatures": true
  },
  "experimental": {
    "skills": true
  },
  "ui": {
    "showHomeDirectoryWarning": false
  }
}

```

## summary

* ⚡ **no_browser=true** is mandatory for wsl2/obsidian.
* ⚡ **node v22** prevents file-locking crashes.
* ⚡ **windows terminal** is better for the initial auth; **obsidian** is better for daily use.

now go build something cool.
