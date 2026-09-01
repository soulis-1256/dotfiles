if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# Auto-switch to docker group if not already in it
if not groups | grep -q docker
    exec newgrp docker
end


# >>> grok installer >>>
fish_add_path $HOME/.grok/bin
# <<< grok installer <<<


# User local bin in PATH
fish_add_path $HOME/.local/bin

# Make run0 the default for sudo invocations
alias sudo="run0"

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# Source machine-specific local overrides & secrets if present (untracked by Git)
if test -f ~/.config/fish/secrets.fish
    source ~/.config/fish/secrets.fish
end

