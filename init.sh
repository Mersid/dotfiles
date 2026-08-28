#!/usr/bin/env bash

# References: 4f1a8c2c-ad49-4d1c-acb1-a98e2f9a657b

# --------------------------------------------- C O N F I G U R A T I O N ----------------------------------------------

set -uo pipefail # Avoids issues like mistyped variables resulting in empty strings instead of error.

# Full path to the directory of the init script. Does not contain trailing slash.
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$HOME/.localbin" # For source-compiled stuff.

# Pinned version tags.
# shellcheck disable=SC2034 # Consumed inside lib/btop.sh.
BTOP_REF="v1.4.7" # https://github.com/aristocratos/btop/releases
NEOVIM_REF="stable" # neovim's "stable" branch = latest release; master can break

# Set whether to skip prompts with default yes.
ASSUME_DEFAULT=0

# If first argument is "--yes", install everything without confirmation.
[[ ${1:-} == "--yes" ]] && ASSUME_DEFAULT=1

FAILED=()
STEPS=() # struct: "name:function"

# --------------------------------------------------- I M P O R T S ----------------------------------------------------

# shellcheck source=lib/btop.sh
. "$REPO_DIR/lib/btop.sh" # btop helpers; defines install_btop()

# ------------------------------------------------- F U N C T I O N S --------------------------------------------------

# Prompt the user for a yes or no answer.
# $1: The string to display to the user
# $2: 1 for default yes, 0 for default no (default: 1)
# $?: 0 if yes, 1 if no (conventional shell exit codes: 0 = affirmative)
#
# If ASSUME_DEFAULT=1 (script run with --yes), no prompt is shown and
# the default answer is used for every question.
function prompt() {
    local reply
    if [[ $ASSUME_DEFAULT -eq 1 ]]; then return $(( ! ${2:-1} )); fi
    read -rp "$1" reply
    case $reply in
        [Yy]*) return 0 ;;
        [Nn]*) return 1 ;;
        *)     return $(( ! ${2:-1} )) ;;
    esac
}

# Run a single installation step by name.
# $1: The human-readable step name (shown in output and in the failure summary)
# $2...: The command to run, with its arguments (e.g. step "btop" install_btop)
#
# The command's stdout/stderr pass through normally so you see live progress.
# A step that exits non-zero is recorded in FAILED[] but does NOT abort the
# script - remaining steps still run. A summary of failed steps is printed at
# the end and the script exits 1, so failures are always visible when it's done.
function step() {
    local name=$1; shift
    printf '\n\033[1m==> %s\033[0m\n' "$name"
    if "$@"; then
        printf '    \033[32mok\033[0m\n'
    else
        printf '    \033[31mFAILED\033[0m\n' >&2
        FAILED+=("$name")
    fi
}

# Arguments are passed into `apt-get`. `-y` comes gratis.
function apt_install() {
    # Don't show purple prompt to restart services
    sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
}

# Asks the user and logs a step, if accepted.
#
# $1: The prompt text.
# $2: The step name to register.
# $3: The function to execute.
# $4: The default value. Leave blank or 1 for yes, or 0 for default no.
function ask() {
    prompt "$1" "${4:-1}" && STEPS+=("$2:$3")
}

# ----------------------------------------------------- S T E P S ------------------------------------------------------

# Note: The exit status of a function is the exit status of its last command.

function system_update() {
    sudo env DEBIAN_FRONTEND=noninteractive apt-get update \
        && sudo env DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y
}

# Historically part of the baseline (fresh 22.04 installs, 2022): snapd was
# purged to keep the system deb-only. Now opt-in only, because purging snapd
# removes snap-packaged apps (Firefox, Chromium) and may be silently reversed
# by later installs that depend on it.
function remove_snapd() {
    sudo env DEBIAN_FRONTEND=noninteractive apt-get purge -y snapd \
        && sudo env DEBIAN_FRONTEND=noninteractive apt-get autopurge -y
}

