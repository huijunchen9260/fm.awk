#!/usr/bin/awk -f

BEGIN {

    ###################
    #  Configuration  #
    ###################

    OPENER = ( ENVIRON["OSTYPE"] ~ /darwin.*/ ? "open" : "xdg-open" )

    #######################
    # Start of the script #
    #######################

    init()
    RS = "\n"
    dir = ENVIRON["PWD"] "/"
    list = gen_list(dir)
    delim = "\f"
    num = 1
    tmsg = dir
    bmsg = ""

    while (response = menu_TUI(list, delim, num, tmsg, bmsg)) {
	gsub(/\033\[[0-9];[0-9][0-9]m|\033\[m/, "", response)
	if (response == "../") {
	    gsub(/[^\/]*\/?$/, "", dir)
	    dir = ( dir == "" ? "/" : dir )
	}
	else if (response ~ /.*\/$/) {
	    dir = dir response
	}
	else {
	    restore()
	    system(OPENER " \"" dir response "\"")
	    init()
	}
	list = gen_list(dir)
	delim = "\f"
	num = 1
	tmsg = dir
	bmsg = ""
    }

}

END {
    restore()
}

function restore() {
    printf "\033\1332J" # clear screen
    printf "\033\133?7h" # line wrap
    printf "\033\1338" # restore cursor
    printf "\033\133?1049l" # back from alternate buffer
    ENVIRON["LANG"] = LANG; # restore LANG
}

function init() {
    printf "\033\1332J" # clear screen
    printf "\033\133?1049h" # alternate buffer
    printf "\033\1337" # save cursor
    printf "\033\133?7l" # line wrap
    LANG = ENVIRON["LANG"]; # save LANG
    ENVIRON["LANG"] = C; # simplest locale setting
}

function gen_list(dir) {

    cmd = "for f in " dir "* " dir ".* ; do "\
	      "test \"$f\" \= \".\" || test \"$f\" \= \"..\" && continue; "\
	      "test -L \"$f\" && test -f \"$f\" && printf '\f\033\1331;36m%s\033\133m' \"$f\" && continue; "\
	      "test -L \"$f\" && test -d \"$f\" && printf '\f\033\1331;36m%s\033\133m' \"$f\"/ && continue; "\
	      "test -x \"$f\" && test -f \"$f\" && printf '\f\033\1331;32m%s\033\133m' \"$f\" && continue; "\
	      "test -f \"$f\" && printf '\f%s' \"$f\" && continue; "\
	      "test -d \"$f\" && printf '\f\033\1331;34m%s\033\133m' \"$f\"\/ ; "\
	  "done"
    cmd | getline list
    close(cmd)
    if (dir != "/") {
	gsub(dir, "", list)
    }
    else {
	Narr = split(list, listarr, "\f")
	delete listarr[1]
	list = ""
	for (entry = 2; entry in listarr; entry++) {
	    sub(/\//, "", listarr[entry])
	    list = list "\f" listarr[entry]
	}
    }
    list = substr(list, 2)
    return list

}

##################
#  Start of TUI  #
##################

function CUP(lines, cols) {
    printf("\033\133%s;%sH", lines, cols)
}

function menu_TUI_setup(list, delim) {
    answer = ""; page = 0; split("", pagearr, ":") # delete saved array
    cmd = "stty size"
    cmd | getline d
    close(cmd)
    split(d, dim, " ")
    top = 5; bottom = dim[1] - 4;
    fin = bottom - ( bottom - (top - 1) ) % num; end = fin + 1;
    dispnum = (end - top) / num

    Narr = split(list, disp, delim)
    dispnum = (dispnum <= Narr ? dispnum : Narr)

    # generate display content for each page (pagearr)
    for (entry = 1; entry in disp; entry++) {
	if ((+entry) % (+dispnum) == 1) { # if first item in each page
	    pagearr[++page] = entry ". " disp[entry]
	}
	else {
	    pagearr[page] = pagearr[page] "\n" entry ". " disp[entry]
	}
    }
    curpage = 1;
}

function search(list, delim, str) {
    find = ""; str = tolower(str); regex = ".*" str ".*";
    Narr = split(list, sdisp, delim)

    for (entry = 1; entry in sdisp; entry++) {
	match(tolower(sdisp[entry]), regex)
	if (RSTART) find = find delim sdisp[entry]
    }

    slist = substr(find, 2)
    return slist
}

function menu_TUI(list, delim, num, tmsg, bmsg) {

    cursor = 1
    menu_TUI_setup(list, delim)
    while (answer !~ /^[[:digit:]]+$/) {
	printf "\033\1332J\033\133H" # clear screen and move cursor to 0, 0
	CUP(1, 1);
	hud = "page: [n]ext, [p]rev, [r]eload, [t]op, [b]ottom, [num+G]o; entry: [h/k/j/l]-[←/↑/↓/→], [/]search, [q]uit"
	gsub("[[]", "[\033\1331m", hud); gsub("[]]", "\033\133m]", hud)
	printf hud

	CUP(2, 1)
	hline = sprintf("%" dim[2] "s", "")
	gsub(/ /, "━", hline)
	printf hline
	CUP(top, 1); print pagearr[curpage]
	cursor = ( cursor+dispnum*(curpage-1) > Narr ? Narr - dispnum*(curpage-1) : cursor )
	Ncursor = cursor+dispnum*(curpage-1)
	CUP(top + cursor*num - num, 1); printf "%s\033\1330;7m%s\033\133m", Ncursor ". ", disp[Ncursor]
	CUP(3, 1); print tmsg disp[Ncursor]
	CUP(dim[1] - 2, 1); print bmsg
	CUP(dim[1], 1)

	printf "Choose [\033\1331m1-%d\033\133m], current page num is \033\133;1m%d\033\133m, total page num is \033\133;1m%d\033\133m: ", Narr, curpage, page

	cmd = "saved=$(stty -g); stty raw; dd bs=1 count=1 2>/dev/null; stty \"$saved\""
	cmd | getline answer
	close(cmd)

	if ( answer ~ /[[:digit:]]/ || answer == "/" ) {
	    cmd = "read -r ans; echo \"$ans\""
	    cmd | getline ans
	    close(cmd)
	    answer = answer ans; ans = ""

	    if (answer ~ /\/[^[:cntrl:]*]/) {
		slist = search(list, delim, substr(answer, 2))
		menu_TUI_setup(slist, delim)
		continue
	    }

	    if ( (answer ~ /[[:digit:]]+G/) ) {
		ans = answer; gsub(/G/, "", ans);
		curpage = (+ans <= +page ? ans : page)
		continue
	    }

	    if (+answer > +Narr) answer = Narr
	    if (+answer < 1) answer = 1
	}

	if ( answer == "r" ||
	   ( answer ~ /[[:digit:]]/ && (+answer > +Narr || +answer < 1) ) ) {
	    menu_TUI_setup(list, delim)
	    curpage = (+curpage > +page ? page : curpage)
	}
	if ( answer == "\r" || answer == "l" ) answer = Ncursor
	if ( answer == "q" ) exit
	if ( answer == "h" ) { disp[answer] = "../"; break }
	if ( answer == "j" && +cursor <= +dispnum ) cursor++
	if ( answer == "j" && +cursor > +dispnum  && page > 1 ) { cursor = 1; curpage++ }
	if ( answer == "k" && +cursor == 1  && curpage > 1 && page > 1 ) { cursor = dispnum + 1; curpage-- }
	if ( answer == "k" && +cursor > 1 ) cursor--
	if ( answer == "g" ) cursor = 1
	if ( answer == "G" ) cursor = dispnum
	if ( answer == "n" && +curpage < +page) curpage++
	if ( answer == "p" && +curpage > 1) curpage--
	if ( answer == "t" ) curpage = 1
	if ( answer == "b" ) curpage = page
    }

    return disp[answer]
}
