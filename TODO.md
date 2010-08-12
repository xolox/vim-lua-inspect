# The to-do list

 * OMNI completion for in scope variables (including display of library function signatures).
 * Document g:lua_inspect_path option.
 * Check whether "core/SciTE: jump to definition now supports functions in different files." is interesting.
 * Use the new 'init.get_variable_details' function to replace most of actions.tooltip()? Can't do this until the references to `buffer` and `editor` are removed:
    if ast.localmasking then
      info = info .. "masking "
      local fpos = LA.ast_pos_range(ast.localmasking, buffer.tokenlist)
      if fpos then
        local linenum0 = editor:LineFromPosition(fpos)
        info = info .. "definition at line " .. (linenum0+1) .. " "
      end
    end
 * Bug: Argument count warning tool tips are only shown for parts of the highlighted text.
 * Bug: The plug-in warns `Invalid output from luainspect4vim.lua: 'This is an unknown table field.'`. Mixup between tool tip / highlight response parsing?!
