require("data")

local sprite_index = 0
local map_enabled = false
local world = 1
local dark_room = 0
local menuselect = { 1, 1 }
local colselect = 1
local dpad_counter = 0
local dpad_pressed = 0
local customtravel = false

local rooms = { item_rooms_data_lw, item_rooms_data_dw }
local overworld = { item_ow_data_01_lw, item_ow_data_01_dw }
local specialitems = { specialitems_lw, specialitems_dw }
local worldnames = { "Light World", "Dark World" }

function testbit(v, b)
	local mask = 1 << b
	return (v & mask) == mask
end

function draw_sprite(x, y, d, attr, text)
	local i = sprite_index
	if text then
		if d == 0 then
			w8(const.SPRITE_BASE + 1 + i, 0xf0)
		else
			w8(const.SPRITE_BASE + i + 0, x)
			w8(const.SPRITE_BASE + i + 1, y)
			w8(const.SPRITE_BASE + i + 2, digits[d < 9 and d + 1 or d // 10 + 1])
			w8(const.SPRITE_BASE + i + 3, 0x38)
			sprite_index = sprite_index + 4
			if d > 9 then
				w8(const.SPRITE_BASE + 4 + i + 0, x + 6)
				w8(const.SPRITE_BASE + 4 + i + 1, y)
				w8(const.SPRITE_BASE + 4 + i + 2, digits[d % 10 + 1])
				w8(const.SPRITE_BASE + 4 + i + 3, attr)
				sprite_index = sprite_index + 4
			end
		end
	else
		w8(const.SPRITE_BASE + i + 0, x)
		w8(const.SPRITE_BASE + i + 1, y)
		w8(const.SPRITE_BASE + i + 2, d)
		w8(const.SPRITE_BASE + i + 3, attr)
		sprite_index = sprite_index + 4
	end
end

function log(s)
	emu.log(string.format("%x", s))
end

function getworld()
	if u8(0x7ef3ca) & 0x40 == 0 then return 1 else return 2 end
end

function copy_sprite0()
	w16(0x2116, 0x4830)
	for i = 1, #spritenumber0graphic, 2 do
		w8(0x2118, spritenumber0graphic[i])
		w8(0x2119, spritenumber0graphic[i + 1])
	end
end

function drawitemrooms(w)
	local c, b
	for k, v in ipairs(rooms[w]) do
		c = v.total[1]
		for i = 1, #v.id do
			b = u16(0x7ef000 + v.id[i])
			b = (b & 0xff0) >> 4
			if testbit(b, v.bits[i]) then c = c - 1 end
		end
		draw_sprite(v.xy[1] // 255, v.xy[1] & 255, c, 0x38, true)
	end
end

function drawitemsoverworld(w)
	local b, c = 0, 0
	for k, v in ipairs(overworld[w]) do
		for i = 1, #v.id do
			b = u16(0x7ef000 + v.id[i])
			b = (b & 0xff0) >> 4
			c = 1
			if testbit(b, 2) then c = 0 end
			draw_sprite(v.xy[1] // 255, v.xy[1] & 255, c, 0x38, true)
		end
	end
end

function drawspecialitems(w)
	for i, v in ipairs(specialitems[w]) do
		for n, t in ipairs(v.bits) do
			b = u8(0x7ef000 + v.id[1])
			c = 1
			if testbit(b, t) then c = 0 end
			draw_sprite(v.xy[1] // 255, v.xy[1] & 255, c, 0x38, true)
		end
	end
end

function main()
	if u8(const.SUB_TASK) == 7 and u8(const.NMI_FLAG) > 0 and u8(const.ZOOM_MODE) == 0 then
		if world == 1 or world == 2 then
			sprite_index = 0
			copy_sprite0()
			drawitemrooms(world)
			drawitemsoverworld(world)
			drawspecialitems(world)
		end
	end
end

function mapinput()
	if u8(const.PAD_OLD_F4) == const.RIGHT or u8(const.PAD_OLD_F4) == const.LEFT then
		world = world ~ 3
		w16(const.MAIN_TASK, 0x070e)
		w8(0x200, 0x01)
		w8(0x94, 0x07)
		w8(0x13, 0x80)
		for i = 0, 111 do
			w8(const.SPRITE_BASE + i * 4 + 1, 0xf0)
		end
	end
end

--function () end,
local action =
{
	[1] = function() main() end,                             --main
	[2] = function() setregister(regs[curremu]["a"], 0x0a) end, --map zoom out
	[3] = function()                                         --disable zoom toggle
		local screen = u8(0x8a)
		if screen == 0x00 or screen == 0x81 then return end
		setregister(regs[curremu]["a"], 0x00)
	end,
	[4] = function() --disable overworld map frame counter
		if u8(const.SUB_TASK) == 7 and u8(const.NMI_FLAG) > 0 and u8(const.ZOOM_MODE) == 0 then
			w8(0x1a, 0xff)
			setregister(regs[curremu]["pc"], 0x8056)
		end
	end,
	[5] = function() --set sprites to 8x8
		if u16(const.MAIN_TASK) == 0x030e or u16(const.MAIN_TASK) == 0x070e then
			for i = 0, 0x1a do
				w8(const.OAM_ATTR + i, 0x00)
			end
		end
	end,
	[6] = function() --open overworld map indoors
		if u8(const.PAD_NEW_F2) & 0x20 == 0 then return end
		w8(0x10c, u8(const.MAIN_TASK))
		w16(const.MAIN_TASK, 0x070e)
		w8(0x9c, 0x20)
		w8(0x9d, 0x40)
		w8(0x9e, 0x80)
		dark_room = u8(0x458)
		w8(0x458, 0x00)
		w8(0x7ec20e, u8(0xaa1))
		w8(0x7ec20f, u8(0xaa3))
		w8(0x7ec210, u8(0xaa2))
		--save palette
		for x = 0, 0x7e, 2 do
			w16(0x7fdd80 + x, u16(0x7ec500 + x))
			w16(0x7fde00 + x, u16(0x7ec580 + x))
			w16(0x7fde80 + x, u16(0x7ec600 + x))
			w16(0x7fdf00 + x, u16(0x7ec680 + x))
		end

		setregister(regs[curremu]["pc"], 0x82881c)
		world = getworld()
		map_enabled = true
	end,
	[7] = function() -- close overworld map indoors
		if u8(const.INDOORS) == 1 then
			w16(const.MAIN_TASK, 0x030e)
			w8(0x13, 0x01)
			w8(0x200, 0x05)
			world = getworld()
		end
	end,
	[8] = function() -- close overworld map
		--w8(0x8a, u8(0x8a) & 0x3f | u8(0x7ef3ca))
		w8(0x8a, u8(0x700ef0))
	end,
	[9] = function() -- close dungeon map
		if u8(const.INDOORS) == 1 and map_enabled then
			w16(const.MAIN_TASK, 0x030e)
			w8(0x458, dark_room)
			map_enabled = false
			w8(0x8a, u8(0x8a) & 0x3f | u8(0x7ef3ca))
		end
	end,
	[10] = function() -- open overworld map outside
		world = getworld()
		w8(0x700ef0, u8(0x8a))
	end,
	[11] = function() --set world
		local a = getregister(regs[curremu]["a"])
		setregister(regs[curremu]["a"], a & 0x3f | u8(0x7ef3ca))
	end,
	[12] = function() -- change world
		if world == 2 then
			w8(0x8a, u8(0x8a) | 0x40)
			setregister(regs[curremu]["y"], 0x1fe)
		else
			w8(0x8a, u8(0x8a) & 0x3f)
		end
		setregister(regs[curremu]["pc"], 0x8aba76)
	end,
	[13] = function() --link's position
		local x = getregister(regs[curremu]["x"])
		if u8(const.INDOORS) == 1 and x == 7 then
			local room = u16(0xa0)
			if room == 0x104 then
				for i = 0, 0x9e, 2 do
					if u16(0x82daee + i) == room then
						local sx = u16(0x82ddb5 + i)
						local sy = u16(0x82de53 + i)
						w16(0x7ec108, sx)
						w16(0x7ec10a, sy)
						break
					end
				end
			else
				w16(0x7ec108, u16(0x7ec148))
				w16(0x7ec10a, u16(0x7ec14a))
			end
		end
	end,
	[14] = function() --link's position
		if u8(const.SUB_TASK) == 0x07 then
			setregister(regs[curremu]["pc"], 0xf81b)
		end
	end,
	[15] = function() --draw link low priority
		if u16(const.MAIN_TASK) == 0x070e and u8(const.NMI_FLAG) > 0 and u8(const.ZOOM_MODE) == 0 then
			w8(0x9fc, u8(0x0e) - 4)
			w8(0x9fd, u8(0x0f) - 3)
			w8(0x9fe, 0x00)
			w8(0x9ff, 0x3e)
			w8(0xa9f, 0x02)
			setregister(regs[curremu]["pc"], 0x8abfa2)
		end
	end,
	[16] = function() -- set travel location
		--local retaddr = u16(getregister(regs[curremu]["sp"]) + 2)
		--if retaddr == 0xb3c0 then return end
		if customtravel then
			local pos = travelpos[colselect][menuselect[colselect]][2]
			w16(0x00e6, pos[1])
			w16(0x00e8, pos[1])
			w16(0x0122, pos[1])
			w16(0x0124, pos[1])
			w16(0x00e0, pos[2])
			w16(0x00e2, pos[2])
			w16(0x011e, pos[2])
			w16(0x0120, pos[2])
			w16(0x0020, pos[3])
			w16(0x0022, pos[4])
			w16(0x0624, pos[5])
			w16(0x626, 0 - u16(0x624) & 0xffff)
			w16(0x0628, pos[6])
			w16(0x62a, 0 - u16(0x628) & 0xffff)
			w16(0x008a, pos[7])
			w16(0x040a, pos[7])
			w16(0x0084, pos[8])
			local a = ((pos[8] - 0x400) & 0xf80) * 2
			w16(0x0088, (a >> 8 | a << 8) & 0xffff)
			a = ((pos[8] - 0x10) & 0x3e) // 2
			w16(0x0086, a)
			w16(0x0618, pos[9])
			w16(0x61a, u16(0x618) - 2 & 0xffff)
			w16(0x061c, pos[10])
			w16(0x61e, u16(0x61c) - 2 & 0xffff)
			w8(0x7ef3ca, u8(0x7ef3ca) & 0x3f | u8(0x8a) & 0x40)
			customtravel = false
		end
	end,
	[17] = function() --update
		local room = u16(0xa0)
		local screen = u16(0x8a)

		local dx = u8(0x40c)
		if dx ~= 0xff and u16(const.MAIN_TASK) == 0x030e then
			sprite_index = 0x100
			for i, v in ipairs(itemsxy[dx / 2 + 1]) do
				local b = (u16(0x7ef000 + v[5]) & 0xff0) >> 4
				local low = v[3] + v[4] & 0xffff == u16(0xfaa)
				w8(0xa70 + (i - 1), 0x00)
				if (v[3] == u16(0xfaa) or low) and not testbit(b, v[6]) then
					draw_sprite(v[1], (v[2] + (low and v[4] or 0)) & 0xff, 0x32, 0x39, false)
				end
			end
		end

		--show world map indoors
		if u16(const.MAIN_TASK) == 0x070e then
			mapinput()
			if u8(const.INDOORS) == 1 then
				main()
			end
		end

		--if screen ~= 0x82 then
		--travel menu
		if u8(const.INDOORS) == 0 and u8(const.SUB_TASK) == 0 or u8(const.SUB_TASK) == 6 then
			--activate bird travel
			if u8(const.PAD_NEW_F2) & 0x20 > 0 and u8(const.PAD_OLD_F6) & 0x10 > 0 then
				if u8(const.MAIN_TASK) ~= 0x0e then
					w16(const.MAIN_TASK, 0x000e)
					w8(0xfc1, 0x01)
				else
					w8(const.MAIN_TASK, 0x09)
					w8(0xfc1, 0x00)
				end
			end
		end
		--end

		local xsize = curremu == const.BIZHAWK and 48 or 41
		local ysize = curremu == const.BIZHAWK and 11 or 10
		local c = colselect

		if u16(const.MAIN_TASK) == 0x000e then
			local x, y, col, row = 5, 2, 0, 0
			drawrect(x, y, 256 - x * 2, y + 15, curremu == const.BIZHAWK and 0xff000000 or 0x000000, true)
			local fgcolor = curremu == const.BIZHAWK and 0x0080ff | 0xff000000 or 0x0080ff
			local ty = curremu == const.BIZHAWK and y + 2 or y + 6
			drawtext(x + col + 5, ty, worldnames[c], "%s", fgcolor, 0x000000)
			col = col + 128

			local height = curremu == const.BIZHAWK and 208 or 216

			col, row = 0, 10
			--drawline(x, y + row + 6, 256 - x - 1, y + row + 6, 0xffffff)
			drawrect(x, y + 15, 256 - x * 2, height - y, curremu == const.BIZHAWK and 0x9f000000 or 0x4f000000, true)
			for i, s in ipairs(travelpos[c]) do
				local selected = c == colselect and menuselect[c] == i and 0x1000 or 0
				if selected > 0 then
					fgcolor = curremu == const.BIZHAWK and 0x00ff00 | 0xff000000 or 0x00ff00
					bgcolor = curremu == const.BIZHAWK and 0x000000 or 0xff000000
					drawtext(x + col + 5, y + row + 8, s[1], "%s", fgcolor, bgcolor)
				else
					drawtext(x + col + 5, y + row + 8, s[1], "%s", nil, bgcolor)
				end
				row = row + 10
				if i == (curremu == const.BIZHAWK and 20 or 21) then
					col, row = 128, 10
				end
			end

			if u8(const.PAD_NEW_F0) & const.DOWN > 0 or u8(const.PAD_NEW_F0) & const.UP > 0 then
				dpad_counter = dpad_counter - 1
				dpad_pressed = u8(const.PAD_NEW_F0)
				if dpad_counter < 0 then
					dpad_counter = 3
				end
			else
				dpad_counter = const.DELAY
			end

			if u8(const.PAD_OLD_F4) & const.DOWN > 0 or dpad_pressed == const.DOWN and dpad_counter == 0 then
				menuselect[c] = menuselect[c] + 1
				if menuselect[c] > #travelpos[c] then menuselect[c] = 1 end
			elseif u8(const.PAD_OLD_F4) & const.UP > 0 or dpad_pressed == const.UP and dpad_counter == 0 then
				menuselect[c] = menuselect[c] - 1
				if menuselect[c] < 1 then menuselect[c] = #travelpos[c] end
			elseif u8(const.PAD_OLD_F4) & const.RIGHT > 0 or u8(const.PAD_OLD_F4) & const.LEFT > 0 then
				colselect = colselect ~ 3
			elseif u8(const.PAD_OLD_F4) & const.B > 0 then
				w16(const.MAIN_TASK, 0x0a0e)
				w8(0x200, 0x06)
				customtravel = true
			end
		end

		local yr = curremu == const.BIZHAWK and 0 or 8
		local xi = 256 - 47
		local yi = 9
		drawrect(xi, yr, xsize, ysize, curremu == const.BIZHAWK and 0x7f000000 or 0x7f000000, true)
		drawtext(xi, yi, u8(0x7ef423), "%3d/216", curremu == const.BIZHAWK and 0x00ff00 | 0xff000000 or 0x00ff00,
			curremu == const.BIZHAWK and 0x000000 or 0xff000000)

		if curremu == const.MESEN then
			drawtext(100, 0, room * 2, "Room:%X")
			drawtext(190, 0, screen + 0x280, "Screen:%X")

			if u8(const.PAD_NEW_F2) & const.L > 0 and u8(const.PAD_OLD_F4) & const.Y > 0 then
				emu.log(string.format(
					"{ 0x%04x, 0x%04x, 0x%04x, 0x%04x, 0x%04x, 0x%04x, 0x%04x, 0x%04x, 0x%04x, 0x%04x },",
					u16(0xe6), u16(0xe0), u16(0x20), u16(0x22), u16(0x624) & 0xffff, u16(0x628) & 0xffff,
					u8(0x8a), u16(0x84), u16(0x618), u16(0x61c)))
			end
		end

		--enable compass/dungeon maps
		--w16(0x7ef364, 0xffff)
		--w16(0x7ef368, 0xffff)
	end
}

if curremu == const.GMULATOR or curremu == const.MESEN then
	addmemcallback(action[1], callbackexec, 0x8abf86) --main
	addmemcallback(action[2], callbackexec, 0x8abcfa) --map zoom out
	addmemcallback(action[3], callbackexec, 0x8abb34) --disable zoom toggle
	addmemcallback(action[4], callbackexec, 0x808053) --disable overworld map frame counter
	addmemcallback(action[5], callbackexec, 0x80805d) --set sprites to 8x8
	addmemcallback(action[6], callbackexec, 0x828801) --open overworld map indoors
	addmemcallback(action[7], callbackexec, 0x8abc8f) -- close overworld map indoors
	addmemcallback(action[8], callbackexec, 0x8abca7) -- close overworld map
	addmemcallback(action[9], callbackexec, 0x8aefd8) -- close dungeon map
	addmemcallback(action[10], callbackexec, 0x82a465) -- open overworld map outside	
	addmemcallback(action[11], callbackexec, 0x82e9f2) --set world
	addmemcallback(action[12], callbackexec, 0x8aba6c) -- change world
	addmemcallback(action[13], callbackexec, 0x8ac3b8) --link's position
	addmemcallback(action[14], callbackexec, 0x80f806) --link's position
	addmemcallback(action[15], callbackexec, 0x8abf9d) --draw link low priority
	addmemcallback(action[16], callbackexec, 0x82ea2f) -- set travel location
	addeventcallback(action[17], callbackframe)     --update	

	if curremu == const.MESEN then
		emu.displayMessage("Script", "Menu")
	end
elseif curremu == const.BIZHAWK then
	addmemcallback(action[1], 0x8abf86) --main
	addmemcallback(action[2], 0x8abcfa) --map zoom out
	addmemcallback(action[3], 0x8abb34) --disable zoom toggle
	addmemcallback(action[4], 0x808053) --disable overworld map frame counter
	addmemcallback(action[5], 0x80805d) --set sprites to 8x8
	addmemcallback(action[6], 0x828801) --open overworld map indoors
	addmemcallback(action[7], 0x8abc8f) -- close overworld map indoors
	addmemcallback(action[8], 0x8abca7) -- close overworld map
	addmemcallback(action[9], 0x8aefd8) -- close dungeon map
	addmemcallback(action[10], 0x82a465) -- open overworld map outside	
	addmemcallback(action[11], 0x82e9f2) --set world
	addmemcallback(action[12], 0x8aba6c) -- change world
	addmemcallback(action[13], 0x8ac3b8) --link's position
	addmemcallback(action[14], 0x80f806) --link's position
	addmemcallback(action[15], 0x8abf9d) --draw link low priority
	addmemcallback(action[16], 0x82ea2f) -- set travel location
	addeventcallback(action[17])      --update

	while true do
		if u16(const.MAIN_TASK) == 0x030e or u16(const.MAIN_TASK) == 0x070e then
			for i = 0, 0x1a do
				w8(const.OAM_ATTR + i, 0x00)
			end
		end

		emu.frameadvance()
	end
end
