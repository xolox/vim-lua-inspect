" Vim plug-in
" Author: Peter Odding <peter@peterodding.com>
" Last Change: July 27, 2010
" URL: http://peterodding.com/code/vim/lua-inspect/
" Version: 0.1.2

" Configuration defaults. {{{1

if !exists('g:lua_inspect_automatic')
  " Set this to false (0) to disable the automatic command.
  let g:lua_inspect_automatic = 1
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
  autocmd! CursorHold,CursorHoldI * call s:AutoEnable()
augroup END

" Script local functions. {{{1

function! s:AutoEnable()
  if &filetype == 'lua' && g:lua_inspect_automatic
    LuaInspect
  end
endfunction

function! s:RunLuaInspect()
  let l:text = join(getline(1, "$"), "\n")
  if has('lua') && g:lua_inspect_internal
    " Run LuaInspect using the Lua interface for Vim.
    redir => listing
    silent lua << EOF
    if io == nil then
      -- The Lua interface for Vim doesn't include io.*!
      io = { type = function() end }
    end
    require 'luainspect4vim' (vim.eval 'l:text')
EOF
    redir END
  else
    " Run LuaInspect as an external program.
    let listing = system("lua -e 'require\"luainspect4vim\" (io.read \"*a\")'", l:text)
  endif
  " Clear previously created highlighting.
  call s:InitHighlighting()
  " Highlight variables in buffer based on positions.
  for fields in split(listing, "\n")
    let [type, lnum, start, end] = split(fields)
    let command = 'syntax match %s /\%%%il\%%>%ic.\+\%%<%ic/'
    execute printf(command, type, lnum, start - 1, end + 2)
  endfor
endfunction

function! s:InitHighlighting()
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
  " Define default styles (copied from /luainspect/scite.lua for consistency).
  hi luaInspectGlobalDefined guifg=#600000
  hi def link luaInspectGlobalUndefined WarningMsg
  hi luaInspectLocalUnused guifg=#ffffff guibg=#0000ff
  hi luaInspectLocalMutated gui=italic guifg=#000080
  hi luaInspectUpValue guifg=#0000ff
  hi luaInspectParam guifg=#000040
  hi luaInspectLocal guifg=#000080
  hi luaInspectFieldDefined guifg=#600000
  hi luaInspectFieldUndefined guifg=#c00000
  " TODO Consider the &background?
endfunction

" vim: ts=2 sw=2 et
