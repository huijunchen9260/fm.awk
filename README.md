# fm.awk

File manager written in awk

## Preview

[![asciicast](https://asciinema.org/a/jKftvrAUWtlXK17Nrh0sgAC82.svg)](https://asciinema.org/a/jKftvrAUWtlXK17Nrh0sgAC82)

## Browsing

- cd on exit: `cd $(command fm.awk)`
- last path: `export LASTPATH="$HOME/.cache/lastpath"; cd $(cat -u $LASTPATH) && $TERMINAL -e fm.awk`

## Actions

- [x] Bulk selection
- Actions:
    - History
    - `mv`
    - `cp -R`
    - `ln -sf`

## TODO

- [ ] Bulk selection all


