# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
export PATH=$PATH:/home/soulis/.spicetify
#export GIT_ACCESS_TOKEN=""; #find this or reset
export EDITOR="nvim";
