# The to-do list

 * OMNI completion for in scope variables (including display of library function signatures).
 * Document g:lua_inspect_path option.
 * Check whether "core/SciTE: jump to definition now supports functions in different files." is interesting.
 * Use the new 'init.get_variable_details' function to replace most of actions.tooltip()?
 * BUG: With a Lua script in one split window and a different file type in another split window, where the active window contains the non-Lua file, if you hover over the Lua window syntax error highlighting is applied to the non-Lua buffer! Hint: getbufline() / assert(v:beval_bufnr==bufnr('%'))
