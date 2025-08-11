M = {}

local micro = import("micro")
local utf8 = import("unicode/utf8")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local mode = require("mode")

local reverse_mode = false

local function find()
	mode.find()
	reverse_mode = false
	micro.CurPane():Find()
end

local function reverse_find()
	mode.find()
	reverse_mode = true
	micro.CurPane():Find()
end

local function find_next_internal(number)
	local pane = micro.CurPane()
	local buf = pane.Buf
	local cursor = buf:GetActiveCursor()
	local line = buf:Line(cursor.Y)
	local length = utf8.RuneCount(line)
	if cursor.X < length then
		cursor.X = cursor.X + 1
	end

	for _ = 1, number do
		pane:FindNext()
	end

	if cursor:HasSelection() then
		local start = cursor.CurSelection[1]
		cursor.X = start.X
		cursor.Y = start.Y
		cursor:ResetSelection()
	end
end

local function find_prev_internal(number)
	local pane = micro.CurPane()
	for _ = 1, number do
		pane:FindPrevious()
	end

	local cursor = pane.Buf:GetActiveCursor()
	if cursor:HasSelection() then
		local start = cursor.CurSelection[1]
		cursor.Loc.X = start.X
		cursor.Loc.Y = start.Y
		cursor:ResetSelection()
	end
end

local function find_next(number)
	if reverse_mode then
		find_prev_internal(number)
	else
		find_next_internal(number)
	end
end

local function find_prev(number)
	if reverse_mode then
		find_next_internal(number)
	else
		find_prev_internal(number)
	end
end

M.find = find
M.reverse_find = reverse_find
M.find_next = find_next
M.find_prev = find_prev

return M
