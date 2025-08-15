-- Miscellaneous Commands
local M = {}

local micro = import("micro")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local bell = require("bell")
local mode = require("mode")

-- Ctrl-g : Show info such as current cursor position.
local function show_info()
	bell.not_planned("Ctrl-g (misc.show_info)")
end

-- . : Repeat last edit.
-- repeat is implemented in command.lua

-- u : Undo.
-- undo is implemented in command.lua

-- U : Restore current line to previous state.
local function restore()
	bell.planned("U (misc.restore)")
end

-- ZZ : Save and quit.
local function save_and_quit()
	mode.show()

	micro.CurPane():QuitCmd({})
end

--
-- exports
--

M.show_info = show_info
--M.repeat = repeat
--M.undo = undo
M.restore = restore
M.save_and_quit = save_and_quit

return M
