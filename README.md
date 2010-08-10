# Semantic highlighting for Lua in Vim

The Vim plug-in `luainspect.vim` uses the [LuaInspect](http://lua-users.org/wiki/LuaInspect) tool to (automatically) perform semantic highlighting of variables in Lua source code. It was inspired by [lua2-mode](http://www.enyo.de/fw/software/lua-emacs/lua2-mode.html) (for [Emacs](http://www.gnu.org/software/emacs/)) and the [SciTE](http://www.scintilla.org/SciTE.html) plug-in included with LuaInspect.

![Screenshot of semantic highlighting](http://peterodding.com/code/vim/luainspect/screenshot.png)

## Installation

Unzip the most recent [ZIP archive](http://peterodding.com/code/vim/downloads/lua-inspect) file inside your Vim profile directory (usually this is `~/.vim` on UNIX and `%USERPROFILE%\vimfiles` on Windows), restart Vim and execute the command `:helptags ~/.vim/doc` (use `:helptags ~\vimfiles\doc` instead on Windows). Now try it out: Edit a Lua file and within a few seconds semantic highlighting should be enabled automatically!

## Usage

When you open any Lua file the semantic highlighting should be enabled automatically within a few seconds, so you don't have to configure anything if you're happy with the defaults.

### The `:LuaInspect` command

You don't need to use this command unless you've disabled automatic highlighting using `g:lua_inspect_events`. When you execute this command the plug-in runs the LuaInspect tool and then highlights all variables in the current buffer using one of the following highlighting groups:

 * <span style="color: #600000">luaInspectGlobalDefined</span>
 * <span style="color: #FFF; background: #F00">luaInspectGlobalUndefined</span>
 * <span style="color: #FFF; background: #00F">luaInspectLocalUnused</span>
 * <span style="color: #000080; font-style: italic">luaInspectLocalMutated</span>
 * <span style="color: #00F">luaInspectUpValue</span>
 * <span style="color: #000040">luaInspectParam</span>
 * <span style="color: #000080">luaInspectLocal</span>
 * <span style="color: #600000">luaInspectFieldDefined</span>
 * <span style="color: #C00000">luaInspectFieldUndefined</span>
 * <span style="background: #D3D3D3">luaInspectSelectedVariable</span>

If you don't like one or more of the default styles the Vim documentation [describes how to change them](http://vimdoc.sourceforge.net/htmldoc/syntax.html#:hi-default).

If you want to disable the semantic highlighting in a specific Vim buffer execute `:LuaInspect!` in that buffer. When you want to reenable the highlighting execute `:LuaInspect` again, but now without the [bang](http://vimdoc.sourceforge.net/htmldoc/map.html#:command-bang).

### The `g:loaded_luainspect` option

This variable isn't really an option but if you want to avoid loading the `luainspect.vim` plug-in you can set this variable to any value in your [vimrc script](http://vimdoc.sourceforge.net/htmldoc/starting.html#vimrc):

    :let g:loaded_luainspect = 1

### The `g:lua_inspect_events` option

By default semantic highlighting is automatically enabled after a short timeout and when you save a buffer. If you want to disable automatic highlighting altogether add the following to your [vimrc script](http://vimdoc.sourceforge.net/htmldoc/starting.html#vimrc):

    :let g:lua_inspect_events = ''

You can also add events, for example if you also want to run `:LuaInspect` the moment you edit a Lua file then try this:

    :let g:lua_inspect_events = 'CursorHold,CursorHoldI,BufReadPost,BufWritePost'

Note that this only works when the plug-in is loaded (or reloaded) *after* setting the `g:lua_inspect_events` option.

### The `g:lua_inspect_internal` option

The plug-in uses the Lua interface for Vim when available so that it doesn't have to run LuaInspect as an external program (which can slow things down). If you insist on running LuaInspect as an external program you can set this variable to false (0) in your [vimrc script](http://vimdoc.sourceforge.net/htmldoc/starting.html#vimrc):

    :let g:lua_inspect_internal = 0

## Not yet implemented

 * When LuaInspect fails because of a syntax error the position of the error should be marked like e.g. spelling errors

 * Right now the highlighting styles used by `luainspect.vim` are the same as those used by the SciTE plug-in and they don't work well on dark backgrounds. As soon as I get around to picking some alternate colors I'll include those in the plug-in.

 * Bindings for other features of LuaInspect like renaming variables on command and showing tooltips for identifiers. This might be a lot of work but could prove to be really useful in making Lua easy to use in Vim.

## Contact

If you have questions, bug reports, suggestions, etc. the author can be contacted at <peter@peterodding.com>. The latest version is available at <http://peterodding.com/code/vim/lua-inspect/> and <http://github.com/xolox/vim-lua-inspect>. If you like this plug-in please vote for it on [www.vim.org](http://www.vim.org/scripts/script.php?script_id=3169).

## License

This software is licensed under the [MIT license](http://en.wikipedia.org/wiki/MIT_License).  
© 2010 Peter Odding &lt;<peter@peterodding.com>&gt;.
