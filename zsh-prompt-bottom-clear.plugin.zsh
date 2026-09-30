# zsh-prompt-bottom-clear
#
# Clear the current viewport with Ctrl-L, preserve it in scrollback,
# and redraw the prompt at the bottom of the terminal.
#
# Designed for interactive zsh and compatible with Powerlevel10k
# instant prompt.

[[ -o interactive ]] || return

zmodload zsh/system zsh/terminfo || return

# Portable cursor visibility and one-row cursor movement are required.
(( $+terminfo[civis] && $+terminfo[cnorm] && $+terminfo[cuu1] )) || return

# Open the controlling terminal.
#
# Keep a dedicated read/write descriptor rather than using stdin,
# stdout or stderr. This is important during shell initialization,
# where e.g. Powerlevel10k instant prompt can redirect fd 0, 1 and 2.
_prompt_bottom_init_tty() {
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

# Core terminal operation.
#
# With an argument of 1, leave the cursor one row above the normal
# bottom position. This is used by the shell command path because zsh
# will render a fresh prompt after the command returns.
_prompt_bottom_clear_terminal() {
    local -i reserve_prompt_row=${1:-0}
    local -i _prompt_bottom_cursor_x _prompt_bottom_cursor_y

    _prompt_bottom_cursor_hide

    if _prompt_bottom_get_cursor_position; then
        # Move to the bottom and then scroll one complete viewport.
        # The previous viewport remains available in scrollback.
        builtin print -rnu $_prompt_bottom_tty_fd -- \
            "${(pl:$((2 * LINES - _prompt_bottom_cursor_y - 1))::\n:)}"

        if (( reserve_prompt_row )); then
            builtin echoti cuu1 >&$_prompt_bottom_tty_fd
        fi
    fi

    _prompt_bottom_cursor_show
}

# Public ZLE widget.
prompt-bottom-clear() {
    _prompt_bottom_clear_terminal

    # Direct terminal output has invalidated ZLE's display state.
    builtin zle -I
    builtin zle -R
}

# Replace the normal clear command for the no-argument case.
#
# Unlike the ZLE widget, this runs outside ZLE and therefore deliberately
# does not call zle -I or zle -R. Arguments are passed through to the
# external clear command so implementation-specific options keep working.
clear() {
    if (( ARGC )); then
        command clear "$@"
    else
        _prompt_bottom_clear_terminal 1
    fi
}

_prompt_bottom_init() {
    _prompt_bottom_init_tty || return

    builtin zle -N prompt-bottom-clear
    builtin bindkey '^L' prompt-bottom-clear
}

_prompt_bottom_init
