" Vim script.
" Author: Peter Odding <peter@peterodding.com>
" Last Change: June 17, 2014
" URL: http://peterodding.com/code/vim/lua-inspect/

let g:xolox#luainspect#version = '0.5.2'

function! xolox#luainspect#toggle_cmd() " {{{1
  if !(exists('b:luainspect_disabled') && b:luainspect_disabled)
    " Enabled -> disabled.
    call xolox#luainspect#highlight_cmd(1)
  else
    " Disabled -> enabled.
    call xolox#luainspect#highlight_cmd(0)
  endif
endfunction

function! xolox#luainspect#auto_enable() " {{{1
  if !&diff && !exists('b:luainspect_disabled')
    " Disable easytags.vim because it doesn't play nice with luainspect.vim!
    let b:easytags_nohl = 1
    " Define buffer local mappings for rename / goto definition features.
    if g:lua_inspect_mappings
      inoremap <buffer> <silent> <F2> <C-o>:LuaInspectRename<CR>
      nnoremap <buffer> <silent> <F2> :LuaInspectRename<CR>
      nnoremap <buffer> <silent> gd :LuaInspectGoTo<CR>
    endif
    " Enable balloon evaluation / dynamic tool tips.
    if has('balloon_eval')
      setlocal ballooneval balloonexpr=LuaInspectToolTip()
    endif
    " Install automatic commands to update the highlighting.
    for event in split(g:lua_inspect_events, ',')
      execute 'autocmd!' event '<buffer> LuaInspect'
    endfor
  endif
endfunction

function! xolox#luainspect#highlight_cmd(disable) " {{{1
  if a:disable
    call s:clear_previous_matches()
    unlet! b:luainspect_input
    unlet! b:luainspect_output
    unlet! b:luainspect_warnings
    let b:luainspect_disabled = 1
  else
    unlet! b:luainspect_disabled
    call xolox#luainspect#make_request('highlight')
  endif
endfunction

function! xolox#luainspect#make_request(action) " {{{1
  let starttime = xolox#misc#timer#start()
  let bufnr = a:action != 'tooltip' ? bufnr('%') : v:beval_bufnr
  let bufname = bufname(bufnr)
  if bufname != ''
    let bufname = fnamemodify(bufname, ':p')
  endif
  if a:action == 'tooltip'
    let lines = getbufline(v:beval_bufnr, 1, "$")
    call insert(lines, v:beval_col)
    call insert(lines, v:beval_lnum)
  else
    let lines = getline(1, "$")
    call insert(lines, col('.'))
    call insert(lines, line('.'))
  endif
  call insert(lines, bufname)
  call insert(lines, a:action)
  call s:parse_text(join(lines, "\n"), s:prepare_search_path())
  if !empty(b:luainspect_output)
    let response = b:luainspect_output[0]
    if bufname == ''
      let friendlyname = 'buffer #' . bufnr
    else
      let friendlyname = fnamemodify(bufname, ':~')
    endif
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
      call xolox#misc#timer#stop("luainspect.vim %s: Found a syntax error in %s in %s.", g:xolox#luainspect#version, friendlyname, starttime)
      " But always let the user know that a syntax error exists.
      call xolox#misc#msg#warn("luainspect.vim %s: Syntax error around line %i in %s: %s", g:xolox#luainspect#version, linenum, friendlyname, b:luainspect_syntax_error)
      return
    endif
    unlet! b:luainspect_syntax_error
    if response == 'highlight'
      call s:define_default_styles()
      call s:clear_previous_matches()
      call s:highlight_variables()
      call xolox#misc#timer#stop("luainspect.vim %s: Highlighted variables in %s in %s.", g:xolox#luainspect#version, friendlyname, starttime)
    elseif response == 'go_to'
      if len(b:luainspect_output) < 3
        call xolox#misc#msg#warn("luainspect.vim %s: No variable under cursor!", g:xolox#luainspect#version)
      else
        let linenum = b:luainspect_output[1] + 0
        let colnum = b:luainspect_output[2] + 1
        call setpos('.', [0, linenum, colnum, 0])
        call xolox#misc#timer#stop("luainspect.vim %s: Jumped to definition in %s in %s.", g:xolox#luainspect#version, friendlyname, starttime)
        if &verbose == 0
          " Clear previous "No variable under cursor!" message to avoid confusion.
          redraw | echo ""
        endif
      endif
    elseif response == 'tooltip'
      if len(b:luainspect_output) > 1
        call xolox#misc#timer#stop("luainspect.vim %s: Rendered tool tip for %s in %s.", g:xolox#luainspect#version, friendlyname, starttime)
        return join(b:luainspect_output[1:-1], "\n")
      endif
    elseif response == 'rename'
      if len(b:luainspect_output) > 1
        call xolox#misc#timer#stop("luainspect.vim %s: Prepared for rename in %s in %s.", g:xolox#luainspect#version, friendlyname, starttime)
        call s:rename_variable()
      else
        call xolox#misc#msg#warn("luainspect.vim %s: No variable under cursor!", g:xolox#luainspect#version)
      endif
    endif
  endif
endfunction

