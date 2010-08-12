" Vim script.
" Author: Peter Odding <peter@peterodding.com>
" Last Change: August 12, 2010
" URL: http://peterodding.com/code/vim/lua-inspect/
" License: MIT

let s:script = expand('<sfile>:p:~')

function! luainspect#auto_enable() " {{{1
  if !&diff && !exists('b:luainspect_disabled')
    " Disable easytags.vim because it doesn't play nice with luainspect.vim!
    let b:easytags_nohl = 1
    " Define buffer local mappings for rename / goto definition features.
    inoremap <buffer> <silent> <F2> <C-o>:call luainspect#make_request('rename')<CR>
    nnoremap <buffer> <silent> <F2> :call luainspect#make_request('rename')<CR>
    nnoremap <buffer> <silent> gd :call luainspect#make_request('goto')<CR>
    " Enable balloon evaluation / dynamic tool tips.
    setlocal ballooneval balloonexpr=LuaInspectToolTip()
    " Install automatic commands to update the highlighting.
    for event in split(g:lua_inspect_events, ',')
      execute 'autocmd!' event '<buffer> LuaInspect'
    endfor
  endif
endfunction

function! luainspect#highlight_cmd(disable) " {{{1
  if a:disable
    call s:clear_previous_matches()
    unlet! b:luainspect_input b:luainspect_output
    let b:luainspect_disabled = 1
  else
    unlet! b:luainspect_disabled
    let starttime = xolox#timer#start()
    call luainspect#make_request('highlight')
    let bufname = expand('%:p:~')
    let msg = "%s: Highlighted %s in %s."
    call xolox#timer#stop(msg, s:script, bufname, starttime)
  endif
endfunction

function! luainspect#make_request(action) " {{{1
  if a:action == 'tooltip'
    let lines = getbufline(v:beval_bufnr, 1, "$")
    call insert(lines, v:beval_col)
    call insert(lines, v:beval_lnum)
  else
    let lines = getline(1, "$")
    call insert(lines, col('.'))
    call insert(lines, line('.'))
  endif
  call insert(lines, a:action)
  call s:parse_text(join(lines, "\n"), s:prepare_search_path())
  if !empty(b:luainspect_output)
    let response = b:luainspect_output[0]
    if response == 'syntax_error' && len(b:luainspect_output) >= 4
      " Never perform syntax error highlighting in non-Lua buffers!
      let linenum = b:luainspect_output[1] + 0
      let colnum = b:luainspect_output[2] + 0
      let linenum2 = b:luainspect_output[3] + 0
      let b:luainspect_syntax_error = b:luainspect_output[4]
      if a:action != 'tooltip' || v:beval_bufnr == bufnr('%')
        let error_cmd = 'syntax match luaInspectSyntaxError /\%%>%il\%%<%il.*/ containedin=ALLBUT,lua*Comment*'
        execute printf(error_cmd, linenum - 1, (linenum2 ? linenum2 : line('$')) + 1)
      endif
      " But always let the user know that a syntax error exists.
      let bufname = fnamemodify(bufname(a:action != 'tooltip' ? '%' : v:beval_bufnr), ':p:~')
      call xolox#warning("Syntax error around line %i in %s: %s", linenum, bufname, b:luainspect_syntax_error)
      return
    endif
    unlet! b:luainspect_syntax_error
    if response == 'highlight'
      call s:define_default_styles()
      call s:clear_previous_matches()
      call s:highlight_variables()
    elseif response == 'goto'
      if len(b:luainspect_output) < 3
        call xolox#warning("No variable under cursor!")
      else
        let linenum = b:luainspect_output[1] + 0
        let colnum = b:luainspect_output[2] + 0
        call setpos('.', [0, linenum, colnum, 0])
        call xolox#message("") " Clear any previous message to avoid confusion.
      endif
    elseif response == 'tooltip'
      if len(b:luainspect_output) > 1
        return join(b:luainspect_output[1:-1], "\n")
      endif
    elseif response == 'rename'
      if len(b:luainspect_output) == 1
        call xolox#warning("No variable under cursor!")
      else
        call s:rename_variable()
      endif
    endif
  endif
endfunction

