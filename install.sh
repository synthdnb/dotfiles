#!/usr/bin/env bash
# Preflight checks, symlink dotfiles into $HOME, set up mise, install Homebrew
# packages (+ fzf, moon, tpm), then apply macOS defaults.
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
# fzf key-bindings + completion -> generates ~/.fzf.zsh and ~/.fzf.bash (sourced by .zshrc/.bashrc)
fzf_install="$(brew --prefix)/opt/fzf/install"
if [ -x "$fzf_install" ]; then
  "$fzf_install" --key-bindings --completion --no-update-rc
fi

# moon — not available via Homebrew (installs to ~/.moon/bin, which .zshrc adds to PATH)
if [ ! -x "$HOME/.moon/bin/moon" ]; then
  curl -fsSL https://moonrepo.dev/install/moon.sh | bash || echo "moon install failed — see https://moonrepo.dev/docs/install"
fi

# tmux plugin manager (after this: open tmux, press prefix + I to install plugins)
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

# macOS defaults
[ -f "$DOTFILES/osx.sh" ] && bash "$DOTFILES/osx.sh"

echo
echo "Done. Secrets are NOT tracked — create ~/.zsh_secrets for API keys/tokens."
echo "(.zshrc sources it automatically if present.)"
