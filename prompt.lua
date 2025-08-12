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

local PROMPT = ":"

local prompt_buffer = ""

local function show()
	micro.InfoBar():Message(PROMPT .. prompt_buffer)
end

local function insert_chars(chars)
	prompt_buffer = prompt_buffer .. chars
	show()
end

local function clear()
	prompt_buffer = ""
end

local function enter()
	local pb = prompt_buffer
	if pb == "w" then
		local pane = micro.CurPane()
		pane:Save()
	elseif pb == "q" then
		local pane = micro.CurPane()
		pane:Quit()
	elseif pb == "q!" then
		local pane = micro.CurPane()
		pane:ForceQuit()
	elseif pb == "e" then
		local pane = micro.CurPane()
		pane:OpenFile()
	elseif pb == "wa" then -- vim
		local pane = micro.CurPane()
		pane:SaveAll()
	else
		bell.vi_error("unknown command: " + pb)
	end
	clear()
	mode.command()
end

local function escape()
	clear()
	micro.InfoBar():Message("")
	mode.command()
end

M.show = show
M.insert_chars = insert_chars
M.enter = enter
M.escape = escape

return M
