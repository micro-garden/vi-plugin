M = {}

local micro = import("micro")

local config = import("micro/config")
local plug_path = config.ConfigDir .. "/plug/vi/?.lua"
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
	micro.CurPane():FindNext()
	for _ = 1, number do
		micro.CurPane():FindNext()
	end

	local cursor = micro.CurPane().Buf:GetActiveCursor()
	if cursor:HasSelection() then
		local start = cursor.CurSelection[1]
		cursor.Loc.X = start.X
		cursor.Loc.Y = start.Y
		cursor:ResetSelection()
	end
end

local function find_prev_internal(number)
	for _ = 1, number do
		micro.CurPane():FindPrevious()
	end

	local cursor = micro.CurPane().Buf:GetActiveCursor()
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
