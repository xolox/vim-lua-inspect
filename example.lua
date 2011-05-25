-- A local variable masking a global one:
global_variable = '1st value'
do
  local global_variable = 'NOT ACTUALLY A GLOBAL!'
  print(global_variable)
end
global_variable = '2nd value'

-- Highlighting for different types of locals:
local usedlocal = 'this is a local variable'
local mutated = "this one's assigned multiple times"
local unused = "and this one isn't referenced anywhere"
mutated = 'this is the second value of [mutated]'
print(usedlocal)
print(undefined)

io.open('')
string.lower('')
local tinsert = table.insert
local test = { field = function(foo, bar, baz) print(baz) end }

-- Highlighting for function arguments:
local function example(usedparam, mutatedparam, unusedparam)
  mutatedparam = 42
  print(usedparam)
end

-- Argument count checking:

  example(1)

for k, v in pairs(_G) do print(k) end

  example (
    1,
    2,
    3,
    4)

-- Syntax errors:
-- example(..)
