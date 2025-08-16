local micro = import("micro")
local buffer = import("micro/buffer")

local config = import("micro/config")
local plug_name = "vi"
local plug_path = config.ConfigDir .. "/plug/" .. plug_name .. "/?.lua"
if not package.path:find(plug_path, 1, true) then
	package.path = package.path .. ";" .. plug_path
end

local utils = require("utils")
local bell = require("bell")
local mode = require("mode")
local prompt = require("prompt")
local move = require("move")
local mark = require("mark")
local view = require("view")
local search = require("search")
local find = require("find")
local insert = require("insert")
local operator = require("operator")
local edit = require("edit")
local misc = require("misc")

local command_cache = nil

local undo_mode = true -- true: undo, false: redo

local function cache_command(no_num, num, op, no_subnum, subnum, mv, letter)
	command_cache = {}

	command_cache.no_num = no_num
	command_cache.num = num
	command_cache.op = op
	command_cache.no_subnum = no_subnum
	command_cache.subnum = subnum
	command_cache.mv = mv
	command_cache.letter = letter
end

local function get_command_cache()
	return command_cache.no_num,
		command_cache.num,
		command_cache.op,
		command_cache.no_subnum,
		command_cache.subnum,
		command_cache.mv,
		command_cache.letter,
		true -- replay
end

-- Note: Declaration is used in repeat_command(). Definition is far below.
local run

local function repeat_command(num)
	mode.show()

	if not command_cache then
		bell.vi_info("nothing to repeat yet")
		return
	end

	for _ = 1, num do
		run(get_command_cache())
	end
end

local function undo(num, replay)
	if utils.xor(undo_mode, replay) then
		for _ = 1, num do
			micro.CurPane():Undo()
		end
	else -- redo
		for _ = 1, num do
			micro.CurPane():Redo()
		end
	end

	if not replay then
		undo_mode = not undo_mode
	end
end

local function run_move(no_num, num, mv)
	-- Move by Character / Move by Line
	if mv == "h" then
		move.left(num)
		return true
	elseif mv == "j" then
		move.down(num)
		return true
	elseif mv == "k" then
		move.up(num)
		return true
	elseif mv == "l" then
		move.right(num)
		return true
	end

	-- Move in Line
	if mv == "0" then
		move.to_start()
		return true
	elseif mv == "$" then
		move.to_end()
		return true
	elseif mv == "^" then
		move.to_non_blank()
		return true
	elseif mv == "|" then
		move.to_column(num)
		return true
	end

	-- Move by Word / Move by Loose Word
	if mv == "w" then
		move.by_word(num)
		return true
	elseif mv == "b" then
		move.backward_by_word(num)
		return true
	elseif mv == "e" then
		move.to_end_of_word(num)
		return true
	elseif mv == "W" then
		move.by_loose_word(num)
		return true
	elseif mv == "B" then
		move.backward_by_loose_word(num)
		return true
	elseif mv == "E" then
		move.to_end_of_loose_word(num)
		return true
	end

	-- Move by Line
	if mv == "\n" or mv == "+" then
		move.to_non_blank_of_next_line(num)
		return true
	elseif mv == "-" then
		move.to_non_blank_of_prev_line(num)
		return true
	elseif mv == "G" then
		if no_num then
			move.to_last_line()
		else
			move.to_line(num)
		end
		return true
	end

	-- Move by Block
	if mv == ")" then
		move.by_sentence(num)
		return true
	elseif mv == "(" then
		move.backward_by_sentence(num)
		return true
	elseif mv == "}" then
		move.by_paragraph(num)
		return true
	elseif mv == "{" then
		move.backward_by_paragraph(num)
		return true
	elseif mv == "]]" then
		move.by_section(num)
		return true
	elseif mv == "[[" then
		move.backward_by_section(num)
		return true
	end

	-- Move in View
	if no_num and mv == "H" then
		move.to_top_of_view()
		return true
	elseif mv == "M" then
		move.to_middle_of_view()
		return true
	elseif no_num and mv == "L" then
		move.to_bottom_of_view()
		return true
	elseif mv == "H" then
		move.to_below_top_of_view(num)
		return true
	elseif mv == "L" then
		move.to_above_bottom_of_view(num)
		return true
	end

	return false
end

local function run_mark(op, mv, letter)
	-- Set Mark / Move to Mark
	if op == "m" and letter then
		mark.set(letter)
		return true
	elseif mv == "`" and letter then
		if letter == "`" then
			mark.back()
		else
			mark.move_to(letter)
		end
		return true
	elseif mv == "'" and letter then
		if letter == "'" then
			mark.back_to_line()
		else
			mark.move_to_line(letter)
		end
		return true
	end

	return false
end

local function run_view(op, mv)
	-- Reposition
	if op == "z" and mv == "\n" then
		view.to_top()
		return true
	elseif op == "z." then
		view.to_middle()
		return true
	elseif op == "z" and mv == "-" then
		view.to_bottom()
		return true
	end

	return false
end

local function run_search(mv, num)
	if mv == "/\n" then -- not works
		search.repeat_forward()
		return true
	elseif mv == "?\n" then -- not works
		search.repeat_backward()
		return true
	elseif mv == "/" then
		search.forward()
		return true
	elseif mv == "?" then
		search.backward()
		return true
	elseif mv == "n" then
		search.next_match(num)
		return true
	elseif mv == "N" then
		search.prev_match(num)
		return true
	end

	return false
end

local function run_find(mv, num, letter)
	if mv == "f" and letter then
		find.forward(num, letter)
		return true
	elseif mv == "F" and letter then
		find.backward(num, letter)
		return true
	elseif mv == "t" and letter then
		find.before_forward(num, letter)
		return true
	elseif mv == "T" and letter then
		find.before_backward(num, letter)
		return true
	elseif mv == ";" then
		find.next_match(num)
		return true
	elseif mv == "," then
		find.prev_match(num)
		return true
	end

	return false
end

