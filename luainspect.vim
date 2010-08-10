" Vim plug-in
" Author: Peter Odding <peter@peterodding.com>
" Last Change: August 10, 2010
" URL: http://peterodding.com/code/vim/lua-inspect/
" Version: 0.2.1
" License: MIT

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
let s:groups['SelectedVariable'] = 'Folded'

" (Automatic) command definitions. {{{1

command! -bar -bang LuaInspect call s:run_lua_inspect(<q-bang> != '!')

augroup PluginLuaInspect
  " Clear existing automatic commands.
  autocmd!
  " Disable easytags.vim because it doesn't play nice with luainspect.vim!
  autocmd BufReadPost * if s:check_plugin_enabled() | let b:easytags_nohl = 1 | endif
  " Define the configured automatic commands.
  for s:event in split(g:lua_inspect_events, ',')
    execute 'autocmd' s:event '* if s:check_plugin_enabled() | LuaInspect | endif'
  endfor
augroup END

" Script local functions. {{{1

function! s:check_plugin_enabled()
  return &ft == 'lua' && !&diff && !exists('b:luainspect_disabled')
endfunction

function! s:run_lua_inspect(enabled) " {{{2
  if s:set_plugin_enabled(a:enabled)
    let lines = getline(1, "$")
    call insert(lines, col('.'))
    call insert(lines, line('.'))
    call s:parse_text(join(lines, "\n"), s:prepare_search_path())
    call s:define_default_styles()
    call s:clear_previous_matches()
    call s:highlight_variables()
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
    let code = printf(template, escape(expand(g:lua_inspect_path), '"\'))
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
      let b:luainspect_output = system(printf(template, a:search_path), a:input)
    else
      redir => b:luainspect_output
      silent lua << EOF
      if io == nil then
        -- The Lua interface for Vim previously didn't include io.*!
        io = { type = function() end }
      end
      require 'luainspect4vim' (vim.eval 'a:input')
EOF
      redir END
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
  let did_warning = 0
  for line in split(b:luainspect_output, "\n")
    if match(line, '^\w\+\(\s\+\d\+\)\{3}$') == -1
      if !did_warning
        try
          echohl WarningMsg
          echomsg "Invalid output from luainspect4vim.lua:"
        finally
          echohl None
          let did_warning = 1
        endtry
      endif
      echomsg strtrans(line)
    else
      let [type, lnum, start, end] = split(line)
      let syntax_cmd = 'syntax match %s /\%%%il\%%>%ic\<\w\+\>\%%<%ic/'
      execute printf(syntax_cmd, type, lnum, start - 1, end + 2)
    endif
  endfor
endfunction

" }}}1

" Make sure the plug-in is only loaded once.
let g:loaded_luainspect = 1

" vim: ts=2 sw=2 et
