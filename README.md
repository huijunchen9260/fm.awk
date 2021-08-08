# fm.awk

File manager written in awk

## Preview

[![asciicast](https://asciinema.org/a/9YDmY7GhnV7ku2yRhGJlQa8l4.svg)](https://asciinema.org/a/9YDmY7GhnV7ku2yRhGJlQa8l4)

## Browsing

- cd on exit: `cd $(command fm.awk)`
- last path: `export LASTPATH="$HOME/.cache/lastpath"; cd $(cat -u $LASTPATH) && $TERMINAL -e fm.awk`

## Key bindings

```
NUMBERS:
	[num] - choose entries
	[num]+G - Go to page [num]
NAVIGATION:
	k/↑ - up                      j/↓ - down
	l/→ - right                   h/← - left
	n/PageDown - PageDown         p/PageUp - PageUp
	g/Home - first page           G/End - last page
	t - first entry               b - last entry
MODES:
	/ - search
	: - commandline mode
SELECTION:
	␣ - bulk (de-)selection       V - bulk (de-)selection all
PREVIEW:
	v - toggle preview
	> - more directory ratio      < - less directory ratio
MISC:
	r - refresh                   a - actions
	- - previous directory        ! - spawn shell
	? - show keybinds             q - quit
```

## Actions

- [x] Bulk selection
- [x] Bulk selection all
- [x] Directory / File preview
- Actions:
    - History
    - `mv`
    - `cp -R`
    - `ln -sf`
    - `rm -rf` && yes-no prompt

## Configuration

edit `fm.awk`, modify the first configuration section:

```awk
    ###################
    #  Configuration  #
    ###################

    OPENER = ( ENVIRON["OSTYPE"] ~ /darwin.*/ ? "open" : "xdg-open" )
    LASTPATH = ( ENVIRON["LASTPATH"] == "" ? ( ENVIRON["HOME"] "/.cache/lastpath" ) : ENVIRON["LASTPATH"] )
    HISTORY = ( ENVIRON["HISTORY"] == "" ? ( ENVIRON["HOME"] "/.cache/history" ) : ENVIRON["HISTORY"] )
    CMDHIST = ( ENVIRON["CMDHIST"] == "" ? ( ENVIRON["HOME"] "/.cache/cmdhist" ) : ENVIRON["CMDHIST"] )
    PREVIEW = 0
    RATIO = 0.35
    HIST_MAX = 5000
```

- `OPENER` is the default file opener.
- `LASTPATH` is path which `fm.awk` were last time.
- `HISTORY` is the history for directory visited.
- `CMDHIST` is the command line history, which only the unique command will be left.
- `PREVIEW` is a boolean value which toggles preview or not.
- `RATIO` is the ratio for directory / preview.
- `HIST_MAX` is the maximum number of `HISTORY`.

## cmd mode

- `:cd /path/to/destination`
    - can be relative: `:cd ../../` goes to parents two tiers
- `:cmd ` on each selected item.
    - e.g., After selection, `:chmod +x` to give execution permission on selected entries.
- `:cmd {} destination` to replace `{}` with each selected item and execute the whole command.
    - e.g., After selection, `:mv {} ~` will move selected item to `$HOME` directory.
- `cmd` can be shell alias (`bash` and `zsh` confirmed. `fish` not sure).
- tab completion on `:cd ` and search (`/`)
- tab completion on command line mode based on command line history.
- left / right arrow to move cursor; up / down arrow to access command line history.

## TODO

- [ ] Image preview (now only chafa)
