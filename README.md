# Semantic highlighting for Lua in Vim

The Vim plug-in `luainspect.vim` uses the [LuaInspect](http://lua-users.org/wiki/LuaInspect) tool to (automatically) perform semantic highlighting of variables in Lua source code. It was inspired by [lua2-mode](http://www.enyo.de/fw/software/lua-emacs/lua2-mode.html) (for [Emacs](http://www.gnu.org/software/emacs/)) and the [SciTE](http://www.scintilla.org/SciTE.html) plug-in included with LuaInspect.

## Installation

1. Unzip the most recent [ZIP archive](http://peterodding.com/code/vim/downloads/lua-inspect) file inside your Vim profile directory (usually this is `~/.vim` on UNIX and `%USERPROFILE%\vimfiles` on Windows) and move or symlink the file `luainspect4vim.lua` somewhere where Lua's `require()` function can find it.

2. Download the latest [LuaInspect sources](http://github.com/davidm/lua-inspect/zipball/master) and unpack the contents of the `luainspectlib/` and `metalualib/` directories where Lua's `require()` function can find them.

3. Restart Vim and edit any Lua file. Within a few seconds semantic highlighting should be enabled automatically.

## Usage

When you open any Lua file the semantic highlighting should be enabled automatically within a few seconds, so you don't have to configure anything if you're happy with the defaults.

### The `:LuaInspect` command

You shouldn't need to execute this command manually unless you've disabled automatic highlighting using the `g:lua_inspect_automatic` option. When you execute the `:LuaInspect` command the plug-in runs the LuaInspect tool and then highlights all variables in the current buffer using one of the following highlighting groups:

 * <span style="color: #600000">luaInspectGlobalDefined</span>
 * <span style="color: #FFF; background: #F00">luaInspectGlobalUndefined</span>
 * <span style="color: #FFF; background: #00F">luaInspectLocalUnused</span>
 * <span style="color: #000080; font-style: italic">luaInspectLocalMutated</span>
 * <span style="color: #00F">luaInspectUpValue</span>
 * <span style="color: #000040">luaInspectParam</span>
 * <span style="color: #000080">luaInspectLocal</span>
 * <span style="color: #600000">luaInspectFieldDefined</span>
 * <span style="color: #C00000">luaInspectFieldUndefined</span>

If you don't like one or more of the default styles the Vim documentation [describes how to change them](http://vimdoc.sourceforge.net/htmldoc/syntax.html#:hi-default).

### The `g:lua_inspect_automatic` option

By default semantic highlighting is automatically enabled after a short timeout. If you don't want this you can add the following to your [vimrc script](http://vimdoc.sourceforge.net/htmldoc/starting.html#vimrc):

    :let g:lua_inspect_automatic = 0

### The `g:lua_inspect_internal` option

The plug-in can use the Lua interface for Vim so it doesn't have to run LuaInspect as an external program (which can slow things down). This feature isn't enabled by default though, because the Lua interface for Vim doesn't include most of `io.*` and `os.*` from Lua's standard library, and this causes LuaInspect to flag all references to those modules as undefined global variables! If you want to enable use of the Lua interface for Vim despite this, you can add the following to your [vimrc script](http://vimdoc.sourceforge.net/htmldoc/starting.html#vimrc):

    :let g:lua_inspect_internal = 1

## Not yet implemented

 * Right now the highlighting styles used by `luainspect.vim` are the same as those used by the SciTE plug-in and they don't work well on dark backgrounds. As soon as I get around to picking some alternate colors I'll include those in the plug-in.

 * Bindings for other features of LuaInspect like renaming variables on command and showing tooltips for identifiers. This might be a lot of work but could prove to be really useful in making Lua easy to use in Vim.

## Contact

If you have questions, bug reports, suggestions, etc. the author can be contacted at <peter@peterodding.com>. The latest version is available at <http://peterodding.com/code/vim/lua-inspect/> and <http://github.com/xolox/vim-lua-inspect>. If you like this plug-in please vote for it on [www.vim.org](http://www.vim.org/scripts/script.php?script_id=3169).

## License

This software is licensed under the [MIT license](http://en.wikipedia.org/wiki/MIT_License).  
© 2010 Peter Odding &lt;<peter@peterodding.com>&gt;.
