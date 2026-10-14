# zsh-prompt-bottom-clear startup
#
# Move the cursor to the bottom of the terminal so that the first
# prompt is drawn there.
#
# Source this file before the Powerlevel10k instant prompt block, and
# load the plugin itself as usual later in .zshrc. Without this file,
# the plugin moves the first prompt once it is drawn, which with
# instant prompt means that the prompt jumps down after .zshrc has
# finished loading.

typeset -g _prompt_bottom_startup_only=1
builtin source -- ${${(%):-%x}:A:h}/zsh-prompt-bottom-clear.plugin.zsh
unset _prompt_bottom_startup_only
