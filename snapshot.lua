local micro = import("micro")

local cache = {
	y = nil,
	line = nil,
}

local function get_cache()
	return { y = cache.y, line = cache.line }
end

local function update()
	local buf = micro.CurPane().Buf
	local cursor = buf:GetActiveCursor()
	if cache.y ~= cursor.Y then
		cache.y = cursor.Y
		cache.line = buf:Line(cursor.Y)
	end
end

-------------
-- Exports --
-------------

local M = {}

M.cache = get_cache
M.update = update

return M