function install_neovim() {
    # `-C` flag moves into directory before acting. Less prone to nuking directories if something fails.
    apt_install ninja-build gettext cmake unzip curl git \
        && cd "$SRC_DIR" \
        && rm -rf neovim \
        && git clone --depth 1 --branch "$NEOVIM_REF" https://github.com/neovim/neovim \
        && make -C neovim CMAKE_BUILD_TYPE=RelWithDebInfo \
        && sudo make -C neovim install
}

function install_rust() {
    # Non-interactive install rustup
    # Add cargo env, otherwise it won't work until shell restart
    # shellcheck disable=SC1091
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
        && . "$HOME/.cargo/env"
}

function install_zoxide() {
    cargo install --locked zoxide # crates.io, no clone
}
function install_lsd() {
    cargo install --locked --git https://github.com/Mersid/lsd # TODO: Track this via tags or something.
}

function install_nala() {
    apt_install nala \
        && sudo sed -i "s/scrolling_text = true/scrolling_text = false/g" /etc/nala/nala.conf
}

function install_bat() {
    apt_install bat
}

# Like `df`, but better.
function install_duf() {
    apt_install duf
}

# Back up files. Doesn't touch symlinks.
function backup_if_real() {
    local p=$1
    if [[ -e $p && ! -L $p ]]; then
        mv -v "$p" "$p.bak.$(date +%Y%m%d-%H%M%S)"
    fi
}

function link_configs() {
    mkdir -p "$HOME/.config" || return 1
    local name
    for name in btop nvim tmux; do
        backup_if_real "$HOME/.config/$name" && ln -sfn "$REPO_DIR/.config/$name" "$HOME/.config/$name"
    done
    backup_if_real "$HOME/.vimrc" && ln -sfn "$REPO_DIR/.vimrc" "$HOME/.vimrc"
}

function link_bashrc() {
    local hook=". $REPO_DIR/.bashrc"

    # If the line is not in the .bashrc file, then we append it to the end of the file.
    # Don't add the line manually into an if-block in the .bashrc file, since this grep will
    # find it and leave it, but if the if block doesn't run, .bashrc will never be sourced.
    # In short, just let this script handle it.
    if ! grep -qF "$hook" "$HOME/.bashrc"; then
        printf '\n%s\n' "$hook" >> "$HOME/.bashrc"
    fi
}

# ------------------------------------------------ R U N   S C R I P T -------------------------------------------------

if prompt "Do you want to install any tools? Doing so will require root privileges. [Y/n] " 1; then
    ask "System update + full upgrade? [Y/n] " "system update" system_update
    ask "Install btop? [Y/n] " "btop" install_btop
    ask "Install neovim? [Y/n] " "neovim" install_neovim
    ask "Install nala? [Y/n] " "nala" install_nala
    ask "Install bat? [Y/n] " "bat" install_bat
    ask "Install duf? [Y/n] " "duf" install_duf
    ask "Remove snapd and all snap apps? [y/N] " "remove snapd" remove_snapd 0

    if ask "Install Rust toolchain? [Y/n] " "rust" install_rust; then
        ask "Install lsd? [Y/n] " "lsd" install_lsd
        ask "Install zoxide? [Y/n] " "zoxide" install_zoxide
    fi
fi

ask "Link .bashrc hook? [Y/n] " "bashrc hook" link_bashrc
ask "Link config files? [Y/n] " "config symlinks" link_configs

if ((${#STEPS[@]} == 0)); then
    echo "Nothing selected. Exiting."
    exit 0
fi

echo
echo "The following steps will run:"
for entry in "${STEPS[@]}"; do
    printf '  * %s\n' "${entry%%:*}"
done
echo

if ! prompt "Proceed with installation? [Y/n] " 1; then
    echo "Exiting. Nothing was modified."
    exit 0
fi

mkdir -p "$SRC_DIR"

for entry in "${STEPS[@]}"; do
    step "${entry%%:*}" "${entry#*:}"
done

echo
if ((${#FAILED[@]})); then
    printf 'Finished with %d failed step(s): %s\n' "${#FAILED[@]}" "${FAILED[*]}" >&2
    exit 1
fi
echo "All done - no failures."
echo "Note: aliases and shell settings take effect in new shells, or run 'exec bash' to reload this one."