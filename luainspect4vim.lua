--[[

 This module is part of the luainspect.vim plug-in for the Vim text editor.

 Author: Peter Odding <peter@peterodding.com>
 Last Change: July 28, 2010
 URL: http://peterodding.com/code/vim/lua-inspect/

--]]

local dumpvar
if type(vim) == 'table' and vim.eval then
  -- The Lua interface for Vim redefines print() so it prints inside Vim.
  dumpvar = function(kind, lnum, firstcol, lastcol)
    print(kind, lnum, firstcol, lastcol)
  end
else
  -- My $LUA_INIT script redefines print() to enable pretty printing in the
  -- interactive prompt, which means strings are printed with surrounding
  -- quotes. This would break the communication between Vim and this script.
  dumpvar = function(kind, lnum, firstcol, lastcol)
    io.write(kind, '\t', lnum, '\t', firstcol, '\t', lastcol, '\n')
  end
end

return function(text)
  local LI = require 'luainspect.init'
  text = LI.remove_shebang(text)
  local f, err, linenum, colnum, linenum2 = LI.loadstring(text)
  if not f then return end
  local ast; ast, err, linenum, colnum, linenum2 = LI.ast_from_string(text, "noname.lua")
  if not ast then return end
  for i, note in ipairs(LI.inspect(ast)) do
    local kind
    if note.type == 'global' then
      if note.definedglobal then
        kind = 'luaInspectGlobalDefined'
      else
        kind = 'luaInspectGlobalUndefined'
      end
    elseif note.type == 'local' then
      if not note.ast.localdefinition.isused then
        kind = 'luaInspectLocalUnused'
      elseif note.ast.localdefinition.isset then
        kind = 'luaInspectLocalMutated'
      elseif note.ast.localdefinition.functionlevel  < note.ast.functionlevel then
        kind = 'luaInspectUpValue'
      elseif note.ast.localdefinition.isparam then
        kind = 'luaInspectParam'
      else
        kind = 'luaInspectLocal'
      end
    elseif note.type == 'field' then
      if note.definedglobal or note.ast.seevalue.value ~= nil then
        kind = 'luaInspectFieldDefined'
      else
        kind = 'luaInspectFieldUndefined'
      end
    end
    if kind then
      local l1, c1 = unpack(note.ast.lineinfo.first, 1, 2)
      local l2, c2 = unpack(note.ast.lineinfo.last, 1, 2)
      if l1 == l2 then dumpvar(kind, l1, c1, c2) end
    end
  end
end

-- vim: ts=2 sw=2 et
