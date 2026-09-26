# BBHT - AIO — Bug Bounty / Web Security Toolkit Installer

A single Bash script that provisions a fresh Ubuntu box (22.04 / 24.04) with a
modern recon, scanning, and exploitation toolkit for bug bounty and CTF work —
inspired by [nahamsec/bbht](https://github.com/nahamsec/bbht), rebuilt with
tools that are still actively maintained today.

Safe to re-run: every step checks whether a tool is already present and
skips or updates it instead of reinstalling from scratch.

## What it installs

**System packages (apt)**
git, curl, wget, unzip, jq, build-essential, make, gcc, python3 + pip + venv,
ruby-full, libpcap-dev, nmap, masscan, whois, dnsutils, and a Chromium
browser for screenshot tools (installed separately, best-effort, so a
missing/renamed Chromium package never blocks the rest of the install).

**Go** — installed to `/usr/local/go` if not already present, with
`$HOME/go/bin` added to `PATH` via `~/.bashrc`.

**Go-based tools** (installed with `go install`, land in `$HOME/go/bin`)

| Tool | Purpose |
|---|---|
| subfinder | Subdomain enumeration |
| httpx | HTTP probing / live host discovery |
| nuclei | Template-based vulnerability scanning |
| katana | Web crawler |
| dnsx | DNS toolkit |
| naabu | Port scanning |
| notify | Send results to Slack/Discord/etc. |
| interactsh-client | Out-of-band (OOB) interaction testing |
| assetfinder | Subdomain/asset discovery |
| waybackurls | Wayback Machine URL discovery |
| gau | Get All URLs (multiple sources) |
| unfurl | URL parsing/extraction |
| anew | Append-only dedup utility |
| qsreplace | Query string parameter replacement |
| gf | Pattern-based grep (with `Gf-Patterns` preloaded) |
| ffuf | Fuzzing (dirs, params, vhosts) |
| gowitness | Web screenshotting |
| dalfox | XSS scanning |
| gospider | Web crawler |
| amass | Attack surface / asset discovery |
| crlfuzz | CRLF injection scanning |

**Python-based tools** (git-cloned to `~/tools/`, callable as global aliases)

| Alias | Tool | Purpose |
|---|---|---|
| `sqlmap` | sqlmap (dev branch) | SQL injection |
| `dirsearch` | dirsearch | Directory/file brute-forcing |
| `xsstrike` | XSStrike | XSS detection |
| `linkfinder` | LinkFinder | Endpoint discovery in JS files |
| `corsy` | Corsy | CORS misconfiguration scanning |
| `eyewitness` | EyeWitness | Web screenshotting & triage report |

**Ruby-based tools** — `wpscan` (WordPress scanning) via `gem install`.

**Other**
- `massdns` — built from source, installed to `/usr/local/bin`
- `SecLists` — cloned to `~/tools/SecLists`
- Latest `nuclei` templates, pulled automatically

## Requirements

- Ubuntu 22.04 or 24.04 (x86_64/ARM), fresh or existing box
- A non-root user with `sudo`, or root directly
- Internet access (the script `apt update`s, `go install`s, and clones a
  number of GitHub repos — expect it to take a while, especially SecLists)

## Usage

```bash
chmod +x setup.sh
./setup.sh
```

When it finishes, load the new `PATH` entries and aliases:

```bash
source ~/.bashrc
```

The script prints every alias it registered at the end of the run, e.g.:

```
[+] Installed tool aliases (in /home/user/.bbht_aliases):
  sqlmap      ->  python3 /home/user/tools/sqlmap-dev/sqlmap.py
  dirsearch   ->  python3 /home/user/tools/dirsearch/dirsearch.py
  xsstrike    ->  python3 /home/user/tools/XSStrike/xsstrike.py
  linkfinder  ->  python3 /home/user/tools/LinkFinder/linkfinder.py
  corsy       ->  python3 /home/user/tools/Corsy/corsy.py
  eyewitness  ->  python3 /home/user/tools/EyeWitness/Python/EyeWitness.py
  reconftw    ->  echo "clone https://github.com/six2dez/reconftw ..."
  subs        ->  subfinder -silent -d
  livehosts   ->  httpx -silent -status-code -title
  urls        ->  gau --subs
  wayback     ->  waybackurls
  xss         ->  dalfox url
```

## What gets written to your system

| Path | Contents |
|---|---|
| `~/tools/` | All git-cloned tools (sqlmap-dev, dirsearch, XSStrike, LinkFinder, Corsy, EyeWitness, massdns, SecLists, Gf-Patterns) |
| `~/go/bin/` | All Go-installed binaries |
| `~/.bbht_aliases` | Generated aliases (tool shortcuts + recon chain shortcuts), sourced from `~/.bashrc` |
| `~/bbht-setup.log` | Full install log — check here first if a step fails |
| `/usr/local/go` | Go toolchain (only if it wasn't already installed) |
| `/usr/local/bin/massdns` | massdns binary |

## Re-running / updating

Run `./setup.sh` again any time:
- Go tools: skipped if already on `PATH` (re-run manually with `go install
  <pkg>@latest` to force an update)
- Cloned repos: `git pull`ed instead of re-cloned
- `~/.bbht_aliases` and the `~/.bashrc` `source` line: regenerated cleanly,
  no duplicates

## Troubleshooting

- **A tool failed to install** — check `~/bbht-setup.log` for the actual
  apt/go/pip error; the script keeps going instead of stopping on the first
  failure so one broken tool doesn't block the rest.
- **No Chromium found** — gowitness/EyeWitness screenshots need a browser.
  Install one manually, e.g. `sudo snap install chromium`.
- **Command not found after install** — make sure you ran
  `source ~/.bashrc` (or opened a new terminal) after the script finished.

## Legal

These tools are for authorized security testing only — bug bounty programs
you're enrolled in, CTFs, and systems you own or have explicit written
permission to test. Scanning or attacking systems without authorization is
illegal in most jurisdictions.
