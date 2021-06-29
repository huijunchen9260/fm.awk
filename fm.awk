#!/usr/bin/awk -f

BEGIN {

    ###################
    #  Configuration  #
    ###################

    OPENER = ( ENVIRON["OSTYPE"] ~ /darwin.*/ ? "open" : "xdg-open" )
    LASTPATH = ( ENVIRON["LASTPATH"] == "" ? ( ENVIRON["HOME"] "/.cache/lastpath" ) : ENVIRON["LASTPATH"] )
    HISTORY = ( ENVIRON["HISTORY"] == "" ? ( ENVIRON["HOME"] "/.cache/history" ) : ENVIRON["HISTORY"] )

    ####################
    #  Initialization  #
    ####################

    init()
    RS = "\a"
    dir = ( ENVIRON["PWD"] == "/" ? "/" : ENVIRON["PWD"] "/" )
    cursor = 1; curpage = 1;

    #############
    #  Actions  #
    #############

    action = "History" RS \
	     "mv" RS \
	     "cp -R" RS \
	     "ln -sf" RS \
	     "rm -rf"

    main();
}

END {
    finale();
    hist_clean();
    if (list != "empty") {
	printf "%s", dir > "/dev/stdout";
	printf "%s", dir > LASTPATH
    }
}

function main() {

    do {

	list = gen_content(dir)
	delim = "\f"; num = 1; tmsg = dir; bmsg = ( bmsg == "" ? "Browsing" : bmsg );
	menu_TUI(list, delim, num, tmsg, bmsg)
	response = result[1]
	bmsg = result[2]

	#######################
	#  Matching: Actions  #
	#######################

	if (bmsg == "Actions") {
	    if (response == "History") { hist_act(); empty_selected(); response = result[1]; bmsg = result[2]; }
	    if (response == "mv" || response == "cp -R" || response == "ln -sf" || response == "rm -rf") {
		if (isEmpty(selected)) {
		    bmsg = sprintf("\033\13338;5;15m\033\13348;5;9m%s\033\133m", "Error: Nothing Selected")
		}
		else if (response == "rm -rf") {
		    act = response
		    list = "Yes" delim "No"; tmsg = "Execute " response "? "; bmsg = "Action: " response
		    menu_TUI(list, delim, num, tmsg, bmsg)
		    if (result[1] == "Yes") {
			for (sel in selected) {
			    system(act " \"" selected[sel] "\"")
			}
		    }
		}
		else {
		    bmsg = "Action: choosing destination";  act = response
		    while (1) {
			list = gen_content(dir); delim = "\f"; num = 1; tmsg = dir;
			menu_TUI(list, delim, num, tmsg, bmsg)
			gsub(/\033\[[0-9];[0-9][0-9]m|\033\[m/, "", result[1])
			if (result[1] == "../") { gsub(/[^\/]*\/?$/, "", dir); dir = ( dir == "" ? "/" : dir ); continue }
			if (result[1] == "./") { bmsg = "Browsing"; break; }
			if (result[1] == "History") { hist_act(); dir = result[1]; continue; }
			if (result[1] ~ /.*\/$/) dir = dir result[1]
		    }
		    for (sel in selected) {
			system(act " \"" selected[sel] "\" \"" dir "\"")
		    }
		    empty_selected()
		    continue
		}
	    }
	}

	########################
	#  Matching: Browsing  #
	########################

	gsub(/\033\[[0-9];[0-9][0-9]m|\033\[m/, "", response)

	if (response == "../") {
	    if (hist != 1) gsub(/[^\/]*\/?$/, "", dir)
	    empty_selected()
	    dir = ( dir == "" ? "/" : dir )
	    printf "%s\n", dir >> HISTORY;
	    cursor = 1; curpage = 1; hist = 0
	    continue
	}

	if (response == "./") {
	    finale()
	    system("cd \"" dir response "\" && ${SHELL:=/bin/sh}")
	    init()
	    continue
	}

	if (response ~ /.*\/$/) {
	    empty_selected()
	    dir = ( hist == 1 ? response : dir response )
	    printf "%s\n", dir >> HISTORY;
	    cursor = 1; curpage = 1; hist = 0
	    continue
	}

	finale()
	system(OPENER " \"" dir response "\"")
	init()

    } while (1)

}

function hist_act() {
    cmd = "sed '1!G;h;$!d' " HISTORY; cmd | getline list; close(cmd)
    list = list "../"; delim = "\n"; num = 1; tmsg = "Choose history: "; bmsg = "Action: " response; hist = 1;
    menu_TUI(list, delim, num, tmsg, bmsg)
}

function hist_clean() {

    hist_max = 5000
    getline hisfile < HISTORY; close(HISTORY);
    N = split(hisfile, hisarr, "\n")
    if (N > hist_max) {
	for (i = N-hist_max; i in hisarr; i++) {
	    histmp = histmp "\n" hisarr[i]
	}
	hisfile = substr(histmp, 2)
	printf "%s", hisfile > HISTORY
    }
}

function gen_content(dir) {

    cmd = "for f in \"" dir "\"* \"" dir "\".* ; do "\
	      "test -L \"$f\" && test -f \"$f\" && printf '\f\033\1331;36m%s\033\133m' \"$f\" && continue; "\
	      "test -L \"$f\" && test -d \"$f\" && printf '\f\033\1331;36m%s\033\133m' \"$f\"/ && continue; "\
	      "test -x \"$f\" && test -f \"$f\" && printf '\f\033\1331;32m%s\033\133m' \"$f\" && continue; "\
	      "test -f \"$f\" && printf '\f%s' \"$f\" && continue; "\
	      "test -d \"$f\" && printf '\f\033\1331;34m%s\033\133m' \"$f\"/ ; "\
	  "done"
    # cmd = "for f in \"" dir "\"* \"" dir "\".* ; do "\
	      # "test -L \"$f\" && test -f \"$f\" && printf '\f\033\1331;36m%s\033\133m' \"$f\" && continue; "\
	      # "test -L \"$f\" && test -d \"$f\" && printf '\f\033\1331;36m%s\033\133m' \"$f\"/ && continue; "\
	      # "test -d \"$f\" && printf '\f\033\1331;34m%s\033\133m' \"$f\"/ && continue; "\
	      # "test -x \"$f\" && printf '\f\033\1331;32m%s\033\133m' \"$f\" && continue; "\
	      # "printf '\f%s' \"$f\" && continue; "\
	  # "done"

    code = cmd | getline list
    close(cmd)
    if (code <= 0) {
	list = "empty"
    }
    else if (dir != "/") {
	gsub(/[\\.^$(){}\[\]|*+?]/, "\\\\&", dir) # escape special char
	gsub(dir, "", list)
	list = substr(list, 2)
    }
    else {
	Narr = split(list, listarr, "\f")
	delete listarr[1]
	list = ""
	for (entry = 2; entry in listarr; entry++) {
	    sub(/\//, "", listarr[entry])
	    list = list "\f" listarr[entry]
	}
	list = substr(list, 2)
    }
    return list

}

# Credit: https://stackoverflow.com/a/20078022
function isEmpty(arr, idx) { for (idx in arr) return 0; return 1 }

##################
#  Start of TUI  #
##################

function finale() {
    printf "\033\1332J\033\133H" > "/dev/stderr" # clear screen
    printf "\033\133?7h" > "/dev/stderr" # line wrap
    printf "\033\1338" > "/dev/stderr" # restore cursor
    printf "\033\133?25h" > "/dev/stderr" # hide cursor
    printf "\033\133?1049l" > "/dev/stderr" # back from alternate buffer
    system("stty icanon echo")
    ENVIRON["LANG"] = LANG; # restore LANG
}

function init() {
    system("stty -icanon -echo")
    printf "\033\1332J\033\133H" > "/dev/stderr" # clear screen
    printf "\033\133?1049h" > "/dev/stderr" # alternate buffer
    printf "\033\1337" > "/dev/stderr" # save cursor
    printf "\033\133?25l" > "/dev/stderr" # hide cursor
    printf "\033\133?7l" > "/dev/stderr" # line wrap
    LANG = ENVIRON["LANG"]; # save LANG
    ENVIRON["LANG"] = C; # simplest locale setting
}


function CUP(lines, cols) {
    printf("\033\133%s;%sH", lines, cols) > "/dev/stderr"
}

function draw_selected() {
    for (sel in selected) {
	if (selpage[sel] == curpage) {
	    CUP(top + (sel-dispnum*(curpage-1))*num - num, 1)
	    for (i = 1; i <= num; i++) {
		printf "\033\1332K" > "/dev/stderr" # clear line
		CUP(top + cursor*num - num + i, 1)
	    }
	    CUP(top + (sel-dispnum*(curpage-1))*num - num, 1)
	    gsub(/\033\[[0-9];[0-9][0-9]m|\033\[m/, "", seldisp[sel])

	    if (cursor == sel-dispnum*(curpage-1)) {
		printf "  \033\1337;31m%s%s\033\133m", sel ". ", seldisp[sel] > "/dev/stderr"
	    }
	    else {
		printf "  \033\1331;31m%s%s\033\133m", sel ". ", seldisp[sel] > "/dev/stderr"
	    }
	}
    }
}

function empty_selected() { split("", selected, ":"); split("", seldisp, ":"); split("", selpage, ":"); }

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

    oldCursor = 1
    menu_TUI_setup(list, delim)
    while (answer !~ /^[[:digit:]]+$|\.\.\//) {

	printf "\033\1332J\033\133H" > "/dev/stderr" # clear screen and move cursor to 0, 0
	CUP(1, 1);
	hud = "page: [n]ext, [p]rev, [r]efresh, [t]op, [b]ottom, [num+G]o; entry: [h/k/j/l]-[←/↑/↓/→], [/]search; [a]ctions, [q]uit"
	gsub("[[]", "[\033\1331m", hud); gsub("[]]", "\033\133m]", hud)
	printf hud > "/dev/stderr"
	CUP(2, 1)
	hline = sprintf("%" dim[2] "s", "")
	gsub(/ /, "━", hline)
	# gsub(/ /, "\x1b(0\x71\x1b(B", hline)
	printf hline > "/dev/stderr"
	CUP(top, 1); print pagearr[curpage] > "/dev/stderr"

	cursor = ( cursor+dispnum*(curpage-1) > Narr ? Narr - dispnum*(curpage-1) : cursor )
	Ncursor = cursor+dispnum*(curpage-1)
	CUP(top + cursor*num - num, 1); printf "%s\033\1337m%s\033\133m", Ncursor ". ", disp[Ncursor] > "/dev/stderr"

	if (bmsg !~ /Action.*/) draw_selected()

	CUP(3, 1); print tmsg disp[Ncursor] > "/dev/stderr"
	CUP(dim[1] - 2, 1); print bmsg > "/dev/stderr"
	CUP(dim[1], 1)
	printf "Choose [\033\1331m1-%d\033\133m], current page num is \033\133;1m%d\033\133m, total page num is \033\133;1m%d\033\133m: ", Narr, curpage, page > "/dev/stderr"

	while (1) {

	    answer = ""
	    do {
		cmd = "dd ibs=1 count=1 2>/dev/null;"
		cmd | getline ans
		close(cmd)
		gsub(/[\\.^$(){}\[\]|*+?]/, "\\\\&", ans) # escape special char
		answer = ( ans ~ /\033/ ? answer : answer ans )
		if (answer ~ /^\\\[5$|^\\\[6$/) ans = ""; continue;
	    } while (ans !~ /[[:space:][:alnum:]~\/]/ )

	    #######################################
	    #  Key: entry choosing and searching  #
	    #######################################


	    if ( answer ~ /^[[:digit:]]$/ || answer == "/" ) {

		system("stty icanon echo")
		CUP(dim[1], 1)
		printf "Choose [\033\1331m1-%d\033\133m], current page num is \033\133;1m%d\033\133m, total page num is \033\133;1m%d\033\133m: %s", Narr, curpage, page, answer > "/dev/stderr"
		printf "\033\133?25h" > "/dev/stderr" # show cursor
		cmd = "read -r ans; echo \"$ans\" 2>/dev/null"
		cmd | getline ans
		close(cmd)
		printf "\033\133?25l" > "/dev/stderr" # hide cursor
		system("stty -icanon -echo")
		answer = answer ans; ans = ""

		if (answer ~ /\/[^[:cntrl:]*]/) {
		    slist = search(list, delim, substr(answer, 2))
		    if (slist != "") menu_TUI_setup(slist, delim)
		    break
		}

		if ( (answer ~ /[[:digit:]]+G/) ) {
		    ans = answer; gsub(/G/, "", ans);
		    curpage = (+ans <= +page ? ans : page)
		    break
		}

		if (+answer > +Narr) answer = Narr
		if (+answer < 1) answer = 1
		break
	    }

	    ########################
	    #  Key: Total Redraw   #
	    ########################

	    if ( answer == "r" ||
	       ( answer ~ /^[[:digit:]]$/ && (+answer > +Narr || +answer < 1) ) ) {
		menu_TUI_setup(list, delim)
		tmsg = dir; bmsg = "Browsing"
		cursor = 1; curpage = (+curpage > +page ? page : curpage);
		break
	    }
	    if ( answer == "\r" || answer == "l" || answer ~ /\[C/ ) { answer = Ncursor; break }
	    if ( answer == "a" ) {
		menu_TUI_setup(action, "\a")
		tmsg = ""; bmsg = "Actions"
		cursor = 1; curpage = 1;
		break
	    }
	    if ( answer == "q" ) exit
	    if ( (answer == "h" || answer ~ /\[D/) && dir != "/" ) { answer = "../"; disp[answer] = "../"; break }
	    if ( (answer == "h" || answer ~ /\[D/) && dir = "/" ) continue
	    if ( (answer == "n" || answer ~ /\[6~/) && +curpage < +page ) { curpage++; break }
	    if ( (answer == "n" || answer ~ /\[6~/) && +curpage == +page && cursor != Narr - dispnum*(curpage-1) ) { cursor = ( +curpage == +page ? Narr - dispnum*(curpage-1) : dispnum ); break }
	    if ( (answer == "n" || answer ~ /\[6~/) && +curpage == +page && cursor = Narr - dispnum*(curpage-1) ) continue
	    if ( (answer == "p" || answer ~ /\[5~/) && +curpage > 1) { curpage--; break }
	    if ( (answer == "p" || answer ~ /\[5~/) && +curpage == 1 && cursor != 1 ) { cursor = 1; break }
	    if ( (answer == "p" || answer ~ /\[5~/) && +curpage == 1 && cursor = 1) continue
	    if ( (answer == "t" || answer ~ /\[H/) && ( curpage != 1 || cursor != 1 ) ) { curpage = 1; cursor = 1; break }
	    if ( (answer == "t" || answer ~ /\[H/) && curpage = 1 && cursor = 1 ) continue
	    if ( (answer == "b" || answer ~ /\[F/) && ( curpage != page || cursor != Narr - dispnum*(curpage-1) ) ) { curpage = page; cursor = Narr - dispnum*(curpage-1); break }
	    if ( (answer == "b" || answer ~ /\[F/) && curpage = page && cursor = Narr - dispnum*(curpage-1) ) continue

	    #########################
	    #  Key: Partial Redraw  #
	    #########################

	    if ( (answer == "j" || answer ~ /\[B/) && +cursor <= +dispnum ) { oldCursor = cursor; cursor++; }
	    if ( (answer == "j" || answer ~ /\[B/) && +cursor > +dispnum  && page > 1 ) { cursor = 1; curpage++; break }
	    if ( (answer == "k" || answer ~ /\[A/) && +cursor == 1  && curpage > 1 && page > 1 ) { cursor = dispnum; curpage--; break }
	    if ( (answer == "k" || answer ~ /\[A/) && +cursor >= 1 ) { oldCursor = cursor; cursor--; }
	    if ( answer == "g" ) { oldCursor = cursor; cursor = 1; }
	    if ( answer == "G" ) { oldCursor = cursor; cursor = ( +curpage == +page ?  Narr - dispnum*(curpage-1) : dispnum ); }
	    if ( answer == " " ) {
		if (selected[Ncursor] == "") {
		    TMP = disp[Ncursor]; gsub(/\033\[[0-9];[0-9][0-9]m|\033\[m/, "", TMP)
		    selected[Ncursor] = dir TMP;
		    seldisp[Ncursor] = TMP;
		    selpage[Ncursor] = curpage;
		    cursor++
		    bmsg = disp[Ncursor] " selected"
		}
		else {
		    delete selected[Ncursor]
		    delete seldisp[Ncursor]
		    delete selpage[Ncursor]
		    cursor++
		    bmsg = disp[Ncursor] " cancelled"
		    break
		}
	    }

	    if (answer == "s") {
		printf "\033\1332J\033\133H"
		for (sel in selected) {
		    print selected[sel]
		}
		cmd = "read -r ans; echo \"$ans\""
		cmd | getline str
		close(cmd)
		break
	    }

	    ####################################################################
	    #  Partial redraw: tmsg, bmsg, old entry, new entry, and selected  #
	    ####################################################################

	    Ncursor = cursor+dispnum*(curpage-1); oldNcursor = oldCursor+dispnum*(curpage-1);
	    if (Ncursor > Narr) { Ncursor = Narr; cursor = Narr - dispnum*(curpage-1); continue }
	    if (Ncursor < 1) { Ncursor = 1; cursor = 1; continue }

	    CUP(3, 1); # tmsg
	    printf "\033\1332K" > "/dev/stderr" # clear line
	    print tmsg disp[Ncursor] > "/dev/stderr"

	    CUP(dim[1] - 2, 1); # bmsg
	    printf "\033\1332K" > "/dev/stderr" # clear line
	    print bmsg > "/dev/stderr"

	    CUP(top + oldCursor*num - num, 1); # old entry
	    for (i = 1; i <= num; i++) {
		printf "\033\1332K" > "/dev/stderr" # clear line
		CUP(top + oldCursor*num - num + i, 1)
	    }
	    CUP(top + oldCursor*num - num, 1);
	    printf "%s", oldNcursor ". " disp[oldNcursor] > "/dev/stderr"

	    CUP(top + cursor*num - num, 1); # new entry
	    for (i = 1; i <= num; i++) {
		printf "\033\1332K" > "/dev/stderr" # clear line
		CUP(top + cursor*num - num + i, 1)
	    }
	    CUP(top + cursor*num - num, 1);
	    printf "%s\033\1337m%s\033\133m", Ncursor ". ", disp[Ncursor] > "/dev/stderr"

	    if (bmsg !~ /Action.*/) draw_selected()

	}

    }

    result[1] = disp[answer]
    result[2] = bmsg
}


function notify(msg, str) {

    printf "\033\1332J\033\133H"
    RS = "\n" # stop getline by enter
    print msg
    system("stty icanon echo")
    printf "\033\133?25h" > "/dev/stderr" # show cursor
    cmd = "read -r ans; echo \"$ans\""
    cmd | getline str
    close(cmd)
    printf "\033\133?25l" > "/dev/stderr" # hide cursor
    RS = "\f"
    system("stty -icanon -echo")
    return str
}

