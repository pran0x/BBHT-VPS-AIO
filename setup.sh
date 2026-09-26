#!/usr/bin/env bash
#
# setup.sh — Bug Bounty / Web Security Toolkit Installer
# Inspired by nahamsec/bbht (https://github.com/nahamsec/bbht),
# updated for modern Ubuntu (22.04/24.04) with actively maintained tools.
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
# Safe to re-run — skips anything already installed.

set -uo pipefail

# ---------- config ----------
TOOLS_DIR="${HOME}/tools"
GOPATH_DIR="${HOME}/go"
LOGFILE="${HOME}/bbht-setup.log"

# ---------- colors ----------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()  { echo -e "${BLUE}[*]${NC} $1" | tee -a "$LOGFILE"; }
ok()   { echo -e "${GREEN}[+]${NC} $1" | tee -a "$LOGFILE"; }
warn() { echo -e "${YELLOW}[!]${NC} $1" | tee -a "$LOGFILE"; }
err()  { echo -e "${RED}[-]${NC} $1" | tee -a "$LOGFILE"; }

mkdir -p "$TOOLS_DIR"
: > "$LOGFILE"

if [[ $EUID -eq 0 ]]; then
    SUDO=""
else
    SUDO="sudo"
fi

# ---------- 1. base packages ----------
log "Updating apt and installing base dependencies..."
# DEBIAN_FRONTEND is passed through `env` (not just exported) so it still
# reaches apt even when running under sudo with env_reset enabled —
# otherwise apt upgrade can hang on conffile/service-restart prompts.
$SUDO env DEBIAN_FRONTEND=noninteractive apt update -y \
    && $SUDO env DEBIAN_FRONTEND=noninteractive apt upgrade -y
$SUDO env DEBIAN_FRONTEND=noninteractive apt install -y \
    git curl wget unzip jq build-essential make gcc \
    python3 python3-pip python3-venv \
    ruby-full \
    libpcap-dev \
    nmap masscan \
    whois dnsutils
ok "Base packages installed."

# Chromium is only needed for gowitness/EyeWitness screenshots and is
# frequently missing/renamed across Ubuntu releases (snap-only on newer
# ones). Install it separately, best-effort, so a failure here can never
# take the essential packages above down with it.
log "Installing a Chromium browser for screenshotting tools..."
$SUDO env DEBIAN_FRONTEND=noninteractive apt install -y chromium-browser \
    || $SUDO env DEBIAN_FRONTEND=noninteractive apt install -y chromium \
    || warn "No apt chromium package found — install one manually (or 'sudo snap install chromium') for gowitness/EyeWitness screenshots to work."

# ---------- 2. Go ----------
if ! command -v go &>/dev/null; then
    log "Installing Go..."
    GO_VERSION="1.23.4"
    ARCH=$(dpkg --print-architecture)
    wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -O /tmp/go.tar.gz
    $SUDO rm -rf /usr/local/go
    $SUDO tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    if ! grep -q '/usr/local/go/bin' "${HOME}/.bashrc"; then
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> "${HOME}/.bashrc"
    fi
    export PATH=$PATH:/usr/local/go/bin:${GOPATH_DIR}/bin
    ok "Go installed: $(go version 2>/dev/null)"
else
    ok "Go already installed: $(go version)"
    export PATH=$PATH:/usr/local/go/bin:${GOPATH_DIR}/bin
fi

export GOPATH="$GOPATH_DIR"
export PATH="$PATH:${GOPATH_DIR}/bin:/usr/local/go/bin"
mkdir -p "${GOPATH_DIR}/bin"

go_install() {
    local name="$1" pkg="$2"
    if command -v "$name" &>/dev/null; then
        ok "$name already installed."
    else
        log "Installing $name..."
        if go install "$pkg" &>>"$LOGFILE"; then
            ok "$name installed."
        else
            err "$name failed to install — check $LOGFILE"
        fi
    fi
}

# ---------- 3. ProjectDiscovery + recon tool suite (Go) ----------
log "Installing recon/scanning tools (Go-based)..."
GO_TOOL_NAMES=(subfinder httpx nuclei katana dnsx naabu notify interactsh-client \
    assetfinder waybackurls gau unfurl anew qsreplace gf ffuf gowitness dalfox \
    gospider amass crlfuzz)
go_install subfinder    "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"
go_install httpx        "github.com/projectdiscovery/httpx/cmd/httpx@latest"
go_install nuclei       "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
go_install katana       "github.com/projectdiscovery/katana/cmd/katana@latest"
go_install dnsx         "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"
go_install naabu        "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"
go_install notify       "github.com/projectdiscovery/notify/cmd/notify@latest"
go_install interactsh-client "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest"
go_install assetfinder  "github.com/tomnomnom/assetfinder@latest"
go_install waybackurls  "github.com/tomnomnom/waybackurls@latest"
go_install gau          "github.com/lc/gau/v2/cmd/gau@latest"
go_install unfurl       "github.com/tomnomnom/unfurl@latest"
go_install anew         "github.com/tomnomnom/anew@latest"
go_install qsreplace    "github.com/tomnomnom/qsreplace@latest"
go_install gf           "github.com/tomnomnom/gf@latest"
go_install ffuf         "github.com/ffuf/ffuf/v2@latest"
go_install gowitness    "github.com/sensepost/gowitness@latest"
go_install dalfox       "github.com/hahwul/dalfox/v2@latest"
go_install gospider     "github.com/jaeles-project/gospider@latest"
go_install amass        "github.com/owasp-amass/amass/v4/...@master"
go_install crlfuzz      "github.com/dwisiswant0/crlfuzz/cmd/crlfuzz@latest"

