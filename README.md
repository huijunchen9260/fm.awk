# fm.awk

File manager written in awk

## Preview

[![asciicast](https://asciinema.org/a/jKftvrAUWtlXK17Nrh0sgAC82.svg)](https://asciinema.org/a/jKftvrAUWtlXK17Nrh0sgAC82)

## Browsing

- cd on exit: `cd $(command fm.awk)`
- last path: `export LASTPATH="$HOME/.cache/lastpath"; cd $(cat -u $LASTPATH) && $TERMINAL -e fm.awk`

## Key bindings

```
k/↑ - up
j/↓ - down
l/→ - right
h/← - left
n/PageDown - PageDown
p/PageUp - PageUp
t/Home - go to first page
b/End - go to last page
g - go to first entry in current page
G - go to last entry in current page
r - refresh
! - spawn shell
/ - search
: - commandline mode
- - go to previous directory
␣ - bulk (de-)selection
A - bulk (de-)selection all
v - toggle preview
> - more directory ratio
< - less directory ratio
a - actions
? - show keybinds
q - quit
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
    PREVIEW = 1
    RATIO = 0.35
```

## cmd mode

- `:cd /path/to/destination`
    - can be relative: `:cd ../../` goes to parents two tiers
- `:cmd ` on each selected item.
    - e.g., After selection, `:chmod +x` to give execution permission on selected entries.
- `:cmd {} destination` to replace `{}` with each selected item and execute the whole command.
    - e.g., After selection, `:mv {} ~` will move selected item to `$HOME` directory.
- `cmd` can be shell alias (`bash` and `zsh` confirmed. `fish` not sure).
- tab completion on `:cd ` and search (`/`)
- left / right arrow to move cursor

## TODO

- [ ] Image preview (now only chafa)
