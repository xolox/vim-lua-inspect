" Vim plug-in
" Author: Peter Odding <peter@peterodding.com>
" Last Change: August 12, 2010
" URL: http://peterodding.com/code/vim/lua-inspect/
" Version: 0.3.5
" License: MIT

" Support for automatic update using the GLVS plug-in.
" GetLatestVimScripts: 3169 1 :AutoInstall: luainspect.zip

" Don't source the plug-in when its already been loaded or &compatible is set.
if &cp || exists('g:loaded_luainspect')
  finish
endif

" Configuration defaults. {{{1

if !exists('g:lua_inspect_events')
  " Change this to enable semantic highlighting on your preferred events.
  let g:lua_inspect_events = 'CursorHold,CursorHoldI,BufWritePost'
endif

if !exists('g:lua_inspect_path')
  " Change this if you want to move the Lua modules somewhere else.
  if has('win32') || has('win64')
    let g:lua_inspect_path = '~\vimfiles\misc\luainspect'
  else
    let g:lua_inspect_path = '~/.vim/misc/luainspect'
  endif
endif

if !exists('g:lua_inspect_internal')
  " Set this to false (0) to run LuaInspect as an external process instead of
  " using the Lua interface for Vim. This makes it slower but might make it
  " more accurate because the Lua interface for Vim didn't include io.* and
  " os.* before the patch posted on 2010-07-28 which means LuaInspect would
  " mark them as undefined globals. The patch I'm referring to is:
  " http://groups.google.com/group/vim_dev/browse_frm/thread/9b77afa2fe4336c8
  let g:lua_inspect_internal = has('lua')
endif

" The highlight groups and default styles/links defined by this plug-in.
let s:groups = {}
let s:groups['GlobalDefined'] = 'guifg=#600000'
let s:groups['GlobalUndefined'] = 'ErrorMsg'
let s:groups['LocalUnused'] = 'guifg=#ffffff guibg=#0000ff'
let s:groups['LocalMutated'] = 'gui=italic guifg=#000080'
let s:groups['UpValue'] = 'guifg=#0000ff'
let s:groups['Param'] = 'guifg=#000040'
let s:groups['Local'] = 'guifg=#000080'
let s:groups['FieldDefined'] = 'guifg=#600000'
let s:groups['FieldUndefined'] = 'guifg=#c00000'
let s:groups['SelectedVariable'] = 'CursorLine'
let s:groups['SyntaxError'] = 'SpellBad'

" (Automatic) command definitions. {{{1

command! -bar -bang LuaInspect call s:run_lua_inspect('highlight', 1, <q-bang> != '!')

augroup PluginLuaInspect
  " Clear existing automatic commands.
  autocmd!
  " Disable easytags.vim because it doesn't play nice with luainspect.vim!
  autocmd BufNewFile,BufReadPost,BufWritePost * call s:init_lua_buffer()
  " Define the configured automatic commands.
  for s:event in split(g:lua_inspect_events, ',')
    execute 'autocmd' s:event '* if s:check_plugin_enabled() | LuaInspect | endif'
  endfor
augroup END

" Script local functions. {{{1

function! s:check_plugin_enabled()
  return &ft == 'lua' && !&diff && !exists('b:luainspect_disabled')
endfunction

function! s:init_lua_buffer()
  if s:check_plugin_enabled()
    let b:easytags_nohl = 1
    inoremap <buffer> <silent> <F2> <C-o>:call <Sid>run_lua_inspect('rename', 0, 1)<CR>
    nnoremap <buffer> <silent> <F2> :call <Sid>run_lua_inspect('rename', 0, 1)<CR>
    nnoremap <buffer> <silent> gd :call <Sid>run_lua_inspect('goto', 0, 1)<CR>
    setlocal ballooneval balloonexpr=LuaInspectToolTip()
  endif
endfunction

function! LuaInspectToolTip() " {{{2
  let text = s:run_lua_inspect('tooltip', 0, 1)
  if exists('b:luainspect_syntax_error')
    return b:luainspect_syntax_error
  else
    return type(text) == type('') ? text : ''
  endif
endfunction

