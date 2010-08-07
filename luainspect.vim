" Vim plug-in
" Author: Peter Odding <peter@peterodding.com>
" Last Change: August 7, 2010
" URL: http://peterodding.com/code/vim/lua-inspect/
" Version: 0.2
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

command! -bar -bang LuaInspect call s:RunLuaInspect(<q-bang> == '!')

augroup PluginLuaInspect
  " Clear existing automatic commands.
  autocmd! 
  " Define the configured automatic commands.
  for s:event in split(g:lua_inspect_events, ',')
    execute 'autocmd' s:event '* call s:AutoEnable()'
  endfor
augroup END

" Script local functions. {{{1

function! s:AutoEnable() " {{{2
  if &ft == 'lua' && !&diff && !exists('b:luainspect_disabled')
    LuaInspect
  end
endfunction

function! s:RunLuaInspect(disable) " {{{2
  if a:disable
    call s:ClearPreviousMatches()
    unlet! b:luainspect_input b:luainspect_output
    let b:luainspect_disabled = 1
    return
  else
    unlet! b:luainspect_disabled
  endif
  let lines = getline(1, "$")
  call insert(lines, col('.'))
  call insert(lines, line('.'))
  let l:input = join(lines, "\n")
  " Don't parse the text when it hasn't been changed.
  if !(exists('b:luainspect_input') && b:luainspect_input == l:input)
    if !(has('lua') && g:lua_inspect_internal)
      " Run LuaInspect as an external program.
      let b:luainspect_output = system("lua -e 'require\"luainspect4vim\" (io.read \"*a\")'", l:input)
    else
      " Run LuaInspect using the Lua interface for Vim.
      redir => b:luainspect_output
      silent lua << EOF
      if io == nil then
        -- The Lua interface for Vim previously didn't include io.*!
        io = { type = function() end }
      end
      require 'luainspect4vim' (vim.eval 'l:input')
EOF
      redir END
    endif
    " Remember the text that was just parsed.
    let b:luainspect_input = l:input
  endif
  " Clear previously created highlighting.
  call s:LoadDefaultStyles()
  call s:ClearPreviousMatches()
  " Highlight variables in buffer based on positions.
  let did_warning = 0
  for line in split(b:luainspect_output, "\n")
    let fields = split(line, "\t")
    if len(fields) != 4
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
      let [type, lnum, start, end] = fields
      let command = 'syntax match %s /\%%%il\%%>%ic\<\w\+\>\%%<%ic/'
      execute printf(command, type, lnum, start - 1, end + 2)
    endif
  endfor
endfunction

function! s:ClearPreviousMatches() " {{{2
  " Clear existing highlighting.
  for group in keys(s:groups)
    let group = 'luaInspect' . group
    if hlexists(group)
      execute 'syntax clear' group
    endif
  endfor
endfunction

function! s:LoadDefaultStyles() " {{{2
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

" }}}1

" Make sure the plug-in is only loaded once.
let g:loaded_luainspect = 1

" vim: ts=2 sw=2 et
