# The to-do list

 * OMNI completion for in scope variables (including display of library function signatures). This will probably get complicated because most times when you want completion you'll already have typed half a statement, and LuaInspect will find syntax errors when trying to parse the source text. `scite.lua` can just use the last known valid AST but `luainspect4vim.lua` cannot keep this around when executed as an external process…
 * Document g:lua_inspect_path option.
 * Check whether "core/SciTE: jump to definition now supports functions in different files." is interesting.
 * Bug: Argument count warning tool tips are only shown for parts of the highlighted text.
 * Bug: The plug-in sometimes warns `Invalid output from luainspect4vim.lua: 'This is an unknown table field.'`. Mixup between tool tip / highlight response parsing?!
 * Bug: When you add some empty lines to the start of a Lua buffer the highlighting breaks! I haven't tracked this down completely yet but it looks to be a bug somewhere deep down inside of Metalua or LuaInspect `:-|`
 * The `ast.valueknown` field was removed from LuaInspect in [this commit](http://github.com/davidm/lua-inspect/commit/d60b0ad2d7e6d1b2f755411c23ca19eb29775bcf) so `luainspect4vim.lua` needs to be updated in the same manner.
 * Dynamic highlighting using `matchadd()` performs **very** poorly when multiple consecutive lines are highlighted as `SpellLocal` -- so poorly that Vim becomes pretty much unusable until the user disables dynamic highlighting using `:LuaInspect!` (e.g. try editing `luainspect/init.lua` using the Vim plug-in). For this reason I guess only the function names should be highlighted.
