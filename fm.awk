#!/usr/bin/awk -f

BEGIN {

    ###################
    #  Configuration  #
    ###################

    OPENER = ( ENVIRON["FMAWK_OPENER"] == "" ? ( ENVIRON["OSTYPE"] ~ /darwin.*/ ? "open" : "xdg-open" ) : ENVIRON["FMAWK_OPENER"] )
    LASTPATH = ( ENVIRON["LASTPATH"] == "" ? ( ENVIRON["HOME"] "/.cache/lastpath" ) : ENVIRON["LASTPATH"] )
    HISTORY = ( ENVIRON["HISTORY"] == "" ? ( ENVIRON["HOME"] "/.cache/history" ) : ENVIRON["HISTORY"] )
    CMDHIST = ( ENVIRON["CMDHIST"] == "" ? ( ENVIRON["HOME"] "/.cache/cmdhist" ) : ENVIRON["CMDHIST"] )
    CACHE = ( ENVIRON["CACHE"] == "" ? ( ENVIRON["HOME"] "/.cache/imagecache" ) : ENVIRON["CACHE"] )
    FIFO_UEBERZUG = ENVIRON["FIFO_UEBERZUG"]
    FMAWK_PREVIEWER = ENVIRON["FMAWK_PREVIEWER"]
    PREVIEW = 0
    HIDDEN = 0
    RATIO = 0.35
    HIST_MAX = 5000
    SUBSEP = ","

    ####################
    #  Initialization  #
    ####################

    # Credit: https://unix.stackexchange.com/questions/224969/current-date-in-awk/225463#225463
    srand(); old_time = srand();
    init()
    RS = "\a"
    dir = ( ENVIRON["PWD"] == "/" ? "/" : ENVIRON["PWD"] "/" )
    cursor = 1; curpage = 1;

    # load alias
    cmd = "${SHELL:=/bin/sh} -c \". ~/.${SHELL##*/}rc && alias\""
    cmd | getline alias
    close(cmd)
    split(alias, aliasarr, "\n")
    for (line in aliasarr) {
        key = aliasarr[line]; gsub(/=.*/, "", key); gsub(/^alias /, "", key)
        cmd = aliasarr[line]; gsub(/.*=/, "", cmd); gsub(/^'|'$/, "", cmd)
        cmdalias[key] = cmd
    }

    # defind [a]ttributes, [b]ackground and [f]oreground
    a_bold = "\033\1331m"
    a_reverse = "\033\1337m"
    a_clean = "\033\1332K"
    a_reset = "\033\133m"
    b_red = "\033\13341m"
    f_red = "\033\13331m"
    f_green = "\033\13332m"
    f_yellow = "\033\13333m"
    f_blue = "\033\13334m"
    f_magenta = "\033\13335m"
    f_cyan = "\033\13336m"
    f_white = "\033\13337m"

    #############
    #  Actions  #
    #############

    # action = "History" RS \
    #      "mv" RS \
    #      "cp -R" RS \
    #      "ln -sf" RS \
    #      "rm -rf"
    action = "History"

    help = "\n" \
       "NUMBERS: \n" \
       "\t[num] - move cursor to entry [num] \n" \
       "\t[num]+G - Go to page [num] \n" \
       "\n" \
       "NAVIGATION: \n" \
       "\tk/↑ - up                      j/↓ - down \n" \
       "\tl/→ - right                   h/← - left \n" \
       "\tCtrl-f - Half Page Down       Ctrl-u - Half Page Up\n" \
       "\tn/PageDown - PageDown         p/PageUp - PageUp \n"  \
       "\tg/Home - first page           G/End - last page \n"  \
       "\tH - first entry               L - last entry \n"  \
       "\tM - middle entry\n" \
       "\n" \
       "MODES: \n" \
       "\t/ - search \n"  \
       "\t: - commandline mode \n"  \
       "\t    commandline mode special function: \n" \
       "\t        {}: represent selected files/directories\n" \
       "\t        tab completion on path: start with ' /', use tab to complete on that path \n" \
       "\t        tab completion on cmd: completion based on command history \n" \
       "\t            ><: enter selecting mode for directory (choose ./ to confirm destination)\n" \
       "\n" \
       "SELECTION: \n" \
       "\t␣ - bulk (de-)selection       S - bulk (de-)selection all  \n"  \
       "\ts - show selected\n" \
       "\n" \
       "PREVIEW: \n" \
       "\tv - toggle preview \n"  \
       "\t> - more directory ratio      < - less directory ratio \n"  \
       "\n" \
       "MISC: \n" \
       "\tr - refresh                   a - actions \n" \
       "\t- - previous directory        ! - spawn shell \n" \
       "\t. - toggle hidden             ? - show keybinds\n" \
       "\tq - quit \n" \

    main();
}

END {
    finale();
    hist_clean();
    cmd_clean();
    system("[ -f " CACHE ".jpg ] && rm " CACHE ".jpg 2>/dev/null")
    if (list != "empty") {
        printf("%s", dir) > "/dev/stdout"; close("/dev/stdout")
        printf("%s", dir) > LASTPATH; close(LASTPATH)
    }
}