# gf patterns (used with the gf tool above)
if [[ ! -d "${HOME}/.gf" ]]; then
    log "Installing gf patterns..."
    git clone -q https://github.com/1ndianl33t/Gf-Patterns "${TOOLS_DIR}/Gf-Patterns" &>>"$LOGFILE"
    mkdir -p "${HOME}/.gf"
    cp "${TOOLS_DIR}/Gf-Patterns"/*.json "${HOME}/.gf/" 2>/dev/null
    ok "gf patterns installed."
fi

# ---------- 4. Python-based tools ----------
log "Installing Python-based tools..."
pip3 install --break-system-packages --upgrade pip &>>"$LOGFILE"

ALIASFILE="${HOME}/.bbht_aliases"
echo "# --- bug bounty helper aliases (generated by setup.sh) ---" > "$ALIASFILE"

clone_or_pull() {
    local name="$1" url="$2" dir="${TOOLS_DIR}/$3"
    if [[ -d "$dir" ]]; then
        ok "$name already present, pulling latest..."
        git -C "$dir" pull -q &>>"$LOGFILE"
    else
        log "Cloning $name..."
        if git clone -q "$url" "$dir" &>>"$LOGFILE"; then
            ok "$name cloned."
        else
            err "$name clone failed."
        fi
    fi
}

# Register a shell alias for a cloned (non-Go) tool so it's callable from
# anywhere once ~/.bbht_aliases is sourced.
# add_alias <alias-name> <absolute path to the script to run> [interpreter]
add_alias() {
    local name="$1" target="$2" interp="${3:-python3}"
    echo "alias ${name}='${interp} ${target}'" >> "$ALIASFILE"
}

# sqlmap (dev branch)
clone_or_pull "sqlmap-dev" "https://github.com/sqlmapproject/sqlmap.git" "sqlmap-dev"
add_alias "sqlmap" "${TOOLS_DIR}/sqlmap-dev/sqlmap.py"

# dirsearch
clone_or_pull "dirsearch" "https://github.com/maurosoria/dirsearch.git" "dirsearch"
pip3 install --break-system-packages -r "${TOOLS_DIR}/dirsearch/requirements.txt" &>>"$LOGFILE"
add_alias "dirsearch" "${TOOLS_DIR}/dirsearch/dirsearch.py"

# XSStrike
clone_or_pull "XSStrike" "https://github.com/s0md3v/XSStrike.git" "XSStrike"
pip3 install --break-system-packages -r "${TOOLS_DIR}/XSStrike/requirements.txt" &>>"$LOGFILE"
add_alias "xsstrike" "${TOOLS_DIR}/XSStrike/xsstrike.py"

# LinkFinder
clone_or_pull "LinkFinder" "https://github.com/GerbenJavado/LinkFinder.git" "LinkFinder"
pip3 install --break-system-packages -r "${TOOLS_DIR}/LinkFinder/requirements.txt" &>>"$LOGFILE"
(cd "${TOOLS_DIR}/LinkFinder" && python3 setup.py install &>>"$LOGFILE") 2>/dev/null
add_alias "linkfinder" "${TOOLS_DIR}/LinkFinder/linkfinder.py"

# corsy
clone_or_pull "Corsy" "https://github.com/s0md3v/Corsy.git" "Corsy"
pip3 install --break-system-packages -r "${TOOLS_DIR}/Corsy/requirements.txt" &>>"$LOGFILE"
add_alias "corsy" "${TOOLS_DIR}/Corsy/corsy.py"

ok "Python-based tools installed."

# EyeWitness (screenshotting / triage)
clone_or_pull "EyeWitness" "https://github.com/FortyNorthSecurity/EyeWitness.git" "EyeWitness"
EW_SETUP="${TOOLS_DIR}/EyeWitness/Python/setup/setup.sh"
EW_SCRIPT="${TOOLS_DIR}/EyeWitness/Python/EyeWitness.py"
EW_REQS="${TOOLS_DIR}/EyeWitness/Python/setup/requirements.txt"

if [[ -f "$EW_SETUP" ]]; then
    chmod +x "$EW_SETUP"
    log "Running EyeWitness's own setup.sh (installs firefox-esr, geckodriver, pip deps)..."
    # PIP_BREAK_SYSTEM_PACKAGES bypasses PEP 668's "externally-managed-
    # environment" error, which is what makes this vendor script fail out
    # of the box on Ubuntu 23.04+/24.04 — it calls plain `pip3 install`
    # internally with no --break-system-packages flag. `yes` auto-answers
    # any y/n prompt so the script can't hang in a non-interactive run.
    if (cd "$(dirname "$EW_SETUP")" \
        && { yes || true; } | $SUDO env PIP_BREAK_SYSTEM_PACKAGES=1 DEBIAN_FRONTEND=noninteractive ./setup.sh &>>"$LOGFILE"); then
        ok "EyeWitness setup.sh completed."
    else
        warn "EyeWitness setup.sh reported an error — check $LOGFILE"
    fi

    # The vendor script can exit 0 while still leaving a broken Python env,
    # so verify the actual import chain instead of trusting its exit code.
    if python3 -c "import selenium, netaddr" &>>"$LOGFILE"; then
        ok "EyeWitness Python dependencies verified."
    else
        warn "EyeWitness deps incomplete after setup.sh — installing requirements.txt directly as a fallback..."
        if [[ -f "$EW_REQS" ]]; then
            if pip3 install --break-system-packages -r "$EW_REQS" &>>"$LOGFILE"; then
                ok "EyeWitness fallback pip install completed."
            else
                err "EyeWitness fallback pip install failed — check $LOGFILE"
            fi
        else
            err "EyeWitness requirements.txt not found at $EW_REQS"
        fi
    fi
    add_alias "eyewitness" "$EW_SCRIPT"
else
    warn "EyeWitness setup script not found — repo layout may have changed."
fi

# ---------- 5. Ruby-based tools ----------
if ! command -v wpscan &>/dev/null; then
    log "Installing wpscan..."
    if $SUDO gem install wpscan &>>"$LOGFILE"; then
        ok "wpscan installed."
    else
        err "wpscan install failed."
    fi
else
    ok "wpscan already installed."
fi

# ---------- 6. Massdns ----------
if ! command -v massdns &>/dev/null; then
    log "Installing massdns..."
    git clone -q https://github.com/blechschmidt/massdns.git "${TOOLS_DIR}/massdns" &>>"$LOGFILE"
    if (cd "${TOOLS_DIR}/massdns" && make &>>"$LOGFILE" && $SUDO cp bin/massdns /usr/local/bin/); then
        ok "massdns installed."
    else
        err "massdns build failed."
    fi
else
    ok "massdns already installed."
fi

# ---------- 7. Wordlists ----------
if [[ ! -d "${TOOLS_DIR}/SecLists" ]]; then
    log "Cloning SecLists (this can take a while)..."
    git clone -q --depth 1 https://github.com/danielmiessler/SecLists.git "${TOOLS_DIR}/SecLists" &>>"$LOGFILE"
    ok "SecLists cloned to ${TOOLS_DIR}/SecLists"
else
    ok "SecLists already present."
fi

# nuclei-templates pulls itself on first run, but prime it anyway
if command -v nuclei &>/dev/null; then
    log "Updating nuclei templates..."
    nuclei -update-templates &>>"$LOGFILE"
    ok "nuclei templates updated."
fi

# ---------- 8. handy shortcut aliases (à la nahamsec/recon_profile) ----------
# The tool aliases (sqlmap, dirsearch, xsstrike, linkfinder, corsy,
# eyewitness) were already appended to $ALIASFILE as each tool was cloned
# above — these are just extra one-liner shortcuts for common recon chains.
cat >> "$ALIASFILE" << 'EOF'

# --- recon chain shortcuts ---
alias reconftw='echo "clone https://github.com/six2dez/reconftw if you want the full automation framework"'
alias subs='subfinder -silent -d'
alias livehosts='httpx -silent -status-code -title'
alias urls='gau --subs'
alias wayback='waybackurls'
alias xss='dalfox url'
EOF

if ! grep -q "bbht_aliases" "${HOME}/.bashrc"; then
    echo "source ${ALIASFILE}" >> "${HOME}/.bashrc"
fi
ok "Aliases written to ${ALIASFILE}"

# ---------- done ----------
echo
ok "Setup complete."
echo -e "${YELLOW}Run: source ~/.bashrc${NC}  (or open a new terminal) to load the aliases and Go's PATH."
echo

ok "Go-based tools (on \$HOME/go/bin once ~/.bashrc is sourced):"
for t in "${GO_TOOL_NAMES[@]}"; do
    if command -v "$t" &>/dev/null || [[ -x "${GOPATH_DIR}/bin/${t}" ]]; then
        echo -e "  ${GREEN}✓${NC} $t"
    else
        echo -e "  ${RED}✗${NC} $t  (failed — check $LOGFILE)"
    fi
done

echo
ok "Aliases (in ${ALIASFILE}, sourced from ~/.bashrc):"
grep '^alias ' "$ALIASFILE" | sed -E "s/^alias ([a-zA-Z0-9_]+)='(.*)'$/  \1  ->  \2/"
echo
echo -e "Tools cloned to: ${TOOLS_DIR}"
echo -e "Wordlists at:    ${TOOLS_DIR}/SecLists"
echo -e "Full log:        ${LOGFILE}"
