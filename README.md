# zsh-prompt-bottom-clear

A small Zsh plugin that makes `Ctrl-L` clear the current viewport while preserving it in scrollback, then redraws the prompt at the bottom of the terminal.

The implementation is based on the same terminal technique used by zsh4humans v5: query the cursor position with DSR/CPR, scroll with newlines, then let ZLE redraw the prompt.

## Features

- Keeps previous terminal contents in scrollback.
- Redraws the prompt at the bottom after `Ctrl-L` or the plain `clear` command.
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

The plugin registers the public ZLE widget:

```text
prompt-bottom-clear
```

and binds it to `Ctrl-L` by default.

Verify the binding with:

```zsh
bindkey '^L'
```

Expected output:

```text
"^L" prompt-bottom-clear
```

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

## Tested

Manually tested in:

- Ghostty → Zsh
- Ghostty → tmux → Zsh
- Powerlevel10k with instant prompt enabled

## Acknowledgements

The terminal handling and prompt-at-bottom algorithm are derived from `zsh4humans` by Roman Perepelitsa, licensed under the MIT License.

## License

MIT
