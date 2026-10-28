#!/usr/bin/env bash
# Preflight checks, symlink dotfiles into $HOME, set up mise, install Homebrew
# packages (+ fzf, fish/starship + fisher plugins, moon, tpm), make fish the
# login shell, then apply macOS defaults.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() { # link <path-relative-to-repo> <absolute-dest>
  local src="$DOTFILES/$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    mv "$dest" "$dest.bak"
    echo "backed up existing $dest -> $dest.bak"
  fi
  ln -sfn "$src" "$dest"
  echo "linked $dest"
}

# Verify prerequisites BEFORE touching $HOME — abort with actionable messages.
preflight() {
  local missing=0
  if [ "$(uname)" != "Darwin" ]; then
    echo "✗ requires macOS (found $(uname))"; missing=1
  fi
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "✗ Xcode Command Line Tools — run: xcode-select --install"; missing=1
  fi
  if ! command -v brew >/dev/null 2>&1; then
    echo "✗ Homebrew — install: https://brew.sh"; missing=1
  fi
  for cmd in git curl; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "✗ $cmd not found on PATH"; missing=1; }
  done
  if [ "$missing" -ne 0 ]; then
    echo
    echo "Resolve the above, then re-run ./install.sh"
    exit 1
  fi
  echo "✓ prerequisites OK"
}

preflight

# Root dotfiles -> ~/
for f in .zshrc .zprofile .bashrc .tmux.conf \
         .p10k.zsh .gitconfig .gitignore; do
  link "$f" "$HOME/$f"
done

# App configs (linked per-file so other ~/.config contents are untouched)
link .config/nvim/init.lua       "$HOME/.config/nvim/init.lua"
link .config/htop/htoprc         "$HOME/.config/htop/htoprc"
link .config/workmux/config.yaml "$HOME/.config/workmux/config.yaml"
link .config/mise/config.toml    "$HOME/.config/mise/config.toml"
link .config/fish/config.fish    "$HOME/.config/fish/config.fish"
link .config/fish/fish_plugins   "$HOME/.config/fish/fish_plugins"
link .config/starship.toml       "$HOME/.config/starship.toml"

# Install the global tool versions (Node/Go/Python/Ruby) from the mise config.
# Ruby uses precompiled binaries (ruby.compile=false), so no slow source build.
command -v mise >/dev/null 2>&1 || brew install mise
mise install                          # tools per ~/.config/mise/config.toml (linked above)

# Homebrew packages (brew is guaranteed by preflight)
brew bundle --file="$DOTFILES/Brewfile"
# Private/host-specific packages (untracked; e.g. internal tooling)
if [ -f "$DOTFILES/Brewfile.local" ]; then
  brew bundle --file="$DOTFILES/Brewfile.local"
fi
# fzf key-bindings + completion -> generates ~/.fzf.zsh and ~/.fzf.bash (sourced by .zshrc/.bashrc).
# fish needs neither: config.fish caches the `fzf --fish` init (rebuilt when fzf is upgraded).
fzf_install="$(brew --prefix)/opt/fzf/install"
if [ -x "$fzf_install" ]; then
  "$fzf_install" --key-bindings --completion --no-update-rc
fi

# fish: fisher plugin manager + the plugins in .config/fish/fish_plugins (linked above),
# tool completions fish does not ship, then make fish the login shell (zsh stays installed).
fish_bin="$(brew --prefix)/bin/fish"
if [ -x "$fish_bin" ]; then
  mkdir -p "$HOME/.config/fish/completions"
  # </dev/null: fisher reads plugin names from stdin when it is not a tty and would hang under a pipe
  "$fish_bin" -c 'functions -q fisher; or curl -fsL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source; fisher update' </dev/null \
    || echo "fisher setup failed — see https://github.com/jorgebucaran/fisher"
  # Homebrew's fish vendor snippet would run `mise activate` (a 221 MB process at
  # every shell start and prompt); config.fish uses mise's shims instead, so turn
  # the vendor snippet off. Universal variable: it must exist before conf.d runs.
  "$fish_bin" -c 'set -U MISE_FISH_AUTO_ACTIVATE 0'
  for tool in rex kubectl; do
    if command -v "$tool" >/dev/null 2>&1; then
      out="$HOME/.config/fish/completions/$tool.fish"
      "$tool" completion fish > "$out" || { rm -f "$out"; echo "$tool completion fish failed — skipped"; }
    fi
  done
  # Login shell: /etc/shells needs sudo, chsh asks for the password. Neither failure aborts the script.
  grep -qxF "$fish_bin" /etc/shells || echo "$fish_bin" | sudo tee -a /etc/shells >/dev/null \
    || echo "could not add fish to /etc/shells — run: echo $fish_bin | sudo tee -a /etc/shells"
  # dscl, not $SHELL: $SHELL still says zsh until the next login, which would re-prompt on every run.
  login_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
  [ "$login_shell" = "$fish_bin" ] || chsh -s "$fish_bin" || echo "chsh failed — run: chsh -s $fish_bin"
fi

# moon — not available via Homebrew (installs to ~/.moon/bin, which .zshrc adds to PATH)
if [ ! -x "$HOME/.moon/bin/moon" ]; then
  curl -fsSL https://moonrepo.dev/install/moon.sh | bash || echo "moon install failed — see https://moonrepo.dev/docs/install"
fi

# Claude Code — self-updating native binary (replaces the old npm install); -> ~/.local/bin
if ! command -v claude >/dev/null 2>&1; then
  curl -fsSL https://claude.ai/install.sh | bash || echo "Claude Code install failed — see https://code.claude.com/docs"
fi

# Codex CLI — official standalone installer (https://developers.openai.com/codex/cli)
if ! command -v codex >/dev/null 2>&1; then
  curl -fsSL https://chatgpt.com/codex/install.sh | CODEX_NON_INTERACTIVE=1 sh || echo "Codex install failed — see https://developers.openai.com/codex/cli"
fi

# tmux plugin manager (after this: open tmux, press prefix + I to install plugins)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# macOS defaults
[ -f "$DOTFILES/osx.sh" ] && bash "$DOTFILES/osx.sh"

echo
echo "Done. Secrets are NOT tracked — put API keys/tokens in ~/.config/secrets.env (KEY=value, read by zsh and fish)."
echo "fish is now the login shell — open a new terminal."
