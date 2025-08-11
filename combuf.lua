M = {}

local buf = "" -- command buffer

local function get()
	return buf
end

-- note: don't use name insert as function name
local function insert_chars(chars)
	buf = buf .. chars
end

local function clear()
	buf = ""
end

M.get = get
M.insert_chars = insert_chars
M.clear = clear

return M
