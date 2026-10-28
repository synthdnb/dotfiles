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
existing real file is moved to `*.bak`), sets up mise, runs `brew bundle`,
bootstraps fisher (fish plugins), registers fish in `/etc/shells` and runs
`chsh` to make it the login shell (prompts for your password), and applies
`osx.sh`. The mise and fzf/tpm/moon steps are described below.

## What's here

| File | Purpose |
|------|---------|
| `.config/fish/config.fish` `.config/fish/fish_plugins` | shell (fish, the login shell) + fisher plugin list |
| `.config/starship.toml` | Starship prompt |
| `.zshrc` `.zprofile` `.bashrc` | shell (zsh kept as fallback / for non-interactive & agent shells) |
| `.p10k.zsh` | Powerlevel10k prompt (zsh fallback only) |
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
your terminal font to **MesloLGS NF** — the Nerd Font is still needed for the
Starship (and Powerlevel10k) glyphs.

## fish notes

- The oh-my-zsh git aliases (`gst`, `gco`, `gp`, `glog`, …) come from
  `jhillyerd/plugin-git` as abbreviations — they expand in place when you press space.
- Autosuggestions and syntax highlighting are built into fish (no plugins).
- Up-arrow with text typed searches history for commands *containing* it
  (substring, like zsh-history-substring-search); `ctrl-r` is fzf history search.
- POSIX `source` snippets (`export FOO=bar`, `eval "$(tool init zsh)"`) need
  translating to fish (`set -gx FOO bar`, `tool init fish | source`).
- The zoxide, fzf, and starship `init` scripts are cached in
  `~/.cache/fish/init.fish`. The cache is rebuilt automatically when a tool's path
  or binary changes (a `brew upgrade` moves it to a new Cellar version); run
  `rm ~/.cache/fish/init.fish` to force a rebuild.
- `install.sh` sets `MISE_FISH_AUTO_ACTIVATE=0` as a universal variable, which
  turns off Homebrew's mise snippet, so mise activates once, from `config.fish`.

## Secrets

Secrets are **never** tracked. Both shells read one shared dotenv-style file,
`~/.config/secrets.env`, if it exists — `.zshrc` sources it with `set -a`, and
`config.fish` parses it with fish builtins (no extra tools). Put API keys/tokens
there, create it by hand on each machine, and keep it private
(`chmod 600 ~/.config/secrets.env`).

Format: one `KEY=value` per line, no `export`; `#` comments and blank lines are
allowed; wrap values containing spaces, `$`, or backslashes in single quotes.
Don't use double quotes or trailing `# comments` on a value line: zsh executes
the file as shell code while fish reads it as plain text, so only bare and
single-quoted values behave the same in both.

```sh
OPENAI_API_KEY=sk-placeholder
EXAMPLE_PASSPHRASE='placeholder with spaces'
```
