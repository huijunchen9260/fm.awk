#!/bin/sh

top="$1"; end="$2"; num="$3"; border="$4"; path="$5";
nl='
'
esc_c=$(printf '\033')

esc() {
    case $1 in
        # vt100 (IL is vt102) (DECTCEM is vt520)
        CUP)     printf '%s[%s;%sH' "$esc_c" "$2" "$3" ;; # cursor home
        SGR)     printf '%s[%s;%sm' "$esc_c" "$2" "$3" ;; # colors
    esac
}

case "$path" in
    *.pdf)
        fig=$(pdftoppm -jpeg -f 1 -singlefile "$path" 2>/dev/null | chafa -s $((3*((end-top)/num)))x "-" 2>/dev/null)
        ;;
esac

# printf "$fig"

IFS="$nl"; i=1
set -- $fig
unset IFS
for item do
    esc CUP $((top+i-1)) $((border+1))
    printf "%s" "$item"
    i=$((i+1))
    [ "$i" > $(((end-top)/num)) ] && break
done
