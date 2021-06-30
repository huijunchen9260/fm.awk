# fm.awk

File manager written in awk

## Preview

[![asciicast](https://asciinema.org/a/jKftvrAUWtlXK17Nrh0sgAC82.svg)](https://asciinema.org/a/jKftvrAUWtlXK17Nrh0sgAC82)

## Browsing

- cd on exit: `cd $(command fm.awk)`
- last path: `export LASTPATH="$HOME/.cache/lastpath"; cd $(cat -u $LASTPATH) && $TERMINAL -e fm.awk`

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
    FILE_PREVIEW = 0
```

## TODO

- [ ] Better Interface

