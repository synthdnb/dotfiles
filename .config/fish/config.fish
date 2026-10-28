# fish counterpart of .zshrc + .zprofile.
# Symlinked to ~/.config/fish/config.fish by install.sh.

### Environment (runs for non-interactive fish too)
# Output of `brew shellenv fish`, pinned (was .zprofile): spawning brew cost
# ~18 ms per shell, non-interactive ones too. Regenerate with `brew shellenv fish`
# if Homebrew moves.
set -gx HOMEBREW_PREFIX /opt/homebrew
set -gx HOMEBREW_CELLAR /opt/homebrew/Cellar
set -gx HOMEBREW_REPOSITORY /opt/homebrew
fish_add_path -g --move --path /opt/homebrew/bin /opt/homebrew/sbin
if test -n "$MANPATH"
    set -gx MANPATH (string replace --regex '^:*(.*?):*$' ':$1' -- "$MANPATH")
end
if not set -q INFOPATH
    set INFOPATH ''
end
set -gx INFOPATH /opt/homebrew/share/info $INFOPATH
set -gx LSCOLORS Gxfxcxdxbxegedxbagxcad
set -gx LS_COLORS "di=1;36:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=0;41:sg=30;46:tw=0;42:ow=30;43"
set -gx TIME_STYLE long-iso
set -gx EDITOR nvim
set -gx PNPM_HOME ~/Library/pnpm
set -gx CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN 1

### PATH (replaces the zsh path=(...), krew, Nebius path.zsh.inc, and pnpm blocks)
# fish_add_path silently skips directories that do not exist (verified on fish 4.9.3).
fish_add_path -g ~/.bin ~/.local/bin ~/go/bin ~/.moon/bin ~/.krew/bin ~/.nebius/bin $PNPM_HOME
# mise runs in shims mode in every shell. A shim resolves the tool version for the
# current directory (and injects the config's [env]) on each call, so nothing runs
# at startup or per prompt; `mise activate` cost ~28 ms per shell start plus a
# `mise hook-env` process per prompt, because the mise binary is 221 MB. Same as
# `mise activate fish --shims | source`, minus the process. `mise which node` shows
# the real binary; `mise reshim` after installing a tool outside `mise install`.
fish_add_path -g ~/.local/share/mise/shims
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
    # Prompt and jump/search tools. Their `init` output only changes when the
    # binary does, so it is cached: each init spawned a process (starship two)
    # and together they cost about 25 ms per shell. The cache is rebuilt when a
    # tool's path or binary changes (brew upgrade), or after
    # `rm ~/.cache/fish/init.fish`. Builtins only, so the check spawns nothing.
    set -l cache ~/.cache/fish/init.fish
    # First line of the cache names the binaries it was built from; a brew upgrade
    # changes their Cellar path (…/Cellar/starship/1.27.0/…), a manual rebuild their mtime.
    set -l key "# built from: "(string join ' ' (path resolve (command -v zoxide fzf starship)))
    set -l have
    test -r $cache; and read -l have <$cache
    set -l stale 0
    test "$have" = "$key"; or set stale 1
    for tool in (command -v zoxide fzf starship)
        test $tool -nt $cache; and set stale 1
    end
    if test $stale = 1
        mkdir -p (dirname $cache)
        begin
            echo $key
            command -q zoxide; and zoxide init fish # z = jump to dir, zi = interactive
            command -q fzf; and fzf --fish # Ctrl-R history, Ctrl-T files, Alt-C cd
            command -q starship; and starship init fish --print-full-init # prompt; config in ~/.config/starship.toml
        end >$cache.tmp # the block's status is the last init's, so move unconditionally
        mv -f $cache.tmp $cache
    end
    test -r $cache; and source $cache
    if test "$TERM_PROGRAM" = vscode
        source (code --locate-shell-integration-path fish)
    end
    # Replaces mise's `_.python.venv` auto-activation (pccafe, vessl-python-sdk),
    # which needs `mise activate`'s prompt hook and so doesn't work with shims:
    # entering a directory tree that has a .venv activates it, and leaving it
    # deactivates a venv this function activated; a venv activated any other way
    # is left alone. Builtins only. starship shows the venv, so the activate
    # script's own prompt prefix is off.
    set -gx VIRTUAL_ENV_DISABLE_PROMPT 1
    function __venv_on_pwd --on-variable PWD --description 'activate ./.venv up the tree'
        # A manual `deactivate` leaves our marker behind; forget it with the venv.
        set -q VIRTUAL_ENV; or set -e __venv_auto
        # A venv inherited from a parent shell has VIRTUAL_ENV but no `deactivate`,
        # and this shell's PATH setup has pushed its bin behind the shims: re-adopt it
        # by sourcing its activate script (_OLD_VIRTUAL_PATH is erased first, or the
        # script would reset PATH to the parent's pre-venv PATH).
        if set -q VIRTUAL_ENV; and not functions -q deactivate; and test -f $VIRTUAL_ENV/bin/activate.fish
            set -l i (contains -i -- $VIRTUAL_ENV/bin $PATH); and set -e PATH[$i]
            set -e _OLD_VIRTUAL_PATH
            source $VIRTUAL_ENV/bin/activate.fish
        end
        # Only a venv this function activated (__venv_auto, exported so a nested
        # shell knows too) is switched or deactivated; one activated by hand, by an
        # editor or by `poetry shell` is left alone.
        if set -q VIRTUAL_ENV; and test "$VIRTUAL_ENV" != "$__venv_auto"
            return
        end
        set -l dir $PWD
        while test "$dir" != / -a "$dir" != "$HOME"
            if test -f $dir/.venv/bin/activate.fish
                if test "$VIRTUAL_ENV" != "$dir/.venv"
                    functions -q deactivate; and deactivate
                    source $dir/.venv/bin/activate.fish
                    set -gx __venv_auto $VIRTUAL_ENV
                end
                return
            end
            set dir (path dirname $dir)
        end
        if set -q VIRTUAL_ENV
            deactivate
            set -e __venv_auto
        end
    end
    __venv_on_pwd
end
