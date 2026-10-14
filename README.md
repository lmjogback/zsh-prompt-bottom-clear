# zsh-prompt-bottom-clear

A small Zsh plugin that makes `Ctrl-L` clear the current viewport while preserving it in scrollback, then redraws the prompt at the bottom of the terminal.

The implementation is based on the same terminal technique used by zsh4humans v5: query the cursor position with DSR/CPR, scroll with newlines, then let ZLE redraw the prompt.

## Features

- Keeps previous terminal contents in scrollback.
- Redraws the prompt at the bottom after `Ctrl-L` or the plain `clear` command.
- `Ctrl-Alt-L` also clears the scrollback, then redraws the prompt at the bottom.
- Inside tmux, also places the first prompt at the bottom when the shell starts.
- Uses a dedicated controlling-TTY file descriptor instead of stdin/stdout/stderr.
- Compatible with Powerlevel10k instant prompt.
- Works directly in modern VT/xterm-compatible terminals and inside tmux.
- Uses terminfo for cursor visibility control.

## Requirements

- Zsh
- An interactive shell
- A controlling terminal that supports ANSI/VT DSR/CPR cursor position reporting
- `zsh/system` and `zsh/terminfo`

## Installation

Clone the repository:

```sh
git clone https://github.com/lmjogback/zsh-prompt-bottom-clear.git \
  ~/.config/zsh/plugins/zsh-prompt-bottom-clear
```

Then source the plugin from `.zshrc`:

```zsh
source ~/.config/zsh/plugins/zsh-prompt-bottom-clear/zsh-prompt-bottom-clear.plugin.zsh
```

Load it after plugins or shell integrations that may change key bindings so that its `Ctrl-L` binding wins.

## Usage

Press `Ctrl-L` or run:

```zsh
clear
```

Both use the same `prompt-bottom-clear` implementation, matching the approach used by zsh4humans. The plugin aliases plain `clear` to that function and also registers it as the `Ctrl-L` ZLE widget.

The plugin registers the public ZLE widgets:

```text
prompt-bottom-clear       Ctrl-L      keep the old viewport in scrollback
prompt-bottom-clear-hard  Ctrl-Alt-L  clear the screen and the scrollback
```

`prompt-bottom-clear-hard` erases the scrollback with `CSI 3 J`. tmux also clears the pane history on this sequence (verified with tmux 3.6).

Verify the binding with:

```zsh
bindkey '^L'
```

Expected output:

```text
"^L" prompt-bottom-clear
```

## Prompt at bottom on startup

Inside tmux, the first prompt of a new shell is moved to the bottom of the pane. Output printed during startup is kept directly above it.

This is controlled with a zstyle, which can be set anywhere in `.zshrc`:

```zsh
# tmux (default): only inside tmux
# yes: in every terminal
# no: never
zstyle ':prompt-bottom-clear:' startup-at-bottom tmux
```

It is enabled only inside tmux by default because tmux always answers the cursor position query itself. Outside tmux, a terminal that does not support the query would delay the first prompt until the query times out after 5 seconds. Use `yes` if your terminal is known to support it.

The move is skipped if keys have already been typed when the first prompt appears, so typed-ahead input is never lost.

## How it works

The plugin opens the controlling terminal on a dedicated read/write file descriptor. This avoids interference from startup helpers such as Powerlevel10k instant prompt, which may temporarily redirect file descriptors 0, 1 and 2 while `.zshrc` is loading.

When `Ctrl-L` is pressed or plain `clear` is run, the plugin:

1. Hides the cursor using terminfo.
2. Sends DSR (`CSI 6 n`) to query the current cursor position.
3. Reads the terminal's CPR response (`CSI <row>;<column> R`).
4. Writes enough newlines to move to the bottom and scroll one full viewport.
5. Restores cursor visibility.
6. Invalidates and redraws the ZLE display.

The old viewport is therefore moved into scrollback instead of being erased.

On startup, the plugin waits until the first prompt has been drawn, queries the cursor position, inserts blank lines at the top of the screen (`CSI <n> L`) and moves the cursor down by the same amount. The prompt and the output above it move down together, and ZLE keeps redrawing correctly because the cursor stays in the same position relative to the prompt. Waiting for the first prompt is what makes this work with Powerlevel10k instant prompt, which restores the cursor to where the instant prompt started.

## Tested

Manually tested in:

- Ghostty → Zsh
- Ghostty → tmux → Zsh
- Powerlevel10k with instant prompt enabled
- Prompt at bottom on startup: tmux 3.6 with a plain prompt and with Powerlevel10k instant prompt

## Acknowledgements

The terminal handling and prompt-at-bottom algorithm are derived from `zsh4humans` by Roman Perepelitsa, licensed under the MIT License.

## License

MIT
