#!/usr/bin/env bash
# Preflight checks, symlink dotfiles into $HOME, set up mise, install packages
# (Homebrew on macOS; dnf + mise on Amazon Linux / Fedora-family Linux), fzf,
# fish + fisher plugins, moon, tpm, make fish the login shell, then apply macOS
# defaults (macOS only).
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s)"   # Darwin | Linux

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
  case "$OS" in
    Darwin)
      if ! xcode-select -p >/dev/null 2>&1; then
        echo "✗ Xcode Command Line Tools — run: xcode-select --install"; missing=1
      fi
      if ! command -v brew >/dev/null 2>&1; then
        echo "✗ Homebrew — install: https://brew.sh"; missing=1
      fi
      ;;
    Linux)
      # Amazon Linux 2023 / Fedora family: system packages come from dnf, the
      # rest (fish, fzf, starship, …) from GitHub releases via mise.
      if ! command -v dnf >/dev/null 2>&1; then
        echo "✗ dnf not found — only Amazon Linux / Fedora-family Linux is supported"; missing=1
      fi
      if ! command -v sudo >/dev/null 2>&1; then
        echo "✗ sudo not found (needed for dnf, /etc/shells, chsh)"; missing=1
      fi
      ;;
    *)
      echo "✗ unsupported OS: $OS"; missing=1
      ;;
  esac
  for cmd in git curl tar; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "✗ $cmd not found on PATH"; missing=1; }
  done
  if [ "$missing" -ne 0 ]; then
    echo
    echo "Resolve the above, then re-run ./install.sh"
    exit 1
  fi
  echo "✓ prerequisites OK ($OS)"
}

# Linux: fish is not packaged for Amazon Linux 2023, and a mise shim is a poor
# login shell (it re-execs mise on every login). Install the official static
# build from GitHub releases into /usr/local/bin instead.
install_fish_linux() {
  local arch tag url tmp
  case "$(uname -m)" in
    aarch64|arm64) arch=aarch64 ;;
    x86_64)        arch=x86_64 ;;
    *) echo "no static fish build for $(uname -m) — skipping fish"; return 1 ;;
  esac
  tag="$(curl -fsSL https://api.github.com/repos/fish-shell/fish-shell/releases/latest | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p')"
  [ -n "$tag" ] || { echo "could not resolve latest fish release — skipping fish"; return 1; }
  if [ -x /usr/local/bin/fish ] && [ "$(/usr/local/bin/fish --version | awk '{print $3}')" = "$tag" ]; then
    echo "fish $tag already installed"; return 0
  fi
  url="https://github.com/fish-shell/fish-shell/releases/download/$tag/fish-$tag-linux-$arch.tar.xz"
  tmp="$(mktemp -d)"
  echo "installing fish $tag from $url"
  curl -fsSL "$url" | tar -xJ -C "$tmp"
  # The static tarball ships only `fish` (functions/completions are embedded); install what is there.
  for bin in fish fish_indent fish_key_reader; do
    [ -f "$tmp/$bin" ] && sudo install -m 755 "$tmp/$bin" /usr/local/bin/
  done
  rm -rf "$tmp"
}

preflight

# Root dotfiles -> ~/
for f in .zshrc .zprofile .bashrc .tmux.conf \
         .p10k.zsh .gitconfig .gitignore; do
  link "$f" "$HOME/$f"
done
# OS-specific git settings, included by .gitconfig (GitHub transport, gh credential helper path)
if [ "$OS" = Darwin ]; then link .gitconfig.macos "$HOME/.gitconfig.os"; else link .gitconfig.linux "$HOME/.gitconfig.os"; fi

# App configs (linked per-file so other ~/.config contents are untouched)
link .config/nvim/init.lua       "$HOME/.config/nvim/init.lua"
link .config/htop/htoprc         "$HOME/.config/htop/htoprc"
link .config/workmux/config.yaml "$HOME/.config/workmux/config.yaml"
link .config/mise/config.toml    "$HOME/.config/mise/config.toml"
link .config/fish/config.fish    "$HOME/.config/fish/config.fish"
link .config/fish/fish_plugins   "$HOME/.config/fish/fish_plugins"
link .config/starship.toml       "$HOME/.config/starship.toml"

# System packages first: on Linux mise's Ruby/Python builds and `rust` need a C toolchain.
if [ "$OS" = Linux ]; then
  # Counterparts of the Brewfile entries that dnf carries; everything else is in
  # .config/mise/config.toml with os = ["linux"]. util-linux-user provides chsh.
  # libatomic: mise's node binary links against it and AL2023 does not ship it by default.
  sudo dnf install -y -q tmux zsh htop automake gcc make wget jq git tar xz libatomic \
    util-linux-user java-11-amazon-corretto-devel
fi

# Install the global tool versions (Node/Go/Python/Ruby) from the mise config.
# Ruby uses precompiled binaries (ruby.compile=false), so no slow source build.
if ! command -v mise >/dev/null 2>&1; then
  if [ "$OS" = Darwin ]; then
    brew install mise
  else
    curl -fsSL https://mise.run | sh     # -> ~/.local/bin/mise
    export PATH="$HOME/.local/bin:$PATH"
  fi
fi
mise install --yes                    # tools per ~/.config/mise/config.toml (linked above)
export PATH="$HOME/.local/share/mise/shims:$PATH"   # fzf/starship/… below come from here on Linux

if [ "$OS" = Darwin ]; then
  # Homebrew packages (brew is guaranteed by preflight)
  brew bundle --file="$DOTFILES/Brewfile"
  # Private/host-specific packages (untracked; e.g. internal tooling)
  if [ -f "$DOTFILES/Brewfile.local" ]; then
    brew bundle --file="$DOTFILES/Brewfile.local"
  fi
  # fzf key-bindings + completion -> generates ~/.fzf.zsh and ~/.fzf.bash (sourced by .zshrc/.bashrc).
  # fish needs neither: config.fish caches the `fzf --fish` init (rebuilt when fzf is upgraded).
  # On Linux fzf comes from mise and .zshrc/.bashrc fall back to `fzf --zsh` / `fzf --bash`.
  fzf_install="$(brew --prefix)/opt/fzf/install"
  if [ -x "$fzf_install" ]; then
    "$fzf_install" --key-bindings --completion --no-update-rc
  fi
  fish_bin="$(brew --prefix)/bin/fish"
else
  install_fish_linux || true
  fish_bin=/usr/local/bin/fish
fi

# fish: fisher plugin manager + the plugins in .config/fish/fish_plugins (linked above),
# tool completions fish does not ship, then make fish the login shell (zsh stays installed).
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
  # Not $SHELL: it still says the old shell until the next login, which would re-prompt on every run.
  if [ "$OS" = Darwin ]; then
    login_shell="$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')"
    [ "$login_shell" = "$fish_bin" ] || chsh -s "$fish_bin" || echo "chsh failed — run: chsh -s $fish_bin"
  else
    # Linux chsh authenticates with the user's password through PAM, which has no tty here; go through sudo.
    login_shell="$(getent passwd "$USER" | cut -d: -f7)"
    [ "$login_shell" = "$fish_bin" ] || sudo chsh -s "$fish_bin" "$USER" || echo "chsh failed — run: sudo chsh -s $fish_bin $USER"
  fi
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
[ "$OS" = Darwin ] && [ -f "$DOTFILES/osx.sh" ] && bash "$DOTFILES/osx.sh"

echo
echo "Done. Secrets are NOT tracked — put API keys/tokens in ~/.config/secrets.env (KEY=value, read by zsh and fish)."
echo "fish is now the login shell — open a new terminal."
