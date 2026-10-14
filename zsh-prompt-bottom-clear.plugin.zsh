# zsh-prompt-bottom-clear
#
# Clear the current viewport with Ctrl-L, preserve it in scrollback,
# and redraw the prompt at the bottom of the terminal.
#
# Designed for interactive zsh and compatible with Powerlevel10k
# instant prompt.

[[ -o interactive ]] || return

zmodload zsh/system zsh/terminfo zsh/zselect || return
autoload -Uz add-zle-hook-widget

# Portable cursor hide/show support is required.
(( $+terminfo[civis] && $+terminfo[cnorm] )) || return

# Open the controlling terminal.
#
# Keep a dedicated read/write descriptor rather than using stdin,
# stdout or stderr. This is important during shell initialization,
# where e.g. Powerlevel10k instant prompt can redirect fd 0, 1 and 2.
_prompt_bottom_init_tty() {
    # Already open, e.g. when the plugin is sourced again.
    [[ -v _prompt_bottom_tty_fd ]] && return

    if [[ -n ${TTY-} && -w $TTY ]]; then
        typeset -gi _prompt_bottom_tty_fd
        sysopen -o cloexec -rwu _prompt_bottom_tty_fd -- "$TTY" || return
        typeset -gri _prompt_bottom_tty_fd
    elif [[ -w /dev/tty ]]; then
        typeset -gi _prompt_bottom_tty_fd
        if sysopen -o cloexec -rwu _prompt_bottom_tty_fd -- /dev/tty 2>/dev/null; then
            typeset -gri _prompt_bottom_tty_fd
        else
            unset _prompt_bottom_tty_fd
            return 1
        fi
    else
        return 1
    fi
}

# Query the terminal for the current cursor position.
#
# The terminal is sent DSR (CSI 6 n) and responds with
# CPR (CSI <row> ; <column> R).
_prompt_bottom_get_cursor_position() {
    local fd=${_prompt_bottom_tty_fd-1}
    [[ -t $fd ]] || return

    local response

    # zsh's read prompt syntax writes everything after '?' before
    # waiting for input, allowing the query and response to use the
    # same terminal descriptor.
    IFS= builtin read -srt 5 -d R \
        response$'?\e[6n' <&$fd || return

    while [[ $response != *$'\e['<->';'<-> ]]; do
        IFS= builtin read -srt 5 -d R response <&$fd || return
    done

    response=${response##*'['}

    typeset -gi _prompt_bottom_cursor_y=${response%';'*}
    typeset -gi _prompt_bottom_cursor_x=${response#*';'}
}

_prompt_bottom_cursor_hide() {
    builtin echoti civis >&$_prompt_bottom_tty_fd
}

_prompt_bottom_cursor_show() {
    # Some terminfo cnorm definitions also modify the cursor shape.
    # If cnorm ends with the standard cursor-visible sequence, emit
    # only that part so a user-selected cursor shape is preserved.
    local cnorm=${${terminfo[cnorm]-}:/*$'\e[?25h'(|$'\e'*)/$'\e[?25h'}

    builtin print -rnu $_prompt_bottom_tty_fd -- "$cnorm"
}

# Public clear function and ZLE widget.
#
# This intentionally mirrors zsh4humans: the same function is used both
# as a normal shell command and as a ZLE widget.
prompt-bottom-clear() {
    local -i _prompt_bottom_cursor_x _prompt_bottom_cursor_y

    _prompt_bottom_cursor_hide

    if _prompt_bottom_get_cursor_position; then
        # Move to the bottom and then scroll one complete viewport.
        # The previous viewport remains available in scrollback.
        builtin print -rnu $_prompt_bottom_tty_fd -- \
            "${(pl:$((2 * LINES - _prompt_bottom_cursor_y - 1))::\n:)}"
    fi

    builtin zle -I
    builtin zle -R

    _prompt_bottom_cursor_show
}

# Whether to move the first prompt to the bottom.
#
#   zstyle ':prompt-bottom-clear:' startup-at-bottom tmux|yes|no
#
# The default, tmux, enables it only inside tmux. tmux always answers
# the cursor position query itself, whereas a terminal without CPR
# support would delay the first prompt until the query times out.
_prompt_bottom_startup_enabled() {
    local mode
    zstyle -s ':prompt-bottom-clear:' startup-at-bottom mode || mode=tmux

    case $mode in
        (yes)  return 0 ;;
        (tmux) [[ -n ${TMUX-} ]] ;;
        (*)    return 1 ;;
    esac
}

# Move the first prompt to the bottom of the terminal.
#
# Runs once, as a line-init hook, after the first prompt is drawn.
# Doing it earlier does not work with Powerlevel10k instant prompt,
# which moves the cursor back to where the instant prompt started.
#
# Blank lines are inserted at the top of the screen, so the prompt
# and any output above it move down together. The rows pushed off the
# bottom are below the cursor and therefore empty. Since the cursor
# keeps its position relative to the prompt, ZLE can go on redrawing
# without being told.
#
# The cursor position query would swallow keys typed during startup,
# so skip it if input is already pending.
_prompt_bottom_startup() {
    add-zle-hook-widget -d line-init _prompt_bottom_startup

    _prompt_bottom_startup_enabled || return 0
    ! zselect -t0 -r $_prompt_bottom_tty_fd || return 0

    local -i _prompt_bottom_cursor_x _prompt_bottom_cursor_y
    _prompt_bottom_get_cursor_position || return 0

    local -i n=$(( LINES - _prompt_bottom_cursor_y ))
    (( n > 0 )) || return 0

    builtin print -rnu $_prompt_bottom_tty_fd -- \
        $'\e[H\e['${n}$'L\e['${LINES}';'${_prompt_bottom_cursor_x}'H'
}

_prompt_bottom_init() {
    _prompt_bottom_init_tty || return

    builtin zle -N prompt-bottom-clear
    builtin bindkey '^L' prompt-bottom-clear

    # Use the same implementation for the clear command as for Ctrl-L.
    # Only alias it once the terminal is open, so plain clear keeps
    # working when the plugin cannot initialize.
    alias clear=prompt-bottom-clear

    builtin zle -N _prompt_bottom_startup
    add-zle-hook-widget line-init _prompt_bottom_startup
}

_prompt_bottom_init
