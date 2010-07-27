--[[

 This module is part of the luainspect.vim plug-in for the Vim text editor.

 Author: Peter Odding <peter@peterodding.com>
 Last Change: July 27, 2010
 URL: http://peterodding.com/code/vim/lua-inspect/

--]]

local function offset2lineinfo(text, offset)
  -- TODO Cache intermediate results because they won't change within a single
  --      call to the function returned from this module below.
  local curlnum = 1
  local lastlineoffset = 0
  for i in text:gmatch '()\n' do
    if i < offset then
      curlnum = curlnum + 1
      lastlineoffset = i
    else
      break
    end
  end
  return curlnum, offset - lastlineoffset
end

return function(text)
  -- Load the LuaInspect core module.
  local LI = require 'luainspect.init'
  text = LI.remove_shebang(text)
  local f, err, linenum, colnum, linenum2 = LI.loadstring(text)
  local function dumpvar(kind, firstbyte, lastbyte)
    local line1, offset1 = offset2lineinfo(text, firstbyte)
    if type(vim) == 'table' and vim.eval then
      -- The Lua interface for Vim redefines print() so it prints inside Vim.
      print(kind, line1, offset1, offset1 + (lastbyte - firstbyte))
    else
      -- My $LUA_INIT script redefines print() to enable pretty printing in the
      -- interactive prompt, which means strings are printed with surrounding
      -- quotes. This would break the communication between Vim and this script.
      io.write(kind, '\t', line1, '\t', offset1, '\t', offset1 + (lastbyte - firstbyte), '\n')
    end
  end
  if f then
    local ast; ast, err, linenum, colnum, linenum2 = LI.ast_from_string(text, "noname.lua")
    if ast then
      for i, note in ipairs(LI.inspect(ast)) do
        if note.type == 'global' then
          if note.definedglobal then
            dumpvar('luaInspectGlobalDefined', note[1], note[2])
          else
            dumpvar('luaInspectGlobalUndefined', note[1], note[2])
          end
        elseif note.type == 'local' then
          if not note.ast.localdefinition.isused then
            dumpvar('luaInspectLocalUnused', note[1], note[2])
          elseif note.ast.localdefinition.isset then
            dumpvar('luaInspectLocalMutated', note[1], note[2])
          elseif note.ast.localdefinition.functionlevel  < note.ast.functionlevel then
            dumpvar('luaInspectUpValue', note[1], note[2])
          elseif note.ast.localdefinition.isparam then
            dumpvar('luaInspectParam', note[1], note[2])
          else
            dumpvar('luaInspectLocal', note[1], note[2])
          end
        elseif note.type == 'field' then
          if note.definedglobal or note.ast.seevalue.value ~= nil then
            dumpvar('luaInspectFieldDefined', note[1], note[2])
          else
            dumpvar('luaInspectFieldUndefined', note[1], note[2])
          end
        end
      end
    end
  end
end

-- vim: ts=2 sw=2 et
