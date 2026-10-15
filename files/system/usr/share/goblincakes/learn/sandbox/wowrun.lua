-- GOBLINCAKES lärläge: a small stand-in for World of Warcraft's API, so the basics of an addon can be
-- run and checked outside the game (Lua 5.1, like WoW). Not the whole API – the final test is in WoW.
-- Usage: lua5.1 wowrun.lua main.lua   (runs the addon, then ADDON_LOADED and PLAYER_LOGIN;
-- a file "slash.txt" with e.g. "/hej Kaytho" runs that slash command afterwards)
local ADDON = "MittTillagg"
local frames, eventFrames = {}, {}
SlashCmdList = {}

local function newRegion(kind, name, parent)
  local r = { _kind = kind, _name = name, _parent = parent, _shown = true, _scripts = {}, _events = {},
              _points = {}, _text = "" }
  function r:GetName() return self._name end
  function r:GetParent() return self._parent end
  function r:Show() self._shown = true end
  function r:Hide() self._shown = false end
  function r:IsShown() return self._shown end
  function r:SetShown(v) self._shown = not not v end
  function r:SetSize(w, h) self._w, self._h = w, h end
  function r:GetSize() return self._w or 0, self._h or 0 end
  function r:SetWidth(w) self._w = w end
  function r:SetHeight(h) self._h = h end
  function r:GetWidth() return self._w or 0 end
  function r:GetHeight() return self._h or 0 end
  function r:SetPoint(...) table.insert(self._points, { ... }) end
  function r:ClearAllPoints() self._points = {} end
  function r:SetAlpha(a) self._alpha = a end
  function r:SetText(t) self._text = tostring(t or "") end
  function r:GetText() return self._text end
  function r:SetFormattedText(fmt, ...) self._text = string.format(fmt, ...) end
  function r:SetTextColor(...) self._color = { ... } end
  function r:SetFont(...) end
  function r:SetFontObject(...) end
  function r:SetJustifyH(...) end
  function r:SetTexture(t) self._texture = t end
  function r:SetColorTexture(...) self._texture = { ... } end
  function r:SetAllPoints() self._all = true end
  function r:SetMovable(v) self._movable = v end
  function r:EnableMouse(v) self._mouse = v end
  function r:RegisterForDrag(...) end
  function r:SetBackdrop(b) self._backdrop = b end
  function r:SetScript(what, fn) self._scripts[what] = fn end
  function r:GetScript(what) return self._scripts[what] end
  function r:HookScript(what, fn)
    local old = self._scripts[what]
    self._scripts[what] = function(...) if old then old(...) end fn(...) end
  end
  function r:RegisterEvent(e) self._events[e] = true; eventFrames[self] = true end
  function r:UnregisterEvent(e) self._events[e] = nil end
  function r:UnregisterAllEvents() self._events = {} end
  function r:IsEventRegistered(e) return self._events[e] == true end
  function r:CreateFontString(n) return newRegion("FontString", n, self) end
  function r:CreateTexture(n) return newRegion("Texture", n, self) end
  function r:Click() local f = self._scripts.OnClick; if f then f(self, "LeftButton") end end
  return r
end

function CreateFrame(kind, name, parent, template)
  local f = newRegion(kind or "Frame", name, parent)
  table.insert(frames, f)
  if name then _G[name] = f end
  return f
end

UIParent = newRegion("Frame", "UIParent")
DEFAULT_CHAT_FRAME = { AddMessage = function(_, msg) print(msg) end }

local playerName = "Kaytho"
function UnitName(unit) if unit == "player" then return playerName, nil end return nil end
function UnitClass(unit) if unit == "player" then return "Präst", "PRIEST", 5 end end
function UnitLevel(unit) return 80 end
function UnitHealth(unit) return 100000 end
function UnitHealthMax(unit) return 120000 end
function GetTime() return 1000.5 end
function GetRealmName() return "Stormscale" end
function IsInGroup() return false end
function IsInRaid() return false end
C_Timer = { After = function(sec, fn) fn() end, NewTicker = function(sec, fn, n) for i = 1, (n or 1) do fn() end return { Cancel = function() end } end }
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strsplit = function(sep, s)
  local out = {}
  for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do table.insert(out, part) end
  return unpack(out)
end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
tinsert, tremove = table.insert, table.remove
format = string.format

local function fire(event, ...)
  for f in pairs(eventFrames) do
    if f._events[event] and f._scripts.OnEvent then
      f._scripts.OnEvent(f, event, ...)
    end
  end
end
_G.GOBLINCAKES_FireEvent = fire

local file = arg[1] or "main.lua"
local chunk, err = loadfile(file)
if not chunk then io.stderr:write("Fel i koden: " .. tostring(err) .. "\n") os.exit(1) end
local ok, runErr = pcall(chunk, ADDON, {})
if not ok then io.stderr:write("Fel när tillägget laddades: " .. tostring(runErr) .. "\n") os.exit(1) end
fire("ADDON_LOADED", ADDON)
fire("PLAYER_LOGIN")
local slash = io.open("slash.txt")
if slash then
  for line in slash:lines() do
    local cmd, rest = line:match("^(/%S+)%s*(.*)$")
    if cmd then
      local found = false
      for key, fn in pairs(SlashCmdList) do
        for i = 1, 9 do
          local s = _G["SLASH_" .. key .. i]
          if s and s:lower() == cmd:lower() then fn(rest) found = true end
        end
      end
      if not found then print("Okänt kommando: " .. cmd) end
    end
  end
  slash:close()
end
