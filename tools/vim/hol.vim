if exists("b:did_hol")
  finish
endif

if $HOLDIR == ""
  echoe "HOLDIR is not set"
  finish
endif

let s:holpipe = $HOLDIR . "/fifo"
let s:holtogglequiet = "val _ = HOL_Interactive.toggle_quietdec();"

new
set buftype=nofile
set bufhidden=hide
set noswapfile
let s:holnr = bufnr("")
hide

fu! TempName()
  let l:n = 0
  while glob("/tmp/vimhol".l:n) != ""
    let l:n = l:n + 1
  endwhile
  return "/tmp/vimhol".l:n
endf

fu! HOLCStart()
  let s:prev = bufnr("")
  let s:wins = winsaveview()
  silent exe "keepjumps hide bu" s:holnr
  keepjumps %d_
endf

fu! HOLCRestore()
  silent exe "w>>" . s:holpipe
  silent exe "keepjumps bu" s:prev
  call winrestview(s:wins)
endf

fu! HOLCEnd()
  let s:temp = TempName()
  silent exe "w" . s:temp
  keepjumps %d_
  silent exe "normal iReadFile " . s:temp
  call HOLCRestore()
endf

fu! HOLLoadSetup()
  keepjumps silent normal P
  keepjumps silent %s/\s/\r/ge
  keepjumps silent %s/\<local\>\|\<open\>\|\<in\>\|\<end\>\|;//ge
  keepjumps silent g/^\s*$/d_
  keepjumps silent g/./normal ival _ = load"
  keepjumps silent g/./normal $a";
endf

fu! HOLLoad()
  call HOLLoadSetup()
  call HOLLoadMessage("HOLLoad",line("$")-1)
endf

fu! HOLLoadSendQuiet()
  call HOLLoadSetup()
  exe "keepjumps normal Go" . s:holtogglequiet
  let l:l = line(".")-1
  silent normal op
  exe "keepjumps normal Go" . s:holtogglequiet
  call HOLLoadMessage("HOLLoadSendQuiet",line(".")-1)
endf

fu! HOLLoadMessage(s,l)
  keepjumps normal Goval _ = print "
  execute "normal a" . a:s
  execute "keepjumps silent 1," . a:l . "g/./normal f\"yi\"G$a p"
  keepjumps normal G$a completed\n";
endf

fu! HOLSend()
  silent normal P
  call HOLEnsureEnd()
endf

fu! HOLEnsureEnd()
  keepjumps normal G$a;
endf

fu! HOLSendQuiet()
  call HOLSend()
  exe "keepjumps normal ggO" . s:holtogglequiet
  exe "keepjumps normal Go" . s:holtogglequiet
endf

fu! HOLFSend(f)
  exe "keepjumps normal" "i" . a:f . "("
  silent normal p
  keepjumps normal Go);
endf

fu! HOLSubgoal()
  keepjumps normal ie(
  silent normal p
  keepjumps normal Goby ALL_TAC);
endf

fu! HOLF(f)
  exe "normal i" . a:f
endf

fu! YankThenHOLCall(f,a) range
  silent normal gvy
  call HOLCall(a:f,a:a)
  exe "normal gv\<Esc>"
endf

fu! HOLCall(f,a)
  call HOLCStart()
  call call(a:f,a:a)
  call HOLCEnd()
endf

fu! HOLRepeat(s)
  call HOLCStart()
  exe "normal" v:count1 . "i" . a:s
  call HOLCEnd()
endf

fu! HOLRotate()
  call HOLCStart()
  exe "normal ir(" . v:count1 .");"
  call HOLCEnd()
endf

fu! HOLINT()
  call HOLCStart()
  normal iInterrupt
  call HOLCRestore()
endf

vn <silent> Hl :call YankThenHOLCall(function("HOLLoad"),[])<CR>
vn <silent> HL :call YankThenHOLCall(function("HOLLoadSendQuiet"),[])<CR>
vn <silent> HS :call YankThenHOLCall(function("HOLSend"),[])<CR>
vn <silent> HU :call YankThenHOLCall(function("HOLSendQuiet"),[])<CR>
vn <silent> He :call YankThenHOLCall(function("HOLFSend"),["e"])<CR>
vn <silent> Hg :call YankThenHOLCall(function("HOLFSend"),["g"])<CR>
vn <silent> Hs :call YankThenHOLCall(function("HOLSubgoal"),[])<CR>
nn <silent> Hb :<C-U>call HOLRepeat("b();")<CR>
nn <silent> Hd :<C-U>call HOLRepeat("drop();")<CR>
nn <silent> Hp :call HOLCall(function("HOLF"),["p();"])<CR>
nn <silent> HR :call HOLCall(function("HOLF"),["restart();"])<CR>
nn <silent> Hr :<C-U>call HOLRotate()<CR>
nn <silent> Hc :call HOLINT()<CR>

let b:did_hol = 1