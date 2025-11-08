# Editor aliases
alias vim=nvim
alias vi=nvim

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate'

# Docker shortcuts
alias d='docker'
alias dc='docker compose'
alias dr='docker compose restart'
alias dcr='docker compose down && docker compose up -d'
alias dps='docker ps'
alias dimg='docker images'

# Directory navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Generate secure keys for Docker services
alias keygen='openssl rand -hex 32'
alias makekey='openssl rand -hex 32'
alias secretkey='openssl rand -hex 32'

# Nginx management
alias el7='sudo nvim /etc/nginx/sites-available/default'
alias el4='sudo nvim /etc/nginx/nginx.conf'
alias addsite='_addsite() { sudo certbot --nginx -d "$1.bros.ninja"; }; _addsite'
alias nreload='sudo nginx -t && sudo systemctl reload nginx'
