source /usr/share/cachyos-fish-config/cachyos-config.fish

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


# Added by Antigravity CLI installer
set -gx PATH "/home/soulis/.local/bin" $PATH

# Make run0 the default for sudo invocations
alias sudo="run0"

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH
