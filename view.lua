local M = {}

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local bell = require("bell")

--
-- Scroll by View Height / Scroll by Line
--

-- key: Ctrl-f
local function down()
	bell.not_planned("Ctrl-f (view.down)")
end

-- key: Ctrl-b
local function up()
	bell.not_planned("Ctrl-b (view.up)")
end

-- key: Ctrl-d
local function down_half()
	bell.not_planned("Ctrl-d (view.down_half)")
end

-- key: Ctrl-u
local function up_half()
	bell.not_planned("Ctrl-u (view.up_half)")
end

-- key: Ctrl-y
local function down_line()
	bell.not_planned("Ctrl-y (view.down_line)")
end

-- key: Ctrl-e
local function up_line()
	bell.not_planned("Ctrl-e (view.up_line)")
end

--
-- Reposition
--

-- key: z Enter
local function to_top()
	bell.planned("z Enter (view.to_top)")
end

-- key: z.
local function to_middle()
	bell.planned("z. (view.to_middle)")
end

-- key: z-
local function to_bottom()
	bell.planned("z- (view.to_bottom)")
end

--
-- Redraw
--

-- key: Ctrl-l
local function redraw()
	bell.not_planned("Ctrl-l (view.redraw)")
end

-- Scroll by View Height / Scroll by Line
M.down = down
M.up = up
M.down_half = down_half
M.up_half = up_half
M.down_line = down_line
M.up_line = up_line

-- Reposition
M.to_top = to_top
M.to_middle = to_middle
M.to_bottom = to_bottom

-- Redraw
M.redraw = redraw

return M
