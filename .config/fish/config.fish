# fish counterpart of .zshrc + .zprofile.
# Symlinked to ~/.config/fish/config.fish by install.sh.

### Environment (runs for non-interactive fish too)
/opt/homebrew/bin/brew shellenv | source # was .zprofile
set -gx LSCOLORS Gxfxcxdxbxegedxbagxcad
set -gx LS_COLORS "di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=0;41:sg=30;46:tw=0;42:ow=30;43"
set -gx TIME_STYLE long-iso
set -gx EDITOR nvim
set -gx PNPM_HOME ~/Library/pnpm
set -gx CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN 1

### PATH (replaces the zsh path=(...), krew, Nebius path.zsh.inc, and pnpm blocks)
# fish_add_path silently skips directories that do not exist (verified on fish 4.9.3).
fish_add_path -g ~/.bin ~/.local/bin ~/go/bin ~/.moon/bin ~/.krew/bin ~/.nebius/bin $PNPM_HOME
# OrbStack: command-line tools and integration (appends ~/.orbstack/bin)
test -f ~/.orbstack/shell/init2.fish; and source ~/.orbstack/shell/init2.fish

### Secrets
# never tracked — API keys/tokens; dotenv-style file shared with .zshrc
if test -r ~/.config/secrets.env
    for line in (string match -rv '^\s*(#|$)' < ~/.config/secrets.env)
        set -l kv (string split -m1 = -- $line)
        set -gx $kv[1] (string trim -c '"\'' -- $kv[2])
    end
end

### Aliases
alias ls 'ls -G'
alias mx 'moon run'
alias vim nvim
alias vi nvim
alias wm workmux
alias tf terraform
alias ccb 'claude --permission-mode=bypassPermissions'
alias cdb 'codex --dangerously-bypass-approvals-and-sandbox'
alias xcb 'XCLAUDE_PICK=0 xclaude --permission-mode=bypassPermissions'
alias x 'tar --zstd -xvf'

# git language — a function, not an alias: fish only prepends `command` when the
# alias body starts with the alias name, so `alias git 'LANG=en_US git'` would recurse.
function git --wraps git --description 'git with English messages'
    LANG=en_US command git $argv
end

### Functions
function slug --description 'random alphanumeric string of length N'
    cat /dev/urandom | LC_ALL=C tr -dc 'a-zA-Z0-9' | fold -w $argv[1] | head -n 1
end

function hotspot_enable
    sudo networksetup -setmanual Wi-Fi 172.20.10.3 255.255.255.240 172.20.10.1
end

function hotspot_disable
    sudo networksetup -setdhcp Wi-Fi
end

### Interactive only
if status is-interactive
    set -g fish_greeting # no greeting
    # emacs key bindings are fish's default (was: bindkey -e); auto_cd and history dedupe are built in
    command -q mise; and mise activate fish | source # brew's vendor_conf.d also does this; re-running only redefines the same functions
    command -q zoxide; and zoxide init fish | source # z = jump to dir, zi = interactive
    command -q fzf; and fzf --fish | source # Ctrl-R history, Ctrl-T files, Alt-C cd
    if test "$TERM_PROGRAM" = vscode
        source (code --locate-shell-integration-path fish)
    end
    command -q starship; and starship init fish | source # prompt; config in ~/.config/starship.toml
end
