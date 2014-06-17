" Vim plug-in
" Author: Peter Odding <peter@peterodding.com>
" Last Change: June 17, 2014
" URL: http://peterodding.com/code/vim/lua-inspect/

" Support for automatic update using the GLVS plug-in.
" GetLatestVimScripts: 3169 1 :AutoInstall: luainspect.zip

" Don't source the plug-in when it's already been loaded or &compatible is set.
if &cp || exists('g:loaded_luainspect')
  finish
endif

" Make sure vim-misc is installed.
try
  " The point of this code is to do something completely innocent while making
  " sure the vim-misc plug-in is installed. We specifically don't use Vim's
  " exists() function because it doesn't load auto-load scripts that haven't
  " already been loaded yet (last tested on Vim 7.3).
  call type(g:xolox#misc#version)
catch
  echomsg "Warning: The vim-lua-inspect plug-in requires the vim-misc plug-in which seems not to be installed! For more information please review the installation instructions in the readme (also available on the homepage and on GitHub). The vim-lua-inspect plug-in will now be disabled."
  let g:loaded_luainspect = 1
  finish
endtry

if !exists('g:lua_inspect_mappings')
  " Change this to disable default key mappings.
  let g:lua_inspect_mappings = 1
endif

if !exists('g:lua_inspect_warnings')
  " Change this to disable automatic warning messages.
  let g:lua_inspect_warnings = 1
endif

if !exists('g:lua_inspect_events')
  " Change this to enable semantic highlighting on your preferred events.
  let g:lua_inspect_events = 'CursorHold,CursorHoldI,BufWritePost'
endif

if !exists('g:lua_inspect_path')
  " Change this if you want to move the Lua modules somewhere else.
  let g:lua_inspect_path = expand('<sfile>:p:h') . '/../misc/luainspect'
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

" This command enables/updates highlighting when automatic highlighting is disabled.
command! -bar -bang LuaInspect call xolox#luainspect#highlight_cmd(<q-bang> == '!')

" This command can be used as a toggle to enable/disable the highlighting.
command! -bar LuaInspectToggle call xolox#luainspect#toggle_cmd()

" This command can be used to rename variables.
command! -bar LuaInspectRename call xolox#luainspect#make_request('rename')

" This command can be used to jump to a variable's definition.
command! -bar LuaInspectGoTo call xolox#luainspect#make_request('go_to')

" Automatically enable the plug-in in Lua buffers.
augroup PluginLuaInspect
  autocmd! FileType lua call xolox#luainspect#auto_enable()
augroup END

" The &balloonexpr option requires a global function.
function! LuaInspectToolTip()
  let result = xolox#luainspect#make_request('tooltip')
  if exists('b:luainspect_syntax_error')
    return b:luainspect_syntax_error
  else
    return type(result) == type('') ? result : ''
  endif
endfunction

" Make sure the plug-in is only loaded once.
let g:loaded_luainspect = 1

" vim: ts=2 sw=2 et
