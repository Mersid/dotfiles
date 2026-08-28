# shellcheck shell=bash
# lib/btop.sh - btop installer with compiler-capability detection.
#
# Expects to be sourced by the init script, which provides:
#   apt_install()  - apt-get wrapper
#   SRC_DIR        - where to clone ($HOME/.localbin)
#   BTOP_REF       - git ref to build (falls back to "main")
#
# Exit-status contract: install_btop returns non-zero on any failure.

: "${BTOP_MIN_GCC:=14}" # btop 1.4.x needs libstdc++ >= 14.1 (std::ranges::to)

# _gcc_major <binary> -> prints major version ("14"), or nothing on failure
function _gcc_major() {
    "$1" -dumpfullversion -dumpversion 2>/dev/null | cut -d. -f1
}

# _gcc_ge <binary> <major> -> 0 if <binary> exists and its major version >= <major>
function _gcc_ge() {
    local m
    m="$(_gcc_major "$1")"
    [[ $m =~ ^[0-9]+$ ]] && (( m >= $2 ))
}

# Toolchain-independent fallback: official static musl build from upstream.
function _btop_install_static() {
    local machine arch tmp rc=0 bin
    machine="$(uname -m)"
    case "$machine" in
        x86_64)        arch="x86_64-unknown" ;;
        aarch64|arm64) arch="aarch64-unknown" ;;
        *) echo "install_btop: no static btop build for $machine" >&2; return 1 ;;
    esac
    tmp="$(mktemp -d)" || return 1
    curl -fLo "$tmp/btop.tar.gz" \
        "https://github.com/aristocratos/btop/releases/latest/download/btop-${arch}-linux-musl.tar.gz" \
    && tar -xzf "$tmp/btop.tar.gz" -C "$tmp" \
    && bin="$(find "$tmp" -type f -name btop -print -quit)" \
    && sudo install -m 0755 "$bin" /usr/local/bin/btop \
    || rc=$?
    rm -rf "$tmp"
    return "$rc"
}

# Build btop from source with a capable compiler; on Ubuntu 22.04 (or anywhere
# without GCC >= 14 available), fall back to the official static binary.
function install_btop() {
    : "${BTOP_REF:=main}"

    local os_id="" os_ver=""
    if [[ -r /etc/os-release ]]; then
        os_id="$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"')"
        os_ver="$(sed -n 's/^VERSION_ID=//p' /etc/os-release | tr -d '"')"
        os_ver="${os_ver%%.*}"
    fi

    # Prefer the default g++ if capable, else try versioned ones from apt.
    local cxx="g++" cc="gcc" v
    if ! _gcc_ge g++ "$BTOP_MIN_GCC"; then
        for v in "$BTOP_MIN_GCC" $((BTOP_MIN_GCC + 1)) $((BTOP_MIN_GCC + 2)); do
            # Exact-name precheck: apt-get install otherwise falls back to
            # regex matching on missing packages (the 'clang-14 for regex
            # g++-14' noise) and errors on every miss.
            if apt-cache pkgnames "g++-$v" 2>/dev/null | grep -qxF "g++-$v" \
               && apt_install "g++-$v" "gcc-$v" \
               && _gcc_ge "g++-$v" "$BTOP_MIN_GCC"; then
                cxx="g++-$v"; cc="gcc-$v"
                break
            fi
        done
    fi

    # Known dead end: 22.04's repos and the toolchain PPA stop at g++-13.
    if [[ $os_id == "ubuntu" && $os_ver == "22" ]] && ! _gcc_ge "$cxx" "$BTOP_MIN_GCC"; then
        echo "install_btop: Ubuntu 22.04 cannot provide GCC >= $BTOP_MIN_GCC; using static binary" >&2
        _btop_install_static
        return
    fi
    if ! _gcc_ge "$cxx" "$BTOP_MIN_GCC"; then
        echo "install_btop: no GCC >= $BTOP_MIN_GCC available; falling back to static binary" >&2
        _btop_install_static
        return
    fi

    # cmake is not needed (btop uses plain make).
    apt_install make git || return

    cd "$SRC_DIR" || return
    rm -rf btop
    git clone --depth 1 --recursive --branch "$BTOP_REF" \
        https://github.com/aristocratos/btop || return

    make -C btop CXX="$cxx" CC="$cc" -j"$(nproc)" &&
        sudo make -C btop install
}