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
	local pane = micro.CurPane()
	local matched = false

	--
	-- Move
	--

	if pb:match("%d+") then
		-- Move cursor to line <num>.
		bell.planned()
		matched = true
	end

	--
	-- File
	--

	if pb == "wq" then
		-- Save current file and quit.
		bell.planned()
		matched = true
	elseif pb == "w" then
		-- Save current file.
		pane:Save()
		matched = true
	elseif pb == "w!" then
		-- Force save current file.
		bell.not_planned()
		matched = true
	elseif pb == "q" then
		-- Quit editor.
		pane:Quit()
		matched = true
	elseif pb == "q!" then
		-- Force quit editor.
		pane:ForceQuit()
		matched = true
	elseif pb == "e" then
		-- Open file.
		pane:OpenFile()
		matched = true
	elseif pb == "e!" then
		-- Force open file.
		bell.planned()
		matched = true
	elseif pb == "r" then
		-- Read file and insert to current buffer.
		bell.not_planned()
		matched = true
	elseif pb == "n" then
		-- Switch to next buffer (tab).
		bell.planned()
		matched = true
	elseif pb == "prev" then
		-- Switch to previous buffer (tab).
		bell.planned()
		matched = true
	end

	--
	-- Utility
	--

	if pb == "sh" then
		-- Execute shell.
		bell.planned()
		matched = true
	end

	--
	-- From Vim
	--

	if pb == "wa" then -- vim
		-- Save all files.
		pane:SaveAll()
		matched = true
	elseif pb == "qa" then -- vim
		-- Close all files and quit editor.
		pane:QuitAll()
		matched = true
	elseif pb == "qa!" then -- vim
		-- Force close all files and quit editor.
		pane:QuitAll()
		matched = true
	end

	if not matched then
		bell.vi_error("not (yet) a ex command [" .. pb .. "]")
	end

	clear()
	mode.command()
end

local function escape()
	clear()
	micro.InfoBar():Message("")
	mode.command()
end

--
-- exports
--

M.show = show
M.insert_chars = insert_chars
M.enter = enter
M.escape = escape

return M