function main() {

    do {

        list = ( sind == 1 && openind == 1 ? slist : gen_content(dir, HIDDEN) )
        delim = "\f"; num = 1; tmsg = dir; bmsg = ( bmsg == "" ? "Browsing" : bmsg );
        menu_TUI(list, delim, num, tmsg, bmsg)
        response = result[1]
        bmsg = result[2]

        #######################
        #  Matching: Actions  #
        #######################

        if (bmsg == "Actions") {
            if (response == "History") { hist_act(); sind = 0; response = result[1]; bmsg = "";}
        }

        ########################
        #  Matching: Browsing  #
        ########################

        gsub(/\033\[[0-9][0-9]m|\033\[[0-9]m|\033\[m/, "", response)

        if (response == "../") {
            parent = ( dir == "/" ? "/" : dir )
            old_dir = parent
            if (hist != 1) {
                gsub(/[^\/]*\/?$/, "", dir)
                gsub(dir, "", parent)
            }
            # empty_selected()
            dir = ( dir == "" ? "/" : dir ); hist = 0; sind = 0; openind = 0;
            printf("%s\n", dir) >> HISTORY; close(HISTORY)
            continue
        }

        if (response == "./") {
            finale()
            system("cd \"" dir "\" && ${SHELL:=/bin/sh}")
            init()
            sind = 0; openind = 0;
            continue
        }

        if (response ~ /.*\/$/) {
            # empty_selected()
            old_dir = dir
            dir = ( hist == 1 ? response : dir response )
            printf("%s\n", dir) >> HISTORY; close(HISTORY)
            cursor = 1; curpage = 1; hist = 0; sind = 0; openind = 0;
            continue
        }

        finale()
        system("cd \"" dir "\" && " OPENER " \"" dir response "\"")
        init()
        openind = 1; old_dir = ""; parent = "";

    } while (1)

}

function hist_act() {
    list = ""
    getline hisfile < HISTORY; close(HISTORY);
    N = split(hisfile, hisarr, "\n")
    # for (i = N; i in hisarr; i--) {
    for (i = N; i >= 1; i--) {
        list = list "\n" hisarr[i]
    }
    list = substr(list, 3)
    list = list "\n../"; delim = "\n"; num = 1; tmsg = "Choose history: "; bmsg = "Action: " response; hist = 1;
    menu_TUI(list, delim, num, tmsg, bmsg)
}

function cmd_clean() { # act like uniq
    tmp = "";
    getline cmdhist < CMDHIST; close(CMDHIST);
    N = split(cmdhist, cmdarr, "\n")
    for (i = 1; i in cmdarr; i++) { # collect items not seen
        if (! (cmdarr[i] in seen)) { seen[cmdarr[i]]++ }
    }
    for (key in seen) { # expand seen array into string
        if (key != "") { tmp = tmp "\n" key }
    }
    tmp = substr(tmp, 2)
    printf("%s", tmp) > CMDHIST; close(CMDHIST)
}

function hist_clean() {
    getline hisfile < HISTORY; close(HISTORY);
    N = split(hisfile, hisarr, "\n")
    if (N > HIST_MAX) {
        for (i = N-HIST_MAX+1; i in hisarr; i++) {
            histmp = histmp "\n" hisarr[i]
        }
        hisfile = substr(histmp, 2)
        printf("%s", hisfile) > HISTORY; close(HISTORY)
    }
}


function gen_content(dir, HIDDEN) {

    if (HIDDEN == 0) {
        cmd = "for f in \"" dir "\"*; do "\
                  "test -L \"$f\" && test -f \"$f\" && symFileList=\"$symFileList$(printf '\f" a_bold f_cyan "%s" a_reset "' \"$f\")\" && continue; "\
                  "test -L \"$f\" && test -d \"$f\" && symDirList=\"$symDirList$(printf '\f" a_bold f_cyan "%s" a_reset "' \"$f\"/)\" && continue; "\
                  "test -x \"$f\" && test -f \"$f\" && execList=\"$execList$(printf '\f" a_bold f_green "%s" a_reset "' \"$f\")\" && continue; "\
                  "test -f \"$f\" && fileList=\"$fileList$(printf '\f%s' \"$f\")\" && continue; "\
                  "test -d \"$f\" && dirList=\"$dirList$(printf '\f" a_bold f_blue "%s" a_reset "' \"$f\"/)\" ; "\
              "done; "\
              "printf '%s' \"$dirList\" \"$symDirList\" \"$fileList\" \"$execList\" \"$symFileList\""

    }
    else if (HIDDEN == 1) {
        cmd = "for f in \"" dir "\"* \"" dir "\".* ; do "\
                  "test -L \"$f\" && test -f \"$f\" && symFileList=\"$symFileList$(printf '\f" a_bold f_cyan "%s" a_reset "' \"$f\")\" && continue; "\
                  "test -L \"$f\" && test -d \"$f\" && symDirList=\"$symDirList$(printf '\f" a_bold f_cyan "%s" a_reset "' \"$f\"/)\" && continue; "\
                  "test -x \"$f\" && test -f \"$f\" && execList=\"$execList$(printf '\f" a_bold f_green "%s" a_reset "' \"$f\")\" && continue; "\
                  "test -f \"$f\" && fileList=\"$fileList$(printf '\f%s' \"$f\")\" && continue; "\
                  "test -d \"$f\" && dirList=\"$dirList$(printf '\f" a_bold f_blue "%s" a_reset "' \"$f\"/)\" ; "\
              "done; "\
              "printf '%s' \"$dirList\" \"$symDirList\" \"$fileList\" \"$execList\" \"$symFileList\""
    }

    code = cmd | getline dirlist
    close(cmd)
    if (code <= 0) {
        dirlist = "empty"
    }
    else if (dir != "/") {
        gsub(/[\\.^$(){}\[\]|*+?]/, "\\\\&", dir) # escape special char
        gsub(dir, "", dirlist)
        dirlist = substr(dirlist, 2)
    }
    else {
        Narr = split(dirlist, dirlistarr, "\f")
        delete dirlistarr[1]
        dirlist = ""
        for (entry = 2; entry in dirlistarr; entry++) {
            sub(/\//, "", dirlistarr[entry])
            dirlist = dirlist "\f" dirlistarr[entry]
        }
        dirlist = substr(dirlist, 2)
    }
    return dirlist

}

# Credit: https://stackoverflow.com/a/20078022
function isEmpty(arr) { for (idx in arr) return 0; return 1 }

function len(arr,   i) { for (idx in arr) { ++i }; return i }

function maxidx(arr,    idx) { for (idx in selorder) { pidx = (pidx <= idx ? idx : pidx ) }; return pidx }

##################
#  Start of TUI  #
##################

function finale() {
    clean_preview()
    printf "\033\1332J\033\133H" >> "/dev/stderr" # clear screen
    printf "\033\133?7h" >> "/dev/stderr" # line wrap
    printf "\033\1338" >> "/dev/stderr" # restore cursor
    printf "\033\133?25h" >> "/dev/stderr" # show cursor
    printf "\033\133?1049l" >> "/dev/stderr" # back from alternate buffer
    system("stty isig icanon echo")
    ENVIRON["LANG"] = LANG; # restore LANG
}

function init() {
    system("stty -isig -icanon -echo")
    printf "\033\1332J\033\133H" >> "/dev/stderr" # clear screen
    printf "\033\133?1049h" >> "/dev/stderr" # alternate buffer
    printf "\033\1337" >> "/dev/stderr" # save cursor
    printf "\033\133?25l" >> "/dev/stderr" # hide cursor
    printf "\033\1335 q" >> "/dev/stderr" # blinking bar
    printf "\033\133?7l" >> "/dev/stderr" # line unwrap
    LANG = ENVIRON["LANG"]; # save LANG
    ENVIRON["LANG"] = C; # simplest locale setting
}


function CUP(lines, cols) {
    printf("\033\133%s;%sH", lines, cols) >> "/dev/stderr"
}

function draw_selected() {
    for (sel in selected) {
        if (selpage[sel] != curpage || selected[sel] != dir seldisp[sel]) continue
        selN = selnum[sel]
        CUP(top + (selN-dispnum*(curpage-1))*num - num, 1)
        for (i = 1; i <= num; i++) {
            printf "\033\1332K" >> "/dev/stderr" # clear line
            CUP(top + cursor*num - num + i, 1)
        }
        CUP(top + (selN-dispnum*(curpage-1))*num - num, 1)
        gsub(/\033\[[0-9][0-9]m|\033\[[0-9]m|\033\[m/, "", seldisp[sel])

        if (cursor == selN-dispnum*(curpage-1)) {
            printf "%s  %s%s%s%s%s", a_clean, a_reverse, f_red, selN ". ", seldisp[sel], a_reset >> "/dev/stderr"
        }
        else {
            printf "%s  %s%s%s%s%s", a_clean, a_bold, f_red, selN ". ", seldisp[sel], a_reset >> "/dev/stderr"
        }
    }
}

function empty_selected() {
    split("", selected, ":"); split("", seldisp, ":");
    split("", selpage, ":"); split("", selorder, ":")
    sellist = ""; order = 0
}

function dim_setup() {
    cmd = "stty size"
    cmd | getline d
    close(cmd)
    split(d, dim, " ")
    top = 3; bottom = dim[1] - 4;
    fin = bottom - ( bottom - (top - 1) ) % num; end = fin + 1;
    dispnum = (end - top) / num
}

function menu_TUI_page(list, delim) {
    answer = ""; page = 0; split("", pagearr, ":") # delete saved array
    dim_setup()
    Narr = split(list, disp, delim)
    dispnum = (dispnum <= Narr ? dispnum : Narr)
    move = int( ( dispnum <= Narr ? dispnum * 0.5 : Narr * 0.5 ) )

    # generate display content for each page (pagearr)
    for (entry = 1; entry in disp; entry++) {
        if ((+entry) % (+dispnum) == 1 || Narr == 1) { # if first item in each page
            pagearr[++page] = entry ". " disp[entry]
        }
        else {
            pagearr[page] = pagearr[page] "\n" entry ". " disp[entry]
        }
        loc = disp[entry]
        gsub(/\033\[[0-9][0-9]m|\033\[[0-9]m|\033\[m/, "", loc)
        if (parent != "" && loc == parent) {
            cursor = entry - dispnum*(page - 1); curpage = page
        }
    }

}

function search(list, delim, str, mode) {
    find = ""; str = tolower(str);
    if (mode == "dir") { regex = "^" str ".*/" }
    else if (mode == "begin") {regex = "^" str ".*"}
    else { regex = ".*" str ".*" }
    gsub(/[(){}\[\]]/, "\\\\&", regex) # escape special char

    # get rid of coloring to avoid find irrelevant item
    tmplist = list
    gsub(/\033\[[0-9][0-9]m|\033\[[0-9]m|\033\[m/, "", tmplist)
    split(list, sdisp, delim); split(tmplist, tmpsdisp, delim)

    for (entry = 1; entry in tmpsdisp; entry++) {
        match(tolower(tmpsdisp[entry]), regex)
        if (RSTART) { find = find delim sdisp[entry]; }
    }

    slist = substr(find, 2)
    return slist
}

function key_collect(list, pagerind) {
    key = ""; rep = 0
    do {

        cmd = "trap 'printf WINCH' WINCH; dd ibs=1 count=1 2>/dev/null"
        cmd | getline ans;
        close(cmd)

        if (++rep == 1) {
            srand(); time = srand()
            if (time - old_time == 0) { sec++ }
            else { sec = 0 }
            old_time = time
        }

        gsub(/[\\^\[\]]/, "\\\\&", ans) # escape special char
        # if (ans ~ /.*WINCH/ && pagerind == 0) { # trap SIGWINCH
        if (ans ~ /.*WINCH/) { # trap SIGWINCH
            cursor = 1; curpage = 1;
            if (pagerind == 0) {
                menu_TUI_page(list, delim)
                redraw(tmsg, bmsg)
            }
            else if (pagerind == 1) {
                printf "\033\1332J\033\133H" >> "/dev/stderr"
                dim_setup()
                Npager = (Nmsgarr >= dim[1] ? dim[1] : Nmsgarr)
                for (i = 1; i <= Npager; i++) {
                    CUP(i, 1)
                    printf "%s", msgarr[i] >> "/dev/stderr"
                }
            }
            gsub(/WINCH/, "", ans);
        }
        if (ans ~ /\033/ && rep == 1) { ans = ""; continue; } # first char of escape seq
        else { key = key ans; }
        if (key ~ /[^\x00-\x7f]/) { break } # print non-ascii char
        if (key ~ /^\\\[5$|^\\\[6$$/) { ans = ""; continue; } # PageUp / PageDown
    } while (ans !~ /[\x00-\x5a]|[\x5f-\x7f]/)
    # } while (ans !~ /[\006\025\033\003\177[:space:][:alnum:]><\}\{.~\/:!?*+-]|"|[|_$()]/)
    return key
}

function cmd_mode(list, answer) {

    ### comment for scrollable cmd mode:
    # |------------b1--------------------b2-------------length(reply)
    # b1 to b2 is the show-able region in the whole reply.
    # b1 and b2 update according to keyboard inputs.
    # keyboard inputs:
    #   - Left arrow, right arrow, tab completion

    cmd_trigger = answer;
    cc = 0; dd = 0;
    # b1 = 1; b2 = dim[2] - 50; bb = b2 - b1 - 1; curloc = 0;
    b1 = 1; b2 = dim[2]; bb = b2 - b1 - 1; curloc = 0;
    while (key = key_collect(list, pagerind)) {
        if (key == "\003" || key == "\033" || key == "\n") {
            split("", comparr, ":")
            if (key == "\003" || key == "\033") { reply = "\003"; break } # cancelled
            # if Double enter as confirm current path and exit
            if (key_last !~ /\t|\[Z/) break
        }
        if (key == "\177") { # backspace
            reply = substr(reply, 1, length(reply) + cc - 1) substr(reply, length(reply) + cc + 1);
            if (length(reply) + cc < b1 && b1 > 1) { b1 = b1 - 1; b2 = b1 + bb; }
            else if (curloc > 1) { curloc--; }
            split("", comparr, ":")
        }
        # path completion: $HOME
        else if (cmd_trigger reply ~ /:cd |:.* / && key == "~") { reply = reply ENVIRON["HOME"] "/" }
        # path completion
        else if (cmd_trigger reply ~ /:cd .*|:.* \.?\.?\// && key ~ /\t|\[Z/) { # Tab / Shift-Tab
            cc = 0; dd = 0;
            if (isEmpty(comparr)) {
                comp = reply;
                if (cmd_trigger reply ~ /:cd .*/) gsub(/cd /, "", comp)
                else {
                    if (comp ~ /.* \.\.\//) {
                        match(comp, /.* \.\.\//)
                        cmd_run = substr(comp, RSTART, RLENGTH-3)
                        comp = substr(comp, RLENGTH-2)
                    }
                    if (comp ~ /.* \.\//) {
                        match(comp, /.* \.\//)
                        cmd_run = substr(comp, RSTART, RLENGTH-2)
                        comp = substr(comp, RLENGTH-1)
                    }
                    if (comp ~ /.* \//) {
                        match(comp, /.* \//)
                        cmd_run = substr(comp, RSTART, RLENGTH-1)
                        comp = substr(comp, RLENGTH)
                    }
                }
                compdir = comp;
                if (compdir ~ /^\.\.\/.*/) {
                    tmpdir = dir
                    while (compdir ~ /^\.\.\/.*/) { # relative path
                        gsub(/[^\/]*\/?$/, "", tmpdir)
                        gsub(/^\.\.\//, "", compdir)
                        tmpdir = ( tmpdir == "" ? "/" : tmpdir )
                    }
                    compdir = tmpdir
                }
                else {
                    # allow single Enter to confirm current reply
                    # as completion dir (compdir)
                    if (key_last ~ /~|\n/) {
                        comp = ""
                    }
                    else {
                        gsub(/[^\/]*\/?$/, "", compdir);
                        gsub(compdir, "", comp)
                    }
                }
                compdir = (compdir == "" ? dir : compdir);
                tmplist = gen_content(compdir, 1)
                complist = ( cmd_trigger reply ~ /:cd .*/ ?
                             search(tmplist, delim, comp, "dir") :
                             search(tmplist, delim, comp, "begin") )
                gsub(/\033\[[0-9][0-9]m|\033\[[0-9]m|\033\[m/, "", complist)
                Ncomp = split(complist, comparr, delim)

                ## save space for completion
                space = length(comparr[1])
                for (item in comparr) {
                    space = ( space < length(comparr[item]) ? length(comparr[item]) : space )
                }
                if (length(compdir) + space > b2) { b2 = b2 + space; b1 = b2 - bb; }

                c = ( key == "\t" ? 1 : Ncomp )
            }
            else {
                if (key == "\t") c = (c == Ncomp ? 1 : c + 1)
                else c = (c == 1 ? Ncomp : c - 1)
            }
            if (cmd_trigger reply ~ /:cd .*/) reply = "cd " compdir comparr[c]
            else reply = cmd_run compdir comparr[c]
            CUP(dim[1] - 2, 1)
            printf("%s%s%s%s%s", a_clean, a_reverse, f_yellow, "looping through completion", a_reset)
        }
        # command completion
        else if (cmd_trigger == ":" && key ~ /\t|\[Z/) {
            if (isEmpty(comparr)) {
                getline cmdhist < CMDHIST; close(CMDHIST);
                comp = reply;
                complist = search(cmdhist, "\n", comp, "begin")
                gsub(/\033\[[0-9][0-9]m|\033\[[0-9]m|\033\[m/, "", complist)
                Ncomp = split(complist, comparr, "\n")
                c = ( key == "\t" ? 1 : Ncomp )
            }
            else {
                if (key == "\t") c = (c == Ncomp ? 1 : c + 1)
                else c = (c == 1 ? Ncomp : c - 1)
            }
            reply = comparr[c]
            CUP(dim[1] - 2, 1)
            printf("%s%s%s%s%s", a_clean, a_reverse, f_yellow, "looping through completion", a_reset)
        }
        else if (cmd_trigger == ":" && key ~ /\[A|\[B/) {
            getline cmdhist < CMDHIST; close(CMDHIST);
            Ncmd = split(cmdhist, cmdarr, "\n")
            reply = cmdarr[Ncmd - dd]
            if (key ~ /\[A/) { dd = (dd < Ncmd - 1 ? dd + 1 : dd) }
            if (key ~ /\[B/) { dd = (dd == 0 ? dd : dd - 1) }
        }
        # search
        else if (cmd_trigger == "/" && key ~ /\t|\[Z/) {
            cc = 0; dd = 0;
            if (isEmpty(comparr)) {
                comp = reply; complist = search(list, delim, comp, "begin")
                gsub(/\033\[[0-9][0-9]m|\033\[[0-9]m|\033\[m/, "", complist)
                Ncomp = split(complist, comparr, delim)
                c = ( key == "\t" ? 1 : Ncomp )
            }
            else {
                if (key == "\t") c = (c == Ncomp ? 1 : c + 1)
                else c = (c == 1 ? Ncomp : c - 1)
            }
            reply = comparr[c]
        }

        else if (key ~ /\[C/) { # Right arrow
            if (cc < 0) {
                cc++
                if (length(reply) + cc > b2 && b2 < length(reply)) { b2 = b2 + 1; b1 = b2 - bb; }
                else if (curloc < bb) { curloc++; }
            }
        }
        else if (key ~ /\[D/) { # Left arrow
            if (-cc < length(reply)) {
                cc--
                if (length(reply) + cc < b1 && b1 > 1) { b1 = b1 - 1; b2 = b1 + bb; }
                else if (curloc > 1) { curloc--; }
            }
        }
        # single Enter clear the completion array (comparr)
        else if (key ~ /\n/) {
            CUP(dim[1] - 2, 1)
            printf("%s%s%s%s%s", a_clean, a_reverse, f_yellow, "confirm current completion", a_reset)
            curloc = ( length(reply) > bb ? bb : length(reply) )
            split("", comparr, ":")
        }
        # Reject other escape sequence
        else if (key ~ /\[.+/) {
            continue
        }
        else {
            reply = substr(reply, 1, length(reply) + cc) key substr(reply, length(reply) + cc + 1);
            if (length(reply) + cc > b2) { b2 = b2 + 1; b1 = b2 - bb }
            else if (curloc < bb) { curloc++; }
            split("", comparr, ":")
        }

        if (cmd_trigger == "/") {
            slist = search(list, delim, reply, "")
            for (i = top; i <= end; i++) {
                CUP(i, 1)
                printf "\033\133K" >> "/dev/stderr" # clear line
            }
            if (slist != "") {
                Nsarr = split(slist, sarr, delim)
                Nsarr = (Nsarr > dispnum ? dispnum : Nsarr)
                for (i = 1; i <= Nsarr; i++) {
                    CUP(i + 2, 1)
                    printf "%d. %s", i, sarr[i] >> "/dev/stderr"
                }
            }
        }
        if (cmd_trigger ~ /^[[:digit:]]$/) {
            status = sprintf("%sChoose [%s1-%d%s], current page num is %s%d%s, total page num is %s%d%s: %s%s", a_clean, a_bold, Narr, a_reset, a_bold, curpage, a_reset, a_bold, page, a_reset, cmd_trigger, reply)
            if (cmd_trigger reply ~ /^[[:digit:]]+[Gjk]$/) { split("", comparr, ":"); break; }
        }
        else {
            # status = sprintf("%s%s%s", a_clean, cmd_trigger, reply)
            status = sprintf("%s%s%s", a_clean, cmd_trigger, substr(reply, b1, bb))
        }
        CUP(dim[1], 1)
        # printf(status) >> "/dev/stderr"
        # if (cc < 0) { CUP(dim[1], length(status) + cc - 3) } # adjust cursor
        # printf(status ", " b1 ", " b2 ", "  curloc ", " cc ", " length(reply) ", " space) >> "/dev/stderr"
        printf(status) >> "/dev/stderr"
        if (cc < 0) { CUP(dim[1], curloc + 2) } # adjust cursor
        key_last = key
    }

}

function yesno(command) {
    CUP(dim[1], 1)
    printf("%s%s %s? (y/n) ", a_clean, "Really execute command", command) >> "/dev/stderr"
    printf "\033\133?25h" >> "/dev/stderr" # show cursor
    key = key_collect(list, pagerind)
    printf "\033\133?25l" >> "/dev/stderr" # hide cursor
    if (key ~ /[Yy]/) return 1
}

function redraw(tmsg, bmsg) {
    printf "\033\1332J\033\133H" >> "/dev/stderr" # clear screen and move cursor to 0, 0
    CUP(top, 1); print pagearr[curpage] >> "/dev/stderr"
    CUP(top + cursor*num - num, 1); printf "%s%s%s%s", Ncursor ". ", a_reverse, disp[Ncursor], a_reset >> "/dev/stderr"
    CUP(top - 2, 1); print tmsg >> "/dev/stderr"
    CUP(dim[1] - 2, 1); print bmsg >> "/dev/stderr"
    CUP(dim[1], 1)
    # printf "Choose [\033\1331m1-%d\033\133m], current page num is \033\133;1m%d\033\133m, total page num is \033\133;1m%d\033\133m: ", Narr, curpage, page >> "/dev/stderr"
    printf "%sChoose [%s1-%d%s], current page num is %s%d%s, total page num is %s%d%s: ", a_clean, a_bold, Narr, a_reset, a_bold, curpage, a_reset, a_bold, page, a_reset >> "/dev/stderr"
    if (bmsg !~ /Action.*|Selecting\.\.\./ && ! isEmpty(selected)) draw_selected()
    if (bmsg !~ /Action.*|Selecting\.\.\./ && PREVIEW == 1) draw_preview(disp[Ncursor])
}

function menu_TUI(list, delim, num, tmsg, bmsg) {

    menu_TUI_page(list, delim)
    while (answer !~ /^[[:digit:]]+$|\.\.\//) {

        oldCursor = 1;

        ## calculate cursor and Ncursor
        cursor = ( cursor+dispnum*(curpage-1) > Narr ? Narr - dispnum*(curpage-1) : cursor )
        Ncursor = cursor+dispnum*(curpage-1)

        clean_preview()
        redraw(tmsg, bmsg)

        while (1) {

            answer = key_collect(list, pagerind)

            #######################################
            #  Key: entry choosing and searching  #
            #######################################

            if ( answer ~ /^[[:digit:]]$/ || answer == "/" || answer == ":" ) {
                CUP(dim[1], 1)
                if (answer ~ /^[[:digit:]]$/) {
                    # printf "Choose [\033\1331m1-%d\033\133m], current page num is \033\133;1m%d\033\133m, total page num is \033\133;1m%d\033\133m: %s", Narr, curpage, page, answer >> "/dev/stderr"

                    printf "%sChoose [%s1-%d%s], current page num is %s%d%s, total page num is %s%d%s: %s", a_clean, a_bold, Narr, a_reset, a_bold, curpage, a_reset, a_bold, page, a_reset, answer >> "/dev/stderr"
                }
                else {
                    printf "%s%s", a_clean, answer >> "/dev/stderr" # clear line
                }
                printf "\033\133?25h" >> "/dev/stderr" # show cursor

                cmd_mode(list, answer)

                printf "\033\133?25l" >> "/dev/stderr" # hide cursor
                if (reply == "\003") { answer = ""; key = ""; reply = ""; break; }
                answer = cmd_trigger reply; reply = ""; split("", comparr, ":"); cc = 0; dd = 0;


                ## cd
                if (answer ~ /:cd .*/) {
                    old_dir = dir
                    gsub(/:cd /, "", answer)
                    if (answer ~ /^\/.*/) { # full path
                        dir = ( answer ~ /.*\/$/ ? answer : answer "/" )
                    }
                    else {
                        while (answer ~ /^\.\.\/.*/) { # relative path
                            gsub(/[^\/]*\/?$/, "", dir)
                            gsub(/^\.\.\//, "", answer)
                            dir = ( dir == "" ? "/" : dir )
                        }
                        dir = ( answer ~ /.*\/$/ || answer == "" ? dir answer : dir answer "/" )
                    }
                    # empty_selected()
                    tmplist = gen_content(dir, HIDDEN)
                    if (tmplist == "empty") {
                        dir = old_dir
                        # bmsg = sprintf("\033\13338;5;15m\033\13348;5;9m%s\033\133m", "Error: Path Not Exist")
                        bmsg = sprintf("%s%s%s%s", b_red, f_white, "Error: Path Not Exist", a_reset)
                    }
                    else {
                        list = tmplist
                    }
                    menu_TUI_page(list, delim)
                    tmsg = dir;
                    cursor = 1; curpage = (+curpage > +page ? page : curpage);
                    break
                }

                ## cmd mode
                if (answer ~ /:[^[:cntrl:]*]/) {
                    command = substr(answer, 2)
                    savecmd = command; post = ""
                    match(command, /\{\}/)
                    if (RSTART) {
                        post = substr(command, RSTART+RLENGTH+1);
                        command = substr(command, 1, RSTART-2)
                    }
                    if (command ~ /.*\$@.*/) {
                        idx = maxidx(selorder)
                        for (j = 1; j <= idx; j++) {
                            if (selorder[j] == "") continue
                            sellist = sellist " \"" selected[selorder[j]] "\" "
                        }
                        gsub(/\$@/, sellist, command)
                        empty_selected()
                    }
                    if (command in cmdalias) { command = cmdalias[command] }

                    if (command ~ /^rm$|rm .*/) { suc = yesno(command); if (suc == 0) break }

                    gsub(/["]/, "\\\\&", command) # escape special char
                    finale()
                    if (isEmpty(selected)) {
                        # code = system("cd \"" dir "\" && eval \"" command "\" 2>/dev/null")
                        code = system("cd \"" dir "\" && eval \"" command "\"")
                    }
                    else {
                        idx = maxidx(selorder)
                        for (j = 1; j <= idx; j++) {
                            if (selorder[j] == "") continue
                            sel = selorder[j]
                            match(post, /\{\}/)
                            if (RSTART) {
                                post = substr(post, 1, RSTART-1) selected[sel] substr(post, RSTART+RLENGTH)
                            }
                            if (post) {
                                # code = system("cd \"" dir "\" && eval \"" command " \\\"" selected[sel] "\\\" \\\"" post "\\\"\" 2>/dev/null")
                                code = system("cd \"" dir "\" && eval \"" command " \\\"" selected[sel] "\\\" \\\"" post "\\\"\"")
                            }
                            else {
                                # code = system("cd \"" dir "\" && eval \"" command " \\\"" selected[sel] "\\\"\" 2>/dev/null")
                                code = system("cd \"" dir "\" && eval \"" command " \\\"" selected[sel] "\\\"\"")
                            }
                        }
                        empty_selected()
                    }
                    init()

                    list = gen_content(dir, HIDDEN); tmsg = dir;
                    menu_TUI_page(list, delim)
                    if (code > 0) { printf("\n%s", savecmd) >> CMDHIST; close(CMDHIST) }
                    break
                }

                ## search
                if (answer ~ /\/[^[:cntrl:]*]/) {
                    slist = search(list, delim, substr(answer, 2), "")
                    if (slist != "") {
                        menu_TUI_page(slist, delim)
                        cursor = 1; curpage = 1; sind = 1
                    }
                    break
                }

                ## go to page
                if (answer ~ /[[:digit:]]+G$/) {
                    ans = answer; gsub(/G/, "", ans);
                    curpage = (+ans <= +page ? ans : page)
                    break
                }


                if (answer ~ /[[:digit:]]+$/) {
                    if (+answer > +Narr) answer = Narr
                    if (+answer < 1) answer = 1
                    curpage = answer / dispnum
                    curpage = sprintf("%.0f", (curpage == int(curpage)) ? curpage : int(curpage)+1)
                    cursor = answer - dispnum*(curpage-1); answer = ""
                    break
                }
            }

            if (answer ~ /[?]/) { pager(help); break; }

            if (answer == "!") {
                finale()
                system("cd \"" dir "\" && ${SHELL:=/bin/sh}")
                init()
                list = gen_content(dir, HIDDEN)
                menu_TUI_page(list, delim)
                break
            }

            if (answer == "-") {
                if (old_dir == "") break
                TMP = dir; dir = old_dir; old_dir = TMP;
                list = gen_content(dir, HIDDEN)
                menu_TUI_page(list, delim)
                tmsg = dir; bmsg = "Browsing"
                cursor = 1; curpage = (+curpage > +page ? page : curpage);
                break
            }


            ########################
            #  Key: Total Redraw   #
            ########################

            if ( answer == "v" ) { PREVIEW = (PREVIEW == 1 ? 0 : 1); break }
            if ( answer == ">" ) { RATIO = (RATIO > 0.8 ? RATIO : RATIO + 0.05); break }
            if ( answer == "<" ) { RATIO = (RATIO < 0.2 ? RATIO : RATIO - 0.05); break }
            if ( answer == "r" || answer == "." ||
               ( answer == "h" && ( bmsg == "Actions" || sind == 1 ) ) ||
               ( answer ~ /^[[:digit:]]$/ && (+answer > +Narr || +answer < 1 ) ) ) {
               if (answer == ".") { HIDDEN = (HIDDEN == 1 ? 0 : 1); }
               list = gen_content(dir, HIDDEN)
               delim = "\f"; num = 1; tmsg = dir; bmsg = "Browsing"; sind = 0; openind = 0;
               menu_TUI_page(list, delim)
               empty_selected()
               cursor = 1; curpage = (+curpage > +page ? page : curpage);
               break
           }
           if ( answer == "\n" || answer == "l" || answer ~ /\[C/ ) { answer = Ncursor; break }
           if ( answer == "a" ) {
               menu_TUI_page(action, RS)
               tmsg = "Choose an action"; bmsg = "Actions"
               cursor = 1; curpage = 1;
               break
           }
           if ( answer ~ /q|\003/ ) exit
           if ( (answer == "h" || answer ~ /\[D/) && dir != "/" ) { answer = "../"; disp[answer] = "../"; bmsg = ""; break }
           if ( (answer == "h" || answer ~ /\[D/) && dir = "/" ) continue
           if ( (answer == "n" || answer ~ /\[6~/) && +curpage < +page ) { curpage++; break }
           if ( (answer == "n" || answer ~ /\[6~/) && +curpage == +page && cursor != Narr - dispnum*(curpage-1) ) { cursor = ( +curpage == +page ? Narr - dispnum*(curpage-1) : dispnum ); break }
           if ( (answer == "n" || answer ~ /\[6~/) && +curpage == +page && cursor == Narr - dispnum*(curpage-1) ) continue
           if ( (answer == "p" || answer ~ /\[5~/) && +curpage > 1) { curpage--; break }
           if ( (answer == "p" || answer ~ /\[5~/) && +curpage == 1 && cursor != 1 ) { cursor = 1; break }
           if ( (answer == "p" || answer ~ /\[5~/) && +curpage == 1 && cursor == 1) continue
           if ( (answer == "g" || answer ~ /\[H/) && ( curpage != 1 || cursor != 1 ) ) { curpage = 1; cursor = 1; break }
           if ( (answer == "g" || answer ~ /\[H/) && curpage = 1 && cursor == 1 ) continue
           if ( (answer == "G" || answer ~ /\[F/) && ( curpage != page || cursor != Narr - dispnum*(curpage-1) ) ) { curpage = page; cursor = Narr - dispnum*(curpage-1); break }
           if ( (answer == "G" || answer ~ /\[F/) && curpage == page && cursor = Narr - dispnum*(curpage-1) ) continue

            #########################
            #  Key: Partial Redraw  #
            #########################

           if ( (answer == "j" || answer ~ /\[B/) && +cursor <= +dispnum ) { oldCursor = cursor; cursor++; }
           if ( (answer == "j" || answer ~ /\[B/) && +cursor > +dispnum && +curpage < +page && +page > 1 ) { cursor = 1; curpage++; break }
           if ( (answer == "k" || answer ~ /\[A/) && +cursor == 1 && +curpage > 1 && +page > 1 ) { cursor = dispnum; curpage--; break }
           if ( (answer == "k" || answer ~ /\[A/) && +cursor > 1 ) { oldCursor = cursor; cursor--; }

           if ( (answer == "\006") && cursor <= +dispnum ) { oldCursor = cursor; cursor = cursor + move }
           if ( (answer == "\006") && +cursor > +dispnum && +curpage < +page && +page > 1 ) { cursor = cursor - dispnum; curpage++; break }
           if ( (answer == "\006") && +cursor > Narr - dispnum*(curpage-1) && +curpage == +page ) { cursor = ( +curpage == +page ? Narr - dispnum*(curpage-1) : dispnum ); break }
           if ( (answer == "\006") && +cursor == Narr - dispnum*(curpage-1) && +curpage == +page ) break

           if ( (answer == "\025") && cursor >= 1 ) { oldCursor = cursor; cursor = cursor - move }
           if ( (answer == "\025") && +cursor < 1 && +curpage > 1 ) { cursor = dispnum + cursor; curpage--; break }
           if ( (answer == "\025") && +cursor < 1 && +curpage == 1 ) { cursor = 1; break }
           if ( (answer == "\025") && +cursor == 1 && +curpage == 1 ) break

           if ( answer == "H" ) { oldCursor = cursor; cursor = 1; }
           if ( answer == "M" ) { oldCursor = cursor; cursor = ( +curpage == +page ? int((Narr - dispnum*(curpage-1))*0.5) : int(dispnum*0.5) ); }
           if ( answer == "L" ) { oldCursor = cursor; cursor = ( +curpage == +page ? Narr - dispnum*(curpage-1) : dispnum ); }

            ####################
            #  Key: Selection  #
            ####################

           if ( answer == " " ) {
               if (selected[dir,Ncursor] == "") {
                   TMP = disp[Ncursor];
                   gsub(/\033\[[0-9][0-9]m|\033\[[0-9]m|\033\[m/, "", TMP)
                   selected[dir,Ncursor] = dir TMP;
                   seldisp[dir,Ncursor] = TMP;
                   selpage[dir,Ncursor] = curpage;
                   selnum[dir,Ncursor] = Ncursor;
                   selorder[++order] = dir SUBSEP Ncursor
                   bmsg = disp[Ncursor] " selected"
               }
               else {
                   for (idx in selorder) { if (selorder[idx] == dir SUBSEP Ncursor) { delete selorder[idx]; break } }
                   delete selected[dir,Ncursor];
                   delete seldisp[dir,Ncursor];
                   delete selpage[dir,Ncursor];
                   delete selnum[dir,Ncursor];
                   bmsg = disp[Ncursor] " cancelled"
               }
               if (+Narr == 1) { break }
               if (+cursor <= +dispnum || +cursor <= +Narr) { cursor++ }
               if (+cursor > +dispnum || +cursor > +Narr) { cursor = 1; curpage = ( +curpage == +page ? 1 : curpage + 1 ) }
               break
           }

           if (answer == "S") {
               if (isEmpty(selected)) {
                   selp = 0
                   for (entry = 1; entry in disp; entry++) {
                       TMP = disp[entry];
                       gsub(/\033\[[0-9][0-9]m|\033\[[0-9]m|\033\[m/, "", TMP)
                       if (TMP != "./" && TMP != "../") {
                           selected[dir,entry] = dir TMP;
                           seldisp[dir,entry] = TMP;
                           selpage[dir,entry] = ((+entry) % (+dispnum) == 1 ? ++selp : selp)
                           selnum[dir,entry] = entry;
                           selorder[++order] = dir SUBSEP entry
                       }
                   }
                   bmsg = "All selected"
               }
               else {
                   empty_selected()
                   bmsg = "All cancelled"
               }
               break
           }

           if (answer == "s") {
               # for (sel in selected) {
               #     selcontent = selcontent "\n" selected[sel]
               # }
               idx = maxidx(selorder)
               for (j = 1; j <= idx; j++) {
                   if (selorder[j] == "") continue
                   selcontent = selcontent "\n" j ". " selected[selorder[j]]
               }
               pager("Selected item: \n" selcontent); selcontent = ""; break;
           }

            ####################################################################
            #  Partial redraw: tmsg, bmsg, old entry, new entry, and selected  #
            ####################################################################

            Ncursor = cursor+dispnum*(curpage-1); oldNcursor = oldCursor+dispnum*(curpage-1);
            if (Ncursor > Narr) { Ncursor = Narr; cursor = Narr - dispnum*(curpage-1); continue }
            if (Ncursor < 1) { Ncursor = 1; cursor = 1; continue }

            CUP(dim[1] - 2, 1); # bmsg
            printf a_clean >> "/dev/stderr" # clear line
            print bmsg >> "/dev/stderr"

            CUP(top + oldCursor*num - num, 1); # old entry
            for (i = 1; i <= num; i++) {
                printf a_clean >> "/dev/stderr" # clear line
                CUP(top + oldCursor*num - num + i, 1)
            }
            CUP(top + oldCursor*num - num, 1);
            printf "%s", oldNcursor ". " disp[oldNcursor] >> "/dev/stderr"

            CUP(top + cursor*num - num, 1); # new entry
            for (i = 1; i <= num; i++) {
            printf a_clean >> "/dev/stderr" # clear line
            CUP(top + cursor*num - num + i, 1)
            }
            CUP(top + cursor*num - num, 1);
            printf "%s%s%s%s", Ncursor ". ", a_reverse, disp[Ncursor], a_reset >> "/dev/stderr"

            if (bmsg !~ /Action.*|Selecting\.\.\./ && ! isEmpty(selected)) draw_selected()
            if (bmsg !~ /Action.*|Selecting\.\.\./ && PREVIEW == 1) draw_preview(disp[Ncursor])
        }

    }

    result[1] = disp[answer]
    result[2] = bmsg
}

function pager(msg) { # pager to print out stuff and navigate
    printf "\033\1332J\033\133H" >> "/dev/stderr"
    if (PREVIEW == 1) { printf "{\"action\": \"remove\", \"identifier\": \"PREVIEW\"}\n" > FIFO_UEBERZUG; close(FIFO_UEBERZUG) }
    Nmsgarr = split(msg, msgarr, "\n")
    Npager = (Nmsgarr >= dim[1] ? dim[1] : Nmsgarr)
    for (i = 1; i <= Npager; i++) {
        CUP(i, 1)
        printf "%s", msgarr[i] >> "/dev/stderr"
    }

    pagerind = 1;
    while (key = key_collect(list, pagerind)) {
        if (key == "\003" || key == "\033" || key == "q" || key == "h") break
        if ((key == "j" || key ~ /\[B/) && i < Nmsgarr) { printf "\033\133%d;H\n", Npager >> "/dev/stderr"; printf msgarr[i++] >> "/dev/stderr" }
        if ((key == "k" || key ~ /\[A/) && i > dim[1] + 1) { printf "\033\133H\033\133L" >> "/dev/stderr"; i--; printf msgarr[i-dim[1]] >> "/dev/stderr" }
    }
    pagerind = 0;
}

######################
#  Start of Preview  #
######################

function draw_preview(item) {

    border = int(dim[2]*RATIO) # for preview

    # clear RHS of screen based on border
    clean_preview()

    gsub(/\033\[[0-9][0-9]m|\033\[[0-9]m|\033\[m/, "", item)
    path = dir item
    if (path ~ /.*\/$/) { # dir
        content = gen_content(path)
        split(content, prev, "\f")
        for (i = 1; i <= ((end - top) / num); i++) {
            CUP(top + i - 1, border + 1)
            print prev[i] >> "/dev/stderr"
        }
    }
    else { # Standard file
        if (FMAWK_PREVIEWER == "") {
            cmd = "file " path
            cmd | getline props
            if (props ~ /text/) {
                getline content < path
                close(path)
                split(content, prev, "\n")
                for (i = 1; i <= ((end - top) / num); i++) {
                    CUP(top + i - 1, border + 1)
                    code = gsub(/\000/, "", prev[i])
                    if (code > 0) {
                        # printf "\033\13338;5;0m\033\13348;5;15m%s\033\133m", "binary" >> "/dev/stderr"
                        printf "%s%s%s%s", a_reverse, f_white, "binary", a_reset >> "/dev/stderr"
                        break
                    }
                    print prev[i] >> "/dev/stderr"
                }
            }
        }
        else {
            system(FMAWK_PREVIEWER " \"" path "\" \"" CACHE "\" \"" border+1 "\" \"" ((end - top)/num) "\" \"" top "\" \"" dim[2]-border-1 "\"")
        }

    }
}

function clean_preview() {
    for (i = top; i <= end; i++) {
        CUP(i, border - 1)
        printf "\033\133K" >> "/dev/stderr" # clear line
    }
    if (FIFO_UEBERZUG == "") return
    printf "{\"action\": \"remove\", \"identifier\": \"PREVIEW\"}\n" > FIFO_UEBERZUG
    close(FIFO_UEBERZUG)
}
