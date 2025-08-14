local M = {}

local micro = import("micro")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local mode = require("mode")

local backward_mode = false

-- key: /
local function forward()
	mode.search()
	backward_mode = false
	micro.CurPane():Find()
end

-- key: ?
local function backward()
	mode.search()
	backward_mode = true
	micro.CurPane():Find()
end

--
local function match_forward(num)
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

local function match_backward(num)
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

-- key: n
local function next_match(num)
	if backward_mode then
		match_backward(num)
	else
		match_forward(num)
	end
end

-- key: N
local function prev_match(num)
	if backward_mode then
		match_forward(num)
	else
		match_backward(num)
	end
end

-- key: / Enter
local function repeat_forward(num)
	backward_mode = false
	match_forward(num)
end

-- key: ? Enter
local function repeat_backward(num)
	backward_mode = true
	match_backward(num)
end

M.forward = forward
M.backward = backward
M.next_match = next_match
M.prev_match = prev_match
M.repeat_forward = repeat_forward
M.repeat_backward = repeat_backward

return M
