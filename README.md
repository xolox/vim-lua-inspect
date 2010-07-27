# Semantic highlighting for Lua in Vim

The Vim plug-in `luainspect.vim` uses the [LuaInspect](http://lua-users.org/wiki/LuaInspect) tool to (automatically) perform semantic highlighting of variables in Lua source code. It was inspired by [lua2-mode](http://www.enyo.de/fw/software/lua-emacs/lua2-mode.html) (for [Emacs](http://www.gnu.org/software/emacs/)) and the [SciTE](http://www.scintilla.org/SciTE.html) plug-in included with LuaInspect.

## Installation

1. Download the latest [LuaInspect sources](http://github.com/davidm/lua-inspect/zipball/master) and unpack the contents of the `luainspectlib/` and `metalualib/` directories where Lua's `require()` function can find them.

2. Save the Lua module [luainspect4vim.lua](http://github.com/xolox/vim-lua-inspect/raw/master/luainspect4vim.lua) somewhere where Lua's `require()` function can find it.

3. Save the Vim plug-in [luainspect.vim](http://github.com/xolox/vim-lua-inspect/raw/master/luainspect.vim) in the directory `$HOME/.vim/plugin` (on UNIX) or `%USERPROFILE%\vimfiles\plugin` (on Windows).

4. Restart Vim and edit any Lua file. Within a few seconds semantic highlighting should be enabled automatically.

## Limitations

Right now the highlighting styles used by `luainspect.vim` are the same as those used by the SciTE plug-in and they don't work well on dark backgrounds. As soon as I get around to picking some alternate colors I'll include those in the plug-in.
