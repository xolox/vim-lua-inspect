# The to-do list

 * OMNI completion for in scope variables (including display of library function signatures). This will probably get complicated because most times when you want completion you'll already have typed half a statement, and LuaInspect will find syntax errors when trying to parse the source text. `scite.lua` can just use the last known valid AST but `luainspect4vim.lua` cannot keep this around when executed as an external process…
 * Document g:lua_inspect_path option.
 * Check whether "core/SciTE: jump to definition now supports functions in different files." is interesting.
 * Bug: The plug-in sometimes warns `Invalid output from luainspect4vim.lua: 'This is an unknown table field.'`. Mixup between tool tip / highlight response parsing?!

# Known issues

 * Dynamic highlighting using Vim's `matchadd()` function performs **very** poorly in large buffers -- so poorly that Vim becomes pretty much unusable until the user disables dynamic highlighting using `:LuaInspect!` (e.g. try editing `luainspect/scite.lua` using the Vim plug-in). I've since switched to highlighting only function names (instead of multiline call expressions) but that hasn't improved performance as much as I'd hoped...
