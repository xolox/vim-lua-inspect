" Vim plug-in
" Author: Peter Odding <peter@peterodding.com>
" Last Change: July 28, 2010
" URL: http://peterodding.com/code/vim/lua-inspect/
" Version: 0.1.3

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

function! s:AutoEnable()
  if &ft == 'lua' && !&diff
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
  call s:LoadDefaultStyles()
  call s:ClearPreviousMatches()
  " Highlight variables in buffer based on positions.
  for fields in split(listing, "\n")
    let [type, lnum, start, end] = split(fields)
    let command = 'syntax match %s /\%%%il\%%>%ic\<\w\+\>\%%<%ic/'
    execute printf(command, type, lnum, start - 1, end + 2)
  endfor
endfunction

function! s:ClearPreviousMatches()
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
endfunction

function! s:LoadDefaultStyles()
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
  highlight def link luaInspectGlobalUndefined Error
  highlight def link luaInspectLocalUnused luaInspectDefLocalUnused
  highlight def link luaInspectLocalMutated luaInspectDefLocalMutated
  highlight def link luaInspectUpValue luaInspectDefUpValue
  highlight def link luaInspectParam luaInspectDefParam
  highlight def link luaInspectLocal luaInspectDefLocal
  highlight def link luaInspectFieldDefined luaInspectDefFieldDefined
  highlight def link luaInspectFieldUndefined luaInspectDefFieldUndefined
endfunction

" vim: ts=2 sw=2 et
