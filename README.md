# dotfiles

Personal macOS setup.

**Fresh Mac, one command** — installs Homebrew (which brings git), clones, and runs `install.sh`:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/synthdnb/dotfiles/main/bootstrap.sh)"
```

Already have git? Clone and run:

```sh
git clone https://github.com/synthdnb/dotfiles.git ~/ws/dotfiles && cd ~/ws/dotfiles && ./install.sh
```

`install.sh` runs a preflight check, symlinks the configs into `$HOME` (any
existing real file is moved to `*.bak`), sets up mise, runs `brew bundle`, and
applies `osx.sh`. The mise and fzf/tpm/moon steps are described below.

## What's here

| File | Purpose |
|------|---------|
| `.zshrc` `.zprofile` `.bashrc` | shell |
| `.p10k.zsh` | Powerlevel10k prompt |
| `.tmux.conf` | tmux multiplexer |
| `.config/nvim/init.lua` | editor |
| `.gitconfig` `.gitignore` | git (global) |
| `.config/htop/htoprc` `.config/workmux/config.yaml` | app configs |
| `.config/mise/config.toml` | mise tool versions (node/go/python/ruby) + settings |
| `Brewfile` | `brew bundle` package list (regenerate: `brew bundle dump --force`) |
| `osx.sh` | macOS `defaults write` tweaks |

`install.sh` also runs the fzf key-binding installer, clones tpm, and installs
moon, Claude Code, and Codex (self-updating native binaries) — none of which `brew bundle` handles.

Node, Go, Python, and Ruby are managed by **mise** (`.config/mise/config.toml`).
`install.sh` runs `mise install` and puts mise's shims on PATH *before* `brew
bundle`, so the Brewfile's `npm "..."` / `go "..."` entries resolve against them.
Ruby installs as a precompiled binary (`ruby.compile=false`) — no source build.

## Prerequisites — install these *before* `./install.sh`

`install.sh` runs a preflight check and aborts unless both are present:

```sh
# Xcode Command Line Tools (Homebrew, git, and compilers need it)
xcode-select --install

# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## Apps & tools not in the Brewfile

`install.sh` doesn't install these — run the ones you need by hand:

```sh
# Nebius CLI (optional) — .zshrc sources ~/.nebius/path.zsh.inc if present
curl -sSL https://storage.eu-north1.nebius.cloud/cli/install.sh | bash
```

After install: open tmux and press `prefix + I` to fetch tmux plugins, and set
your terminal font to **MesloLGS NF** for the Powerlevel10k glyphs.

## Secrets

Secrets are **never** tracked. `.zshrc` sources `~/.zsh_secrets` if it exists —
put API keys/tokens there. Create it by hand on each machine.
