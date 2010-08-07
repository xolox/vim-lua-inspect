" Vim plug-in
" Author: Peter Odding <peter@peterodding.com>
" Last Change: August 7, 2010
" URL: http://peterodding.com/code/vim/lua-inspect/
" Version: 0.1.7
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
  " Set this to false (0) to run LuaInspect inside the Lua interface for Vim.
  " This makes it faster but less accurate because the Lua interface for Vim
  " doesn't include io.* and half of os.* which means LuaInspect marks them as
  " undefined globals...
  let g:lua_inspect_internal = 0
endif

" (Automatic) command definitions. {{{1

command! LuaInspect call s:RunLuaInspect()

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
  if &ft == 'lua' && !&diff
    LuaInspect
  end
endfunction

function! s:RunLuaInspect() " {{{2
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
  if hlexists('luaInspectGlobalDefined') | syntax clear luaInspectGlobalDefined | endif
  if hlexists('luaInspectGlobalUndefined') | syntax clear luaInspectGlobalUndefined | endif
  if hlexists('luaInspectLocalUnused') | syntax clear luaInspectLocalUnused | endif
  if hlexists('luaInspectLocalMutated') | syntax clear luaInspectLocalMutated | endif
  if hlexists('luaInspectUpValue') | syntax clear luaInspectUpValue | endif
  if hlexists('luaInspectParam') | syntax clear luaInspectParam | endif
  if hlexists('luaInspectLocal') | syntax clear luaInspectLocal | endif
  if hlexists('luaInspectFieldDefined') | syntax clear luaInspectFieldDefined | endif
  if hlexists('luaInspectFieldUndefined') | syntax clear luaInspectFieldUndefined | endif
  if hlexists('luaInspectSelectedVariable') | syntax clear luaInspectSelectedVariable | endif
endfunction

function! s:LoadDefaultStyles() " {{{2
  " Always define the default highlighting styles
  " (copied from /luainspect/scite.lua for consistency).
  " TODO Consider the &background?
  highlight luaInspectDefGlobalDefined guifg=#600000
  highlight luaInspectDefLocalUnused guifg=#ffffff guibg=#0000ff
  highlight luaInspectDefLocalMutated gui=italic guifg=#000080
  highlight luaInspectDefUpValue guifg=#0000ff
  highlight luaInspectDefParam guifg=#000040
  highlight luaInspectDefLocal guifg=#000080
  highlight luaInspectDefFieldDefined guifg=#600000
  highlight luaInspectDefFieldUndefined guifg=#c00000
  " Don't link the actual highlighting styles to the defaults if the user
  " has already defined or linked the highlighting group. This enables color
  " schemes and vimrc scripts to override the styles (see :help :hi-default).
  highlight def link luaInspectGlobalDefined luaInspectDefGlobalDefined
  highlight def link luaInspectGlobalUndefined ErrorMsg
  highlight def link luaInspectLocalUnused luaInspectDefLocalUnused
  highlight def link luaInspectLocalMutated luaInspectDefLocalMutated
  highlight def link luaInspectUpValue luaInspectDefUpValue
  highlight def link luaInspectParam luaInspectDefParam
  highlight def link luaInspectLocal luaInspectDefLocal
  highlight def link luaInspectFieldDefined luaInspectDefFieldDefined
  highlight def link luaInspectFieldUndefined luaInspectDefFieldUndefined
  highlight def link luaInspectSelectedVariable Folded
endfunction

" }}}1

" Make sure the plug-in is only loaded once.
let g:loaded_luainspect = 1

" vim: ts=2 sw=2 et
