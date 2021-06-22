#!/usr/bin/mawk -f

BEGIN {

    #######################
    # Start of the script #
    #######################

    LANG = ENVIRON["LANG"];		# save LANG
    ENVIRON["LANG"] = C;		# simplest locale setting
    RS = "\n"
    dir = ENVIRON["PWD"] "/"
    list = gen_list(dir)
    list = "../" list
    delim = "\f"
    num = 1
    tmsg = dir
    bmsg = "HJC"

    while (response = menu_TUI(list, delim, num, tmsg, bmsg)) {

	if (response == "../") {
	    gsub(/[^\/]*\/?$/, "", dir)
	    dir = ( dir == "" ? "/" : dir )
	}
	else {
	    dir = dir response
	    # dir = ( dir == "/" ? dir response "/" : dir response )
	}
	list = gen_list(dir)
	list = "../" list
	delim = "\f"
	num = 1
	tmsg = dir
	bmsg = "HJC"

    }

}

END {
    printf "\033\1332J" # clear screen
    printf "\033\133?7h" # line wrap
    printf "\033\1338" # restore cursor
    printf "\033\133?1049l" # back from alternate buffer
    ENVIRON["LANG"] = LANG; # restore LANG
}

function gen_list(dir) {

    Dirs = ""; Files = ""; DotDirs = ""; DotFiles = "";
    cmd = "printf '\f%s' " dir "*/"
    cmd | getline Dirs
    close(cmd)
    cmd = "printf '\f%s' " dir ".*/"
    cmd | getline DotDirs
    close(cmd)
    cmd = "for f in " dir "*; do test -f \"$f\" && printf '\f%s' \"$f\"; done"
    cmd | getline Files
    close(cmd)
    cmd = "for f in " dir ".*; do test -f \"$f\" && printf '\f%s' \"$f\"; done"
    cmd | getline DotFiles
    close(cmd)
    list = Dirs Files DotDirs DotFiles
    if (dir != "/") gsub(dir, "", list)
    else gsub("\f\/", "\f", list)
    return list

}

##################
#  Start of TUI  #
##################

function clear_screen() { # clear screen and move cursor to 0, 0
    printf "\033\1332J\033\133H"
}

function CUP(lines, cols) {
    printf("\033\133%s;%sH", lines, cols)
}

function menu_TUI_setup(list, delim) {
    answer = ""
    page = 0
    split("", pagearr, ":") # delete saved array
    clear_screen()
    printf "\033\133?7l" # line unwrap
    cmd = "stty size"
    cmd | getline d
    close(cmd)
    split(d, dim, " ")
    top = 5; bottom = dim[1] - 4;
    fin = bottom - ( bottom - (top - 1) ) % num; end = fin + 1;
    dispnum = (end - top) / num

    Narr = split(list, disp, delim)

    # generate display content for each page (pagearr)
    for (entry = 1; entry <= Narr; entry++) {
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

    for (entry = 1; entry <= Narr; entry++) {
	match(tolower(sdisp[entry]), regex)
	if (RSTART) find = find delim sdisp[entry]
    }

    slist = substr(find, 2)
    return slist
}

function menu_TUI(list, delim, num, tmsg, bmsg) {

    printf "\033\133?1049h" # alternate buffer
    printf "\033\1337" # save cursor
    menu_TUI_setup(list, delim)
    while (answer !~ /^[[:digit:]]+$/) {
	clear_screen()
	CUP(1, 1);
	hud = "page: [n]ext, [p]rev, [r]eload, [t]op, [b]ottom, [num+G]o; entry: [f]irst, [l]ast, [/]search, [q]uit"
	gsub("[[]", "[\033\1331m", hud); gsub("[]]", "\033\133m]", hud)
	printf hud

	CUP(2, 1)
	hline = sprintf("%" dim[2] "s", "")
	gsub(/ /, "━", hline)
	printf hline
	CUP(3, 1); print tmsg
	CUP(top, 1); print pagearr[curpage]
	CUP(dim[1] - 2, 1); print bmsg
	CUP(dim[1], 1)

	printf "Choose [\033\133;1m1-%d\033\133m], current page num is \033\133;1m%d\033\133m, total page num is \033\133;1m%d\033\133m: ", Narr, curpage, page

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
	   ( answer ~ /[[:digit:]]/ && (+answer > +Narr || +answer < +1) ) ) {
	    menu_TUI_setup(list, delim)
	    curpage = (+curpage > +page ? page : curpage)
	}
	if ( answer == "\r" && +Narr == 1 ) answer = 1
	if ( answer == "q" ) exit
	if ( answer == "f" ) answer = 1
	if ( answer == "l" ) answer = Narr
	if ( (answer == "n" || answer == "j") && +curpage < +page) curpage++
	if ( (answer == "p" || answer == "k") && +curpage > 1) curpage--
	if ( (answer == "t" || answer == "g") ) curpage = 1
	if ( (answer == "b" || answer == "G") ) curpage = page
    }

    return disp[answer]
}

function notify(msg, str) {
    system("stty -cread icanon echo 1>/dev/null 2>&1")
    print msg
    getline str < "-"
    return str
    system("stty sane")
}
