# bash is not the interactive shell (fish is; zsh is the fallback), but it is
# the login shell until chsh runs, and agent/non-interactive shells use it.
# Linux: system-wide defaults (Amazon Linux's stock ~/.bashrc sourced this).
[ -f /etc/bashrc ] && . /etc/bashrc

# Same PATH entries as .zshrc / config.fish, so mise-managed tools resolve here too.
for d in "$HOME/.local/share/mise/shims" "$HOME/.moon/bin" "$HOME/go/bin" "$HOME/.local/bin" "$HOME/.bin"; do
  case ":$PATH:" in *":$d:"*) ;; *) [ -d "$d" ] && PATH="$d:$PATH" ;; esac
done
export PATH

# fzf key-bindings: ~/.fzf.bash is written by Homebrew's fzf installer (macOS);
# on Linux fzf comes from mise and prints its own init.
if [ -f ~/.fzf.bash ]; then
  source ~/.fzf.bash
elif [[ $- == *i* ]] && command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --bash)"
fi

. "$HOME/.moon/bin/env"
