# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

### PATH Configuration
path=(
  ~/.bin
  ~/.local/bin
  ~/go/bin
  ~/.moon/bin
  $path
)
export PATH

### End of PATH Configuration


### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit
### End of Zinit's installer chunk

### Zinit plugins
zinit snippet OMZL::git.zsh
zinit snippet OMZP::git
zinit ice depth=1; zinit light romkatv/powerlevel10k

zinit light zsh-users/zsh-autosuggestions
zinit light zdharma-continuum/fast-syntax-highlighting
zinit light zsh-users/zsh-history-substring-search
zinit light zsh-users/zsh-completions

### End of Zinit plugins

setopt auto_cd histignorealldups sharehistory
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'


## lscolors
autoload -U colors && colors
export LSCOLORS="Gxfxcxdxbxegedxbagxcad"
export LS_COLORS="di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=0;41:sg=30;46:tw=0;42:ow=30;43"
export TIME_STYLE='long-iso'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
alias ls='ls -G'
alias mx='moon run'
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"


### Aliases

# git language
alias git='LANG=en_US git'

# neovim
alias vim='nvim'
alias vi='nvim'
alias wm='workmux'

alias tf="terraform"
alias ccb='claude --permission-mode=bypassPermissions'
alias cdb='codex --dangerously-bypass-approvals-and-sandbox'

### End of Aliases



[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

### VSCode
[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"
###


slug(){
	cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w $1 | head -n 1
}

hotspot_enable(){
	sudo networksetup -setmanual Wi-Fi 172.20.10.3 255.255.255.240 172.20.10.1
}

hotspot_disable(){
	sudo networksetup -setdhcp Wi-Fi
}

command -v mise >/dev/null && eval "$(mise activate zsh)"
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"  # z = jump to dir, zi = interactive
alias x='tar --zstd -xvf'

# The next line updates PATH for Nebius CLI.
if [ -f '/Users/marshall/.nebius/path.zsh.inc' ]; then source '/Users/marshall/.nebius/path.zsh.inc'; fi
export EDITOR='nvim'
bindkey -e

# pnpm
export PNPM_HOME="/Users/marshall/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Load secrets (API keys, tokens, etc.)
[[ -f ~/.zsh_secrets ]] && source ~/.zsh_secrets

# Clear Claude Code notification when opening new shell in tmux
[[ -n "$TMUX_PANE" ]] && ~/.local/bin/claude-clear-notify 2>/dev/null

export CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN=1
