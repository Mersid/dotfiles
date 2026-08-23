# dotfiles

Managed with [chezmoi](https://chezmoi.io/). Targets Debian/Ubuntu-ish Linux
boxes.

## New machine

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply Mersid
```

`init --apply` clones this repo to `~/.local/share/chezmoi` and applies the
dotfiles to the home directory. Afterwards, `provision.sh` can be run
interactively to install/build the optional tools (btop, neovim, lsd, zoxide,
nala, bat, duf); it no longer touches any dotfiles.

## Day to day

```sh
chezmoi update        # git pull + apply on this machine
chezmoi status        # drift in both directions
chezmoi diff          # what `apply` would change
chezmoi add <file>    # start managing a new file
chezmoi re-add        # pull live edits back into the source repo
chezmoi cd            # shell in the source repo (git commit/push from here)
```

`git.autoCommit`/`git.autoPush` are intentionally not enabled; commits stay
explicit.

## Layout

| Source | Target |
|---|---|
| `dot_bashrc.local` | `~/.bashrc.local` |
| `modify_dot_bashrc` | injects a source-line into `~/.bashrc`, preserving existing contents |
| `dot_vimrc` | `~/.vimrc` |
| `dot_config/` | `~/.config/` (btop, nvim, tmux) |

The `.bashrc` hook is the same approach as the old `init.sh`: the distro
`~/.bashrc` is left intact and gains one guarded line that sources
`~/.bashrc.local`.
