--[[

 This module is part of the luainspect.vim plug-in for the Vim text editor.

 Author: Peter Odding <peter@peterodding.com>
 Last Change: July 18, 2013
 URL: http://peterodding.com/code/vim/lua-inspect/
 License: MIT

--]]

local LI = require 'luainspect.init'
local LA = require 'luainspect.ast'
local LT = require 'luainspect.types'
local MAX_PREVIEW_KEYS = 20
local actions = {}
local myprint

if type(vim) == 'table' and vim.eval then
  -- The Lua interface for Vim redefines print() so it prints inside Vim.
  myprint = print
else
  -- My $LUA_INIT script redefines print() to enable pretty printing in the
  -- interactive prompt, which means strings are printed with surrounding
  -- quotes. This would break the communication between Vim and this script.
  function myprint(text) io.write(text, '\n') end
end

local function getcurvar(tokenlist, line, column) -- {{{1
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

function actions.highlight(tokenlist, line, column, src) -- {{{1
  local function dump(token, hlgroup)
    local l1, c1 = unpack(token.ast.lineinfo.first, 1, 2)
    local l2, c2 = unpack(token.ast.lineinfo.last, 1, 2)
    myprint(('%s %i %i %i %i'):format(hlgroup, l1, c1, l2, c2))
  end
  -- Print any warnings to show in Vim's quick-fix list.
  -- FIXME Why does this report argument count warnings in luainspect/init.lua but not in example.lua?!
  local warnings = LI.list_warnings(tokenlist, src)
  myprint(#warnings)
  for i, warning in ipairs(warnings) do
    warning = warning:gsub('%s+', ' ')
    myprint(warning)
  end
  local curvar = getcurvar(tokenlist, line, column)
  for i, token in ipairs(tokenlist) do
    if curvar and curvar.ast.id == token.ast.id then
      dump(token, 'luaInspectSelectedVariable')
    end
    local ast = token.ast
    if ast and (ast.seevalue or ast).note then
      local hast = ast.seevalue or ast
      if hast.tag == 'Call' then
        hast = hast[1]
      elseif hast.tag == 'Invoke' then
        hast = hast[2]
      end
      local fpos, lpos = LA.ast_pos_range(hast, tokenlist)
      local l1, c1 = LA.pos_to_linecol(fpos, src)
      local l2, c2 = LA.pos_to_linecol(lpos, src)
      -- TODO: A bit confusing is that LuaInspect seems to emit both zero-based
      -- and one-based column numbers (i.e. offsets vs. indices) since the
      -- included Metalua lexer was patched to fix a rare bug.
      myprint(('luaInspectWrongArgCount %i %i %i %i'):format(l1, c1 - 1, l2, c2 - 1))
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
      local a = token.ast
      if a.definedglobal or not LT.istype[a.seevalue.value] and a.seevalue.value ~= nil then
        dump(token, 'luaInspectFieldDefined')
      else
        dump(token, 'luaInspectFieldUndefined')
      end
    end
  end
end

local function previewtable(ast) -- {{{1
  -- Print a preview of a table's fields.
  local value = (ast.seevalue or ast).value
  if type(value) == 'table' then
    -- Print at most MAX_PREVIEW_KEYS of the table's keys.
    local keys = {}
    local count = 0
    for k, v in pairs(value) do
      if #keys < MAX_PREVIEW_KEYS then
        if type(k) == 'string' and k:find '^[A-Za-z_][A-Za-z0-9_]*$' then
          keys[#keys+1] = k .. (type(v) == 'function' and '()' or '')
        end
      end
      count = count + 1
    end
    table.sort(keys)
    if count > 0 then
      local fields = #keys == 1 and ' field' or ' fields'
      local including = count ~= #keys and ' including' or ''
      myprint('This table contains ' .. count .. fields .. including .. ':')
      for i, k in ipairs(keys) do myprint(' - ' .. k) end
    end
  end
end

function actions.tooltip(tokenlist, line, column, src) -- {{{1
  for i, token in ipairs(tokenlist) do
    local ast = token.ast
    if ast.lineinfo then
      local l1, c1 = unpack(ast.lineinfo.first, 1, 2)
      local l2, c2 = unpack(ast.lineinfo.last, 1, 2)
      if l1 == line then
        if column >= c1 and column <= c2 and ast.id then
          local details = LI.get_value_details(ast, tokenlist, src)
          if details ~= '?' then
            -- Convert variable type to readable sentence (friendlier to new users IMHO).
            details = details:gsub('^[^\n]+', function(vartype)
              vartype = vartype:match '^%s*(.-)%s*$'
              if vartype:find 'local$' or vartype:find 'global' then
                vartype = vartype .. ' ' .. 'variable'
              end
              local article = details:find '^[aeiou]' and 'an' or 'a'
              return "This is " .. article .. ' ' .. vartype .. '.'
            end)
            myprint(details)
          end
          previewtable(ast)
          break
        end
      end
    end
  end
end

function actions.go_to(tokenlist, line, column) -- {{{1
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
  local action, file, line, column
  action, file, line, column, src = src:match '^(%S+)\n([^\n]*)\n(%d+)\n(%d+)\n(.*)$'
  line = tonumber(line)
  -- This adjustment was found by trial and error :-|
  column = tonumber(column) - 1
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
  -- Now parse the source code using Metalua to build an abstract syntax tree.
  local ast = LA.ast_from_string(src, file)
  -- This shouldn't happen: Metalua failed to parse what loadstring() accepts!
  if not ast then return end
  -- Create a list of tokens from the AST and decorate it using LuaInspect.
  local tokenlist = LA.ast_to_tokenlist(ast, src)
  LI.inspect(ast, tokenlist, src)
  -- Branch on the requested action.
  if actions[action] then
    myprint(action)
    actions[action](tokenlist, line, column, src)
  end
end

-- Enable type checking of ast.* expressions.
--! require 'luainspect.typecheck' (context)

-- vim: ts=2 sw=2 et