function! s:run_lua_inspect(action, toggle, enabled) " {{{2
  if !a:toggle || s:set_plugin_enabled(a:enabled)
    let lines = getline(1, "$")
    if a:action == 'tooltip'
      call insert(lines, v:beval_col)
      call insert(lines, v:beval_lnum)
    else
      call insert(lines, col('.'))
      call insert(lines, line('.'))
    endif
    call insert(lines, a:action)
    call s:parse_text(join(lines, "\n"), s:prepare_search_path())
    if !empty(b:luainspect_output)
      let response = b:luainspect_output[0]
      if response == 'syntax_error' && len(b:luainspect_output) >= 4
        let linenum = b:luainspect_output[1] + 0
        let colnum = b:luainspect_output[2] + 0
        let linenum2 = b:luainspect_output[3] + 0
        let b:luainspect_syntax_error = b:luainspect_output[4]
        let error_cmd = 'syntax match luaInspectSyntaxError /\%%>%il\%%<%il.*/ containedin=ALLBUT,lua*Comment*'
        execute printf(error_cmd, linenum - 1, (linenum2 ? linenum2 : line('$')) + 1)
        call xolox#warning("Syntax error around line %i: %s", linenum, b:luainspect_syntax_error)
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
  endif
endfunction

function! s:set_plugin_enabled(enabled) " {{{2
  if a:enabled
    unlet! b:luainspect_disabled
    return 1
  else
    call s:clear_previous_matches()
    unlet! b:luainspect_input b:luainspect_output
    let b:luainspect_disabled = 1
    return 0
  endif
endfunction

function! s:prepare_search_path() " {{{2
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

function! s:parse_text(input, search_path) " {{{2
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
      silent lua << EOF
      if io == nil then
        -- The Lua interface for Vim previously didn't include io.*!
        io = { type = function() end }
      end
      require 'luainspect4vim' (vim.eval 'a:input')
EOF
      redir END
      let b:luainspect_output = split(output, "\n")
    endif
    " Remember the text that was just parsed.
    let b:luainspect_input = a:input
  endif
endfunction

function! s:define_default_styles() " {{{2
  " Always define the default highlighting styles
  " (copied from /luainspect/scite.lua for consistency).
  " TODO Consider the &background?
  for [group, style] in items(s:groups)
    let defgroup = style
    let group = 'luaInspect' . group
    if match(style, '=') >= 0
      let defgroup = 'luaInspectDefault' . group
      execute 'highlight' defgroup style
    endif
    " Don't link the actual highlighting styles to the defaults if the user
    " has already defined or linked the highlighting group. This enables color
    " schemes and vimrc scripts to override the styles (see :help :hi-default).
    execute 'highlight def link' group defgroup
  endfor
endfunction

function! s:clear_previous_matches() " {{{2
  " Clear existing highlighting.
  for group in keys(s:groups)
    let group = 'luaInspect' . group
    if hlexists(group)
      execute 'syntax clear' group
    endif
  endfor
endfunction

function! s:highlight_variables() " {{{2
  call clearmatches()
  for line in b:luainspect_output[1:-1]
    if s:check_output(line, '^\w\+\(\s\+\d\+\)\{3}$')
      let [hlgroup, linenum, firstcol, lastcol] = split(line)
      let pattern = s:highlight_position(linenum + 0, firstcol - 1, lastcol + 2)
      if hlgroup == 'luaInspectSelectedVariable'
        call matchadd(hlgroup, pattern)
      else
        execute 'syntax match' hlgroup '/' . pattern . '/'
      endif
    endif
  endfor
endfunction

function! s:rename_variable() " {{{2
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

function! s:check_output(line, pattern) " {{{2
  if match(a:line, a:pattern) >= 0
    return 1
  else
    call xolox#warning("Invalid output from luainspect4vim.lua: '%s'", strtrans(a:line))
    return 0
  endif
endfunction

function! s:highlight_position(linenum, firstcol, lastcol) " {{{2
  return printf('\%%%il\%%>%ic\<\w\+\>\%%<%ic', a:linenum, a:firstcol, a:lastcol)
endfunction

" }}}1

" Make sure the plug-in is only loaded once.
let g:loaded_luainspect = 1

" vim: ts=2 sw=2 et
