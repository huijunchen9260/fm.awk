#!/usr/bin/awk -f

BEGIN {

    #######################
    # Start of the script #
    #######################

    RS = "\n"
    dir = ENVIRON["PWD"] "/"
    gen_list(dir)
    list =  "../" Dirs Files DotDirs DotFiles
    delim = "\f"
    num = 1
    tmsg = dir
    bmsg = ""

    while (response = menu_TUI(list, delim, num, tmsg, bmsg)) {

	if (response == "../") {
	    gsub(/[^\/]*\/?$/, "", dir)
	    dir = ( dir == "" ? "/" : dir )
	}
	else {
	    dir = dir response
	}
	gen_list(dir)
	list =  "../" Dirs Files DotDirs DotFiles
	delim = "\f"
	num = 1
	tmsg = dir
	bmsg = ""

    }

}

END {
    printf "\033\1332J" # clear screen
    printf "\033\133?7h" # line wrap
    printf "\033\1338" # restore cursor
    printf "\033\133?1049l" # back from alternate buffer
    system("stty " tty_setting)
}

function gen_list(dir) {

    Dirs = ""; Files = ""; DotDirs = ""; DotFiles = "";

    cmd = "printf '%s\f' " dir "/.* " dir "/*"
    cmd | getline content
    close(cmd)
    gsub(dir "/", "", content)
    num = split(content, arr, "\f")
    delete arr[num]
    for (key in arr) {
        if (getline < arr[key] > 0) { # can read -> is file
	    if (arr[key] ~ /^\..*$/) DotFiles = DotFiles "\f" arr[key]
	    else Files = Files "\f" arr[key]
        }
	else { # cannot read -> is dir
	    if (arr[key] ~ /^[.][^.].*$/) DotDirs = DotDirs "\f" arr[key] "/"
	    else if (arr[key] ~ /^[^.].*$/) Dirs = Dirs "\f" arr[key] "/"
	}
    }
    return Dirs Files DotDirs DotFiles

}

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

    split(list, disp, delim)

    # generate display content for each page (pagearr)
    for (entry in disp) {
	if ((+entry) % (dispnum) == 1) { # if first item in each page
	    pagearr[++page] = entry ". " disp[entry]
	}
	else {
	    pagearr[page] = pagearr[page] "\n" entry ". " disp[entry]
	}
    }
    cur = 1
}

function search(list, delim, str) {
    find = ""; str = tolower(str); regex = ".*" str ".*";
    split(list, sdisp, delim)
    for (entry in sdisp) {
	match(tolower(sdisp[entry]), regex)
	if (RSTART) find = find delim sdisp[entry]
    }
    slist = substr(find, 2)
    return slist
}

function menu_TUI(list, delim, num, tmsg, bmsg) {

    ## save tty setting
    cmd = "stty -g"
    cmd | getline tty_setting
    system("stty -cread icanon echo 1>/dev/null 2>&1")

    printf "\033\133?1049h" # alternate buffer
    printf "\033\1337" # save cursor
    cur = 1
    menu_TUI_setup(list, delim)
    while (answer !~ /^[[:digit:]]+$/) {
	clear_screen()
	CUP(1, 1);
	printf "page: "\
	       "[\033\1331mn\033\133m]ext, "\
	       "[\033\1331mp\033\133m]rev, "\
	       "[\033\1331mr\033\133m]eload, "\
	       "[\033\1331mt\033\133m]op, "\
	       "[\033\1331mb\033\133m]ottom, "\
	       "[\033\1331m[0-9]G\033\133m]o; "\
	       "entry: "\
	       "[\033\1331mf\033\133m]irst, "\
	       "[\033\1331ml\033\133m]ast, "\
	       "[\033\1331m/\033\133m]search, " \
	       "[\033\1331mq\033\133m]uit"
	CUP(3, 1); print tmsg
	CUP(dim[1] - 2, 1); print bmsg
	CUP(top, 1); print pagearr[cur]
	CUP(dim[1], 1)
	printf "Choose [\033\133;1m1-%d\033\133m], "\
	       "current page num is \033\133;1m%d\033\133m, "\
	       "total page num is \033\133;1m%d\033\133m: ", \
	       entry, cur, page

	cmd = "saved=$(stty -g); stty raw; var=$(dd bs=1 count=1 2>/dev/null); stty \"$saved\"; printf '%s' \"$var\""
	cmd | getline answer
	close(cmd)

	if ( answer ~ /[[:digit:]]/ || answer == "/" ) {
	    getline ans < "-"
	    answer = answer ans; ans = ""

	    if (answer ~ /\/[^[:cntrl:]*]/) {
		slist = search(list, delim, substr(answer, 2))
		menu_TUI_setup(slist, delim)
		cur = 1
		continue
	    }

	    if ( (answer ~ /[[:digit:]]+G/) ) {
		ans = answer; gsub(/G/, "", ans);
		cur = (+ans <= +page ? ans : page)
		continue
	    }

	    if (+answer > +entry) answer = entry
	    if (+answer < 1) answer = 1
	}

	if ( answer == "r" ||
	   ( answer ~ /[[:digit:]]/ && (+answer > +entry || +answer < +1) ) ) {
	    menu_TUI_setup(list, delim)
	    cur = (+cur > +page ? page : cur)
	}
	if ( answer == "" && +entry == 1 ) answer = 1
	if ( answer == "q" ) exit
	if ( answer == "f" ) answer = 1
	if ( answer == "l" ) answer = entry
	if ( (answer == "n" || answer == "j") && +cur < +page) cur++
	if ( (answer == "p" || answer == "k") && +cur > 1) cur--
	if ( (answer == "t" || answer == "g") ) cur = 1
	if ( (answer == "b" || answer == "G") ) cur = page
    }

    return disp[answer]
}