function! s:prepare_search_path() " {{{1
  let code = ''
  if !(has('lua') && g:lua_inspect_internal && exists('s:changed_path'))
    let root = xolox#misc#path#absolute(g:lua_inspect_path)
    let directories = [root]
    call add(directories, xolox#misc#path#merge(root, 'metalualib'))
    call add(directories, xolox#misc#path#merge(root, 'luainspect'))
    let template = "package.path = package.path .. ';%s/?.lua'"
    let lines = []
    for directory in directories
      call add(lines, printf(template, escape(directory, '"\''')))
    endfor
    let code = join(lines, '; ')
    if has('lua') && g:lua_inspect_internal
      execute 'lua' code
      let s:changed_path = 1
    endif
  endif
  return code
endfunction

function! s:parse_text(input, search_path) " {{{1
  if !(exists('b:luainspect_input')
          \ && exists('b:luainspect_output')
          \ && b:luainspect_input == a:input)
    if !(has('lua') && g:lua_inspect_internal)
      let template = 'lua -e "%s; require ''luainspect4vim'' (io.read ''*a'')"'
      let command = printf(template, a:search_path)
      call xolox#misc#msg#debug("luainspect.vim %s: Executing LuaInspect as external process using command: %s", g:xolox#luainspect#version, command)
      try
        let b:luainspect_output = xolox#misc#os#exec({'command': command . ' 2>&1', 'stdin': a:input})['stdout']
      catch
        let msg = "luainspect.vim %s: Failed to execute LuaInspect as external process! Use ':verbose LuaInspect' to see the command line of the external process."
        throw printf(msg, g:xolox#luainspect#version)
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
  call clearmatches()
  for group in keys(s:groups)
    let group = 'luaInspect' . group
    if hlexists(group)
      execute 'syntax clear' group
    endif
  endfor
endfunction

function! s:highlight_variables() " {{{1
  call clearmatches()
  let num_warnings = b:luainspect_output[1] + 0
  call s:update_warnings(num_warnings > 0 ? b:luainspect_output[2 : num_warnings+1] : [])
  let other_output = b:luainspect_output[num_warnings+2 : -1]
  for line in other_output
    if s:check_output(line, '^\w\+\(\s\+\d\+\)\{4}$')
      let [group, l1, c1, l2, c2] = split(line)
      " Convert strings to numbers.
      let l1 += 0
      let l2 += 0
      " These adjustments were found by trial and error :-|
      let c1 += 0
      let c2 += 3 
      if group == 'luaInspectWrongArgCount'
        call matchadd(group, s:highlight_position(l1, c1, l2, c2, 0))
      elseif group == 'luaInspectSelectedVariable' 
        call matchadd(group, s:highlight_position(l1, c1, l2, c2, 1), 20)
      else
        let pattern = s:highlight_position(l1, c1, l2, c2, 1)
        execute 'syntax match' group '/' . pattern . '/'
      endif
    endif
  endfor
endfunction

function! s:update_warnings(warnings) " {{{1
  if !g:lua_inspect_warnings
    return
  endif
  let list = []
  for line in a:warnings
    if s:check_output(line, '^line\s\+\d\+\s\+column\s\+\d\+\s\+-\s\+\S')
      let fields = split(line)
      let linenum = fields[1] + 0
      let colnum = fields[3] + 0
      let message = join(fields[5:-1])
      call add(list, { 'bufnr': bufnr('%'), 'lnum': linenum, 'col': colnum, 'text': message })
    endif
  endfor
  call setloclist(winnr(), list)
  let b:luainspect_warnings = list
  if !empty(list)
    lopen
    if winheight(winnr()) > 4
      resize 4
    endif
    let warnings = len(list) > 1 ? 'warnings' : 'warning'
    let w:quickfix_title = printf('%i %s reported by LuaInspect', len(list), warnings)
    wincmd p
  else
    lclose
  endif
endfunction

function! s:rename_variable() " {{{1
  " Highlight occurrences of variable before rename.
  let highlights = []
  for line in b:luainspect_output[1:-1]
    if s:check_output(line, '^\d\+\(\s\+\d\+\)\{2}$')
      let [l1, c1, c2] = split(line)
      " Convert string to number.
      let l1 += 0
      " These adjustments were found by trial and error :-|
      let c1 += 0
      let c2 += 3
      let pattern = s:highlight_position(l1, c1, l1, c2, 1)
      call add(highlights, matchadd('IncSearch', pattern))
    endif
  endfor
  redraw
  " Prompt for new name.
  let oldname = expand('<cword>')
  let prompt = "luainspect.vim %s: Please enter the new name for %s: "
  let newname = input(printf(prompt, g:xolox#luainspect#version, oldname), oldname)
  " Clear highlighting of occurrences.
  call map(highlights, 'matchdelete(v:val)')
  " Perform rename?
  if newname != '' && newname !=# oldname
    let num_renamed = 0
    for fields in reverse(b:luainspect_output[1:-1])
      let [linenum, firstcol, lastcol] = split(fields)
      " Convert string to number.
      let linenum += 0
      " These adjustments were found by trial and error :-|
      let firstcol -= 1
      let lastcol += 1
      let line = getline(linenum)
      let prefix = firstcol > 0 ? line[0 : firstcol] : ''
      let suffix = lastcol < len(line) ? line[lastcol : -1] : ''
      call setline(linenum, prefix . newname . suffix)
      let num_renamed += 1
    endfor
    let msg = "luainspect.vim %s: Renamed %i occurrences of %s to %s"
    call xolox#misc#msg#info(msg, g:xolox#luainspect#version, num_renamed, oldname, newname)
  endif
endfunction

function! s:check_output(line, pattern) " {{{1
  if match(a:line, a:pattern) >= 0
    return 1
  else
    call xolox#misc#msg#warn("luainspect.vim %s: Invalid output from luainspect4vim.lua: '%s'", g:xolox#luainspect#version, strtrans(a:line))
    return 0
  endif
endfunction

function! s:highlight_position(l1, c1, l2, c2, ident_only) " {{{1
  let l1 = a:l1 >= 1 ? (a:l1 - 1) : a:l1
  let p = '\%>' . l1 . 'l\%>' . a:c1 . 'c'
  let p .= a:ident_only ? '\<\w\+\>' : '\_.\+'
  return p . '\%<' . (a:l2 + 1) . 'l\%<' . a:c2 . 'c'
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
