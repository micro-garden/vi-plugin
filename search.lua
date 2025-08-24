-- Search Commands

local micro = import("micro")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local mode = require("vi/mode")
local context = require("vi/context")

local backward_mode = false

-- /<pattern> Enter - Search <pattern> forward.
local function forward()
	context.memorize()

	mode.search()
	backward_mode = false
	micro.CurPane():Find()
end

-- ?<pattern> Enter : Search <pattern> backward.
local function backward()
	context.memorize()

	mode.search()
	backward_mode = true
	micro.CurPane():Find()
end

-- internal use
-- (none) : Search next match forward.
local function match_forward(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	context.memorize()

	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	if cursor.X < length then
		cursor.X = cursor.X + 1
	end

	for _ = 1, num do
		pane:FindNext()
	end

	if cursor:HasSelection() then
		local start = cursor.CurSelection[1]
		cursor.X = start.X
		cursor.Y = start.Y
		cursor:ResetSelection()
	end
end

-- internal use
-- (none) : Search next match backward.
local function match_backward(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	context.memorize()

	local pane = micro.CurPane()
	for _ = 1, num do
		pane:FindPrevious()
	end

	local cursor = pane.Buf:GetActiveCursor()
	if cursor:HasSelection() then
		local start = cursor.CurSelection[1]
		cursor.X = start.X
		cursor.Y = start.Y
		cursor:ResetSelection()
	end
end

-- n : Search next match.
local function next_match(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	if backward_mode then
		match_backward(num)
	else
		match_forward(num)
	end
end

-- N : Search previous match.
local function prev_match(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	if backward_mode then
		match_forward(num)
	else
		match_backward(num)
	end
end

-- / Enter : Repeat last search forward.
local function repeat_forward(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	backward_mode = false
	match_forward(num)
end

-- ? Enter : Repeat last search backward.
local function repeat_backward(num)
	if num < 1 then
		bell.program_error("1 > num == " .. num)
		return
	end

	backward_mode = true
	match_backward(num)
end

-------------
-- Exports --
-------------

local M = {}

M.forward = forward
M.backward = backward
M.next_match = next_match
M.prev_match = prev_match
M.repeat_forward = repeat_forward
M.repeat_backward = repeat_backward

return M
