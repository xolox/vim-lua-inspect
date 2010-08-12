--[[

 This module is part of the luainspect.vim plug-in for the Vim text editor.

 Author: Peter Odding <peter@peterodding.com>
 Last Change: August 12, 2010
 URL: http://peterodding.com/code/vim/lua-inspect/
 License: MIT

--]]

local MAX_PREVIEW_KEYS = 20

local LI = require 'luainspect.init'
local LA = require 'luainspect.ast'
local LS = require 'luainspect.signatures'
local actions, myprint, getcurvar, knownvarorfield = {}
local printvartype, printsignature, printvalue

if type(vim) == 'table' and vim.eval then
  -- The Lua interface for Vim redefines print() so it prints inside Vim.
  myprint = print
else
  -- My $LUA_INIT script redefines print() to enable pretty printing in the
  -- interactive prompt, which means strings are printed with surrounding
  -- quotes. This would break the communication between Vim and this script.
  function myprint(text) io.write(text, '\n') end
end

function getcurvar(tokenlist, line, column) -- {{{1
  for i, token in ipairs(tokenlist) do
    if token.ast.lineinfo then
      local l1, c1 = unpack(token.ast.lineinfo.first, 1, 2)
      local l2, c2 = unpack(token.ast.lineinfo.last, 1, 2)
      if l1 == line and column >= c1 and column <= c2 then
        if token.ast.id then return token end
      end
    end
  end
end

function knownvarorfield(token) -- {{{1
  local a = token.ast
  local v = a.seevalue or a
  return a.definedglobal or v.valueknown and v.value ~= nil
end

function actions.highlight(tokenlist, line, column) -- {{{1
  local function dump(token, hlgroup)
    local l1, c1 = unpack(token.ast.lineinfo.first, 1, 2)
    local l2, c2 = unpack(token.ast.lineinfo.last, 1, 2)
    myprint(hlgroup .. ' ' .. l1 .. ' ' .. c1 .. ' ' .. c2)
  end
  local curvar = getcurvar(tokenlist, line, column)
  for i, token in ipairs(tokenlist) do
    if curvar and curvar.ast.id == token.ast.id then
      dump(token, 'luaInspectSelectedVariable')
    end
    if token.ast.note and token.ast.note:find '[Tt]oo%s+%w+%s+arguments' then
      local l1, c1 = unpack(token.ast.lineinfo.first, 1, 2)
      local l2, c2 = unpack(token.ast.lineinfo.last, 1, 2)
      dump(token, 'luaInspectWrongArgCount')
    end
    if token.tag == 'Id' then
      if not token.ast.localdefinition then
        dump(token, token.ast.definedglobal and 'luaInspectGlobalDefined' or 'luaInspectGlobalUndefined')
      elseif not token.ast.localdefinition.isused then
        dump(token, 'luaInspectLocalUnused')
      elseif token.ast.localdefinition.functionlevel < token.ast.functionlevel then
        dump(token, 'luaInspectUpValue')
      elseif token.ast.localdefinition.isset then
        dump(token, 'luaInspectLocalMutated')
      elseif token.ast.localdefinition.isparam then
        dump(token, 'luaInspectParam')
      else
        dump(token, 'luaInspectLocal')
      end
    elseif token.ast.isfield then
      dump(token, knownvarorfield(token) and 'luaInspectFieldDefined' or 'luaInspectFieldUndefined')
    end
  end
end

function actions.tooltip(tokenlist, line, column) -- {{{1
  local did_details = false
  local note
  for i, token in ipairs(tokenlist) do
    if token.ast.lineinfo then
      local l1, c1 = unpack(token.ast.lineinfo.first, 1, 2)
      local l2, c2 = unpack(token.ast.lineinfo.last, 1, 2)
      if l1 == line then
        local ast = token.ast
        if ast and column >= c1 and column <= c2 then
          if ast.id and not did_details then
            printvartype(token)
            printsignature(ast)
            printvalue(ast)
            if note then
              myprint(note)
              break
            end
          end
          if ast.note then
            -- This is complicated by the fact that I don't really understand
            -- the metalua/lua-inspect abstract syntax tree and apparently notes
            -- are not always available on the identifier token printed above.
            local iswarning = ast.note:find '[Tt]oo%s+%w+%s+arguments'
            note = (iswarning and "Warning: " or "Note: ") .. ast.note
            if did_details then
              myprint(note)
              break
            end
          end
        end
      end
    end
  end
end

function printvartype(token) -- {{{1
  local ast = token.ast
  local text = {}
  if ast.localdefinition then
    if not ast.localdefinition.isused then text[#text+1] = "unused" end
    if ast.localdefinition.isset then text[#text+1] = "mutable" end
    if ast.localmasking then text[#text+1] = "masking" end
    if ast.localmasked then text[#text+1] = "masked" end
    if ast.localdefinition.functionlevel < ast.functionlevel then
      text[#text+1] = "upvalue"
    elseif ast.localdefinition.isparam then
      text[#text+1]  = "function parameter"
    else
      text[#text+1] = "local variable"
    end
  elseif ast.tag == 'Id' then
    text[#text+1] = knownvarorfield(token) and "known" or "unknown"
    text[#text+1] = "global variable"
  elseif ast.isfield then
    text[#text+1] = knownvarorfield(token) and "known" or "unknown"
    text[#text+1] = "table field"
  else
    return
  end
  -- TODO Bug in luainspect's static analysis? :gsub() below is marked as an
  -- unknown table field even though table.concat() returns a string?!
  text = table.concat(text, ' ')
  myprint("This is " .. (text:find '^[aeiou]' and 'an' or 'a') .. ' ' .. text .. '.')
end

function printsignature(ast) -- {{{1
  -- Display signatures for standard library functions.
  local name = ast.resolvedname
  local signature = name and LS.global_signatures[name]
  if not signature then
    local value = (ast.seevalue or ast).value
    signature = value and LS.value_signatures[value]
  end
  if signature then
    if not signature:find '%w %b()$' then
      myprint 'Its description is:'
      myprint('    ' .. signature)
    else
      myprint 'Its signature is as follows:'
      myprint('    ' .. signature)
    end
  end
end

function printvalue(ast) -- {{{1
  -- Try to represent the value as a string.
  local value = (ast.seevalue or ast).value
  if type(value) == 'table' then
    -- Print at most MAX_PREVIEW_KEYS of the table's keys.
    local keys = {}
    for k, v in pairs(value) do
      if type(k) == 'string' then
        keys[#keys+1] = k .. (type(v) == 'function' and '()' or '')
      elseif type(k) == 'number' then
        keys[#keys+1] = '[' .. k .. ']'
      else
        keys[#keys+1] = tostring(k)
      end
    end
    table.sort(keys)
    if #keys > MAX_PREVIEW_KEYS then
      myprint('Its value is a table with ' .. #keys .. ' fields including:')
      for i, k in ipairs(keys) do
        myprint(' - ' .. k)
        if i == MAX_PREVIEW_KEYS then break end
      end
    elseif #keys >= 1 then
      myprint("Its value is a table with the following field" .. (#keys > 1 and "s" or '') .. ":")
      for i, k in ipairs(keys) do myprint(' - ' .. k) end
    else
      myprint 'Its value is a table.'
    end
  elseif type(value) == 'string' then
    -- Print string value.
    if value ~= '' then
      myprint("Its value is the string " .. string.format('%q', value) .. ".")
    else
      myprint "Its value is a string."
    end
  elseif type(value) == 'function' then
    -- Print function details.
    local text = { "Its value is a" }
    local info = debug.getinfo(value)
    text[#text+1] = info.what
    text[#text+1] = "function"
    -- Try to find out where the function was defined.
    local source = (info.source or ''):match '^@(.+)$'
    if source and not source:find '[\\/]+luainspect[\\/]+.-%.lua$' then
      source = source:gsub('^/home/[^/]+/', '~/')
      text[#text+1] = "defined in"
      text[#text+1] = source
      if info.linedefined then
        text[#text+1] = "on line"
        text[#text+1] = info.linedefined
      end
    end
    myprint(table.concat(text, ' ') .. '.')
  elseif type(value) == 'userdata' then
    myprint("Its value is a " .. type(value) .. '.')
  elseif value ~= nil then
    myprint("Its value is the " .. type(value) .. ' ' .. tostring(value) .. '.')
  end
end

function actions.goto(tokenlist, line, column) -- {{{1
  -- FIXME This only jumps to declaration of local / 1st occurrence of global.
  local curvar = getcurvar(tokenlist, line, column)
  for i, token in ipairs(tokenlist) do
    if curvar and curvar.ast.id == token.ast.id then
      local l1, c1 = unpack(token.ast.lineinfo.first, 1, 2)
      myprint(l1)
      myprint(c1)
      break
    end
  end
end

function actions.rename(tokenlist, line, column) -- {{{1
  local curvar = getcurvar(tokenlist, line, column)
  for i, token in ipairs(tokenlist) do
    if curvar and curvar.ast.id == token.ast.id then
      local l1, c1 = unpack(token.ast.lineinfo.first, 1, 2)
      local l2, c2 = unpack(token.ast.lineinfo.last, 1, 2)
      if l1 == l2 then myprint(l1 .. ' ' .. c1 .. ' ' .. c2) end
    end
  end
end

-- }}}

return function(src)
  local action, line, column, src = src:match '^(%S+)\n(%d+)\n(%d+)\n(.*)$'
  line = tonumber(line)
  column = tonumber(column)
  src = LA.remove_shebang(src)
  -- Quickly parse the source code using loadstring() to check for syntax errors.
  local f, err, linenum, colnum, linenum2 = LA.loadstring(src)
  if not f then
    myprint 'syntax_error'
    myprint(linenum)
    myprint(colnum)
    myprint(linenum2 or 0)
    -- Remove prefixed line number from error message because it's redundant.
    myprint((err:gsub('^%d+:%s+', '')))
    return
  end
  -- Now parse the source code using metalua to build an abstract syntax tree.
  local ast; ast, err, linenum, colnum, linenum2 = LA.ast_from_string(src, "noname.lua")
  if not ast then return end
  -- Create a list of tokens from the AST and decorate it using luainspect.
  local tokenlist = LA.ast_to_tokenlist(ast, src)
  LI.inspect(ast, tokenlist)
  -- Branch on requested action.
  if actions[action] then
    myprint(action)
    actions[action](tokenlist, line, column)
  end
end

-- Enable type checking of ast.* expressions.
--! require 'luainspect.typecheck' (context)

-- vim: ts=2 sw=2 et
