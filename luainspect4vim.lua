--[[

 This module is part of the luainspect.vim plug-in for the Vim text editor.

 Author: Peter Odding <peter@peterodding.com>
 Last Change: July 28, 2010
 URL: http://peterodding.com/code/vim/lua-inspect/

--]]

local function offset2lineinfo(text, offset)
  -- TODO Cache intermediate results because they won't change within a single
  --      call to the function returned from this module below.
  local curlnum = 1
  local lastlineoffset = 0
  for i in text:gmatch '()\n' do
    if i >= offset then break end
    curlnum = curlnum + 1
    lastlineoffset = i
  end
  return curlnum, offset - lastlineoffset
end

local dumpvar
if type(vim) == 'table' and vim.eval then
  -- The Lua interface for Vim redefines print() so it prints inside Vim.
  dumpvar = function(text, kind, firstbyte, lastbyte)
    local line1, offset1 = offset2lineinfo(text, firstbyte)
    print(kind, line1, offset1, offset1 + (lastbyte - firstbyte))
  end
else
  -- My $LUA_INIT script redefines print() to enable pretty printing in the
  -- interactive prompt, which means strings are printed with surrounding
  -- quotes. This would break the communication between Vim and this script.
  dumpvar = function(text, kind, firstbyte, lastbyte)
    local line1, offset1 = offset2lineinfo(text, firstbyte)
    io.write(kind, '\t', line1, '\t', offset1, '\t', offset1 + (lastbyte - firstbyte), '\n')
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
    if kind then dumpvar(text, kind, note[1], note[2]) end
  end
end

-- vim: ts=2 sw=2 et
