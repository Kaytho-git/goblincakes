-- The globals a Lua file reads (G <line> <name>) and writes (S …), for wowapi.py's check (30 Oct): LuaJIT's own
-- compiler tells which names are globals – a local that went missing (gemma4's sed deleted `local ilvl = …`) reads as one.
local ju = require("jit.util")
local vmdef = require("jit.vmdef")
local names = vmdef.bcnames
local function op(ins)
  local o = ins % 256
  return names:sub(o * 6 + 1, o * 6 + 6):gsub(" ", "")
end
local function walk(fn)
  local pc = 1
  while true do
    local ins = ju.funcbc(fn, pc)
    if not ins then break end
    local name = op(ins)
    if name == "GGET" or name == "GSET" then
      local d = math.floor(ins / 65536)
      local k = ju.funck(fn, -d - 1)
      local line = ju.funcinfo(fn, pc).currentline
      io.write(name == "GGET" and "G " or "S ", line, " ", tostring(k), "\n")
    end
    pc = pc + 1
  end
  local i = -1
  while true do
    local k = ju.funck(fn, i)
    if k == nil then break end
    if type(k) == "proto" then walk(k) end
    i = i - 1
  end
end
local f, err = loadfile(arg[1])
if not f then io.stderr:write(err, "\n") os.exit(1) end
walk(f)
