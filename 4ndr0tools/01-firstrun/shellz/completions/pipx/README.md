zsh:
    To activate completions in zsh, first make sure compinit is marked for
    autoload and run autoload:

    autoload -U compinit && compinit

    Afterwards you can enable completions for pipx:

    eval "$(register-python-argcomplete pipx)"

    