local function run_insert(num, op, replay)
	-- Enter Insert Mode
	if op == "i" then
		insert.before(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "a" then
		insert.after(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "I" then
		insert.before_non_blank(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "A" then
		insert.after_end(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "R" then
		insert.overwrite(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	end

	-- Open Line
	if op == "o" then
		insert.open_below(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "O" then
		insert.open_above(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	end

	return false
end

local function run_operator(num, op, replay)
	-- Copy (Yank)
	if op == "yw" then
		operator.copy_word(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "yy" or op == "Y" then
		operator.copy_line(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "yy" and false then -- TODO reg
		operator.copy_line_into_reg(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	end

	-- Paste (Put)
	if op == "p" then
		operator.paste(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "P" then
		operator.paste_before(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	end

	-- Delete
	if op == "x" then
		operator.delete(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "X" then
		operator.delete_before(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "dd" then
		operator.delete_line(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "D" then
		operator.delete_to_end()
		cache_command(false, 1, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	end

	-- Change / Substitute
	if op == "cc" then
		operator.change_line(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "C" then
		operator.change_to_end(replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "s" then
		operator.subst(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "S" then
		operator.subst_line(num, replay)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	end

	return false
end

local function run_edit(num, op, letter)
	if op == "r" then
		edit.replace(letter)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "J" then
		edit.join(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == ">>" then
		edit.indent(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	elseif op == "<<" then
		edit.outdent(num)
		cache_command(false, num, op, true, 1, "", nil, nil)
		undo_mode = true
		return true
	end

	return false
end

local function run_misc(num, op, replay)
	if op == "." then
		repeat_command(num)
		return true
	elseif op == "u" then
		cache_command(false, num, op, true, 1, "", nil)
		undo(num, replay)
		return true
	elseif op == "U" then
		misc.restore()
		return true
	elseif op == "ZZ" then
		misc.save_and_quit()
		return true
	end

	return false
end

local function get_region(num, no_subnum, subnum, mv, letter, save)
	local cursor = micro.CurPane().Buf:GetActiveCursor()
	local saved_x, saved_y
	if save ~= nil and save then
		saved_x, saved_y = cursor.X, cursor.Y
	end

	local start_loc = buffer.Loc(cursor.X, cursor.Y)

	for _ = 1, num do
		if not run_move(no_subnum, subnum, mv) and not run_mark("", mv, letter) then
			bell.fatal("unknown motion: " .. mv)
			break
		end
	end

	local end_loc = buffer.Loc(cursor.X, cursor.Y)

	if save ~= nil and save then
		cursor.X, cursor.Y = saved_x, saved_y
	end
	return start_loc, end_loc
end

local function run_compound_operator(num, op, no_subnum, subnum, mv, letter, replay)
	local matched = false

	if op == "y" and mv == "$" then
		operator.copy_to_end()
		matched = true
	elseif op == "d" and mv == "$" then
		operator.delete_to_end()
		matched = true
	elseif op == "c" and mv == "$" then
		operator.change_to_end(replay)
		matched = true
	elseif op == "y" and mv == "w" then
		operator.copy_word(num)
		matched = true
	elseif op == "d" and mv == "w" then
		operator.delete_word(num)
		matched = true
	elseif op == "c" and mv == "w" then
		operator.change_word(num, replay)
		matched = true
	elseif op == "y" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(num, no_subnum, subnum, mv, letter)
		operator.copy_region(start_loc, end_loc)
		matched = true
	elseif op == "d" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(num, no_subnum, subnum, mv, letter)
		operator.delete_region(start_loc, end_loc)
		matched = true
	elseif op == "c" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(num, no_subnum, subnum, mv, letter)
		operator.change_region(start_loc, end_loc, replay)
		matched = true
	elseif op == "y" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(num, no_subnum, subnum, mv, letter)
		operator.copy_line_region(start_loc.Y, end_loc.Y)
		matched = true
	elseif op == "d" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(num, no_subnum, subnum, mv, letter)
		operator.delete_line_region(start_loc.Y, end_loc.Y)
		matched = true
	elseif op == "c" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(num, no_subnum, subnum, mv, letter)
		operator.change_line_region(start_loc.Y, end_loc.Y, replay)
		matched = true
	end

	if matched then
		cache_command(false, num, op, no_subnum, subnum, mv, letter)
		undo_mode = true
		return true
	end

	return false
end

local function run_compound_edit(num, op, no_subnum, subnum, mv, letter)
	local matched = false

	if op == ">" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(1, no_subnum, subnum, mv, letter, true)
		edit.indent_region(start_loc, end_loc, 1)
		matched = true
	elseif op == "<" and (mv:match("[hl0wbnN]+") or mv == "`" and letter) then
		local start_loc, end_loc = get_region(1, no_subnum, subnum, mv, letter, true)
		edit.outdent_region(start_loc, end_loc, 1)
		matched = true
	elseif op == ">" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(1, no_subnum, subnum, mv, letter, true)
		edit.indent_region(start_loc, end_loc, num)
		matched = true
	elseif op == "<" and (mv:match("[jk\nG]+") or mv == "'" and letter) then
		local start_loc, end_loc = get_region(1, no_subnum, subnum, mv, letter, true)
		edit.outdent_region(start_loc, end_loc, num)
		matched = true
	end

	if matched then
		cache_command(false, num, op, no_subnum, subnum, mv, letter)
		undo_mode = true
		return true
	end

	return false
end

-- Note: Declared as local far above.
function run(no_num, num, op, no_subnum, subnum, mv, letter, replay)
	if op == ":" then
		mode.prompt()
		prompt.show()
		return true
	elseif run_compound_edit(num, op, no_subnum, subnum, mv, letter) then
		return true
	elseif run_compound_operator(num, op, no_subnum, subnum, mv, letter, replay) then
		return true
	elseif run_move(no_num, num, mv) then
		return true
	elseif run_view(op, mv) then
		return true
	elseif run_mark(op, mv, letter) then
		return true
	elseif run_search(mv, num) then
		return true
	elseif run_find(mv, num, letter) then
		return true
	elseif run_insert(num, op, replay) then
		return true
	elseif run_operator(num, op, replay) then
		return true
	elseif run_edit(num, op, letter) then
		return true
	elseif run_misc(num, op, replay) then
		return true
	elseif mv == "g" then
		move.by_word_for_change(num) -- XXX debug
		return true
	end

	return false
end

-------------
-- Exports --
-------------

local M = {}

M.run = run

return M
