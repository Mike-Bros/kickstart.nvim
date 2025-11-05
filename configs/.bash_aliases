# Editor aliases
alias vim=nvim
alias vi=nvim

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

# Nginx management
alias el7='sudo nvim /etc/nginx/sites-available/default'
alias el4='sudo nvim /etc/nginx/nginx.conf'
alias addsite='_addsite() { sudo certbot --nginx -d "$1.bros.ninja"; }; _addsite'
alias nreload='sudo nginx -t && sudo systemctl reload nginx'