function! s:prepare_search_path() " {{{1
  let code = ''
  if !(has('lua') && g:lua_inspect_internal && exists('s:changed_path'))
    let template = 'package.path = ''%s/?.lua;'' .. package.path'
    let code = printf(template, escape(expand(g:lua_inspect_path), '"\'''))
    if has('lua') && g:lua_inspect_internal
      execute 'lua' code
      let s:changed_path = 1
    endif
  endif
  return code
endfunction

function! s:parse_text(input, search_path) " {{{1
  if !(exists('b:luainspect_input') && b:luainspect_input == a:input)
    if !(has('lua') && g:lua_inspect_internal)
      let template = 'lua -e "%s; require ''luainspect4vim'' (io.read ''*a'')"'
      let command = printf(template, a:search_path)
      try
        let b:luainspect_output = xolox#shell#execute(command, 1, a:input)
      catch /^Vim\%((\a\+)\)\=:E117/
        " Ignore missing shell.vim plug-in.
        let b:luainspect_output = split(system(command, a:input), "\n")
        if v:shell_error
          let msg = "Failed to execute luainspect as external process! %s"
          throw printf(msg, strtrans(join(b:luainspect_output, "\n")))
        endif
      endtry
    else
      redir => output
      silent lua require 'luainspect4vim' (vim.eval 'a:input')
      redir END
      let b:luainspect_output = split(output, "\n")
    endif
    " Remember the text that was just parsed.
    let b:luainspect_input = a:input
  endif
endfunction

function! s:define_default_styles() " {{{1
  " Always define the default highlighting styles
  " (copied from /luainspect/scite.lua for consistency).
  for [group, styles] in items(s:groups)
    let group = 'luaInspect' . group
    if type(styles) == type('')
      let defgroup = styles
    else
      let defgroup = 'luaInspectDefault' . group
      let style = &bg == 'light' ? styles[0] : styles[1]
      execute 'highlight' defgroup style
    endif
    " Don't link the actual highlighting styles to the defaults if the user
    " has already defined or linked the highlighting group. This enables color
    " schemes and vimrc scripts to override the styles (see :help :hi-default).
    execute 'highlight def link' group defgroup
    unlet styles " to avoid E706.
  endfor
endfunction

function! s:clear_previous_matches() " {{{1
  " Clear existing highlighting.
  for group in keys(s:groups)
    let group = 'luaInspect' . group
    if hlexists(group)
      execute 'syntax clear' group
    endif
  endfor
endfunction

function! s:highlight_variables() " {{{1
  call clearmatches()
  for line in b:luainspect_output[1:-1]
    if s:check_output(line, '^\w\+\(\s\+\d\+\)\{3}$')
      let [group, linenum, firstcol, lastcol] = split(line)
      let pattern = s:highlight_position(linenum + 0, firstcol - 1, lastcol + 2)
      if group == 'luaInspectWrongArgCount'
        call matchadd(group, pattern)
      elseif group == 'luaInspectSelectedVariable' 
        call matchadd(group, pattern, 20)
      else
        execute 'syntax match' group '/' . pattern . '/'
      endif
    endif
  endfor
endfunction

function! s:rename_variable() " {{{1
  " Highlight occurrences of variable before rename.
  let highlights = []
  for line in b:luainspect_output[1:-1]
    if s:check_output(line, '^\d\+\(\s\+\d\+\)\{2}$')
      let [linenum, firstcol, lastcol] = split(line)
      let pattern = s:highlight_position(linenum + 0, firstcol - 1, lastcol + 2)
      call add(highlights, matchadd('IncSearch', pattern))
    endif
  endfor
  redraw
  " Prompt for new name.
  let oldname = expand('<cword>')
  let prompt = "Please enter the new name for %s: "
  let newname = input(printf(prompt, oldname), oldname)
  " Clear highlighting of occurrences.
  call map(highlights, 'matchdelete(v:val)')
  " Perform rename?
  if newname != '' && newname != oldname
    let num_renamed = 0
    for fields in reverse(b:luainspect_output[1:-1])
      let [linenum, firstcol, lastcol] = split(fields)
      let linenum += 0
      let firstcol -= 2
      let lastcol += 0
      let line = getline(linenum)
      let prefix = firstcol > 0 ? line[0 : firstcol] : ''
      let suffix = lastcol < len(line) ? line[lastcol : -1] : ''
      call setline(linenum, prefix . newname . suffix)
      let num_renamed += 1
    endfor
    let msg = "Renamed %i occurrences of %s to %s"
    call xolox#message(msg, num_renamed, oldname, newname)
  endif
endfunction

function! s:check_output(line, pattern) " {{{1
  if match(a:line, a:pattern) >= 0
    return 1
  else
    call xolox#warning("Invalid output from luainspect4vim.lua: '%s'", strtrans(a:line))
    return 0
  endif
endfunction

function! s:highlight_position(linenum, firstcol, lastcol) " {{{1
  return printf('\%%%il\%%>%ic\<\w\+\>\%%<%ic', a:linenum, a:firstcol, a:lastcol)
endfunction

" Highlighting groups and their default light/dark styles. {{{1

let s:groups = {}
let s:groups['GlobalDefined'] = ['guifg=#600000', 'guifg=#ffc080']
let s:groups['GlobalUndefined'] = 'ErrorMsg'
let s:groups['LocalUnused'] = ['guifg=#ffffff guibg=#000080', 'guifg=#ffffff guibg=#000080']
let s:groups['LocalMutated'] = ['gui=italic guifg=#000080', 'gui=italic guifg=#c0c0ff']
let s:groups['UpValue'] = ['guifg=#0000ff', 'guifg=#e8e8ff']
let s:groups['Param'] = ['guifg=#000040', 'guifg=#8080ff']
let s:groups['Local'] = ['guifg=#000040', 'guifg=#c0c0ff']
let s:groups['FieldDefined'] = ['guifg=#600000', 'guifg=#ffc080']
let s:groups['FieldUndefined'] = ['guifg=#c00000', 'guifg=#ff0000']
let s:groups['SelectedVariable'] = 'CursorLine'
let s:groups['SyntaxError'] = 'SpellBad'
let s:groups['WrongArgCount'] = 'SpellLocal'
