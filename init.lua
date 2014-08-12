hudmap = {
	marker = {},
	map = {},
	pref = {},
	registered_maps = {},
}

HUDMAP_UPDATE_TIME = 1
HUDMAP_MARKER_SIZE = {x=15, y=15}
HUDMAP_DEFAULT_PREFS = {visible=true, scale=1}

function hudmap:register_map(name, def)
	local scale_size = {
		x = def.maxp.x - def.minp.x,
		z = def.maxp.z - def.minp.z,
	}
	table.insert(hudmap.registered_maps, {
		name = name,
		size = def.size,
		minp = def.minp,
		maxp = def.maxp,
		area = scale_size.x * scale_size.z,
		texture = def.texture,
		scale = {
			x = scale_size.x / def.size.x,
			y = scale_size.z / def.size.y,
		},
		marker_pos = {x=0, y=0},
	})
	table.sort(hudmap.registered_maps, function(a, b)
		return a.area < b.area
	end)
end

local modpath = minetest.get_modpath(minetest.get_current_modname())
local input = io.open(modpath.."/hudmap.conf", "r")
if input then
	dofile(modpath.."/hudmap.conf")
	input:close()
	input = nil
end
local timer = 0
local marker_offset = {
	x = math.ceil(HUDMAP_MARKER_SIZE.x / 2),
	y = math.ceil(HUDMAP_MARKER_SIZE.y / 2),
}

local function get_map(player)
	local name = player:get_player_name()
	local pos = player:getpos()
	if name and pos then
		local map = nil
		for _, v in ipairs(hudmap.registered_maps) do
			if pos.x >= v.minp.x and pos.x <= v.maxp.x and
					pos.y >= v.minp.y and pos.y <= v.maxp.y and
					pos.z >= v.minp.z and pos.z <= v.maxp.z then
				map = v
				break
			end
		end
		if map then
			local x = pos.x - map.minp.x
			local y = pos.z - map.minp.z
			x = map.size.x - x / map.scale.x - marker_offset.x
			y = map.size.y - y / map.scale.y - marker_offset.y
			map.marker_pos = {
				x = -x * hudmap.pref[name].scale,
				y = y * hudmap.pref[name].scale,
			}
			return map
		end
	end
end

local function remove_hud(player, name)
	player:hud_remove(hudmap.map[name])
	player:hud_remove(hudmap.marker[name])
	hudmap.map[name] = nil
	hudmap.marker[name] = nil
end

local function update_hud(player)
	local name = player:get_player_name()
	if hudmap.pref[name].visible == false then
		return
	end
	local map = get_map(player)
	if hudmap.map[name] then
		if map then
			player:hud_change(hudmap.map[name], "text", map.texture)
			player:hud_change(hudmap.marker[name], "offset", map.marker_pos)
		else
			remove_hud(player, name)
		end
	elseif map then
		local scale = hudmap.pref[name].scale
		hudmap.map[name] = player:hud_add({
			hud_elem_type = "image",
			position = {x=1,y=0},
			scale = {x=scale, y=scale},
			text = map.texture,
			offset = {x=0,y=0},
			alignment = {x=-1,y=1},
		})
		hudmap.marker[name] = player:hud_add({
			hud_elem_type = "image",
			position = {x=1,y=0},
			scale = {x=scale, y=scale},
			text = "hudmap_marker.png",
			offset = map.marker_pos,
			alignment = {x=-1,y=1},
		})
	end
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	hudmap.pref[name] = HUDMAP_DEFAULT_PREFS
	minetest.after(1, function(player)
		if player then
			update_hud(player)
		end
	end, player)
end)

minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer > HUDMAP_UPDATE_TIME then
		for _,player in ipairs(minetest.get_connected_players()) do
			update_hud(player)
		end
		timer = 0
	end
end)

minetest.register_chatcommand("hudmap", {
	params = "<cmd> [args]",
	description = "Hudmap",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if param == nil or player == nil then
			return
		end
		local cmd, args = string.match(param, "([^ ]+) (.+)")
		cmd = cmd or param
		if cmd == "on" then
			hudmap.pref[name].visible = true
			update_hud(player)
		elseif cmd == "off" then
			hudmap.pref[name].visible = false
			remove_hud(player, name)
		elseif cmd == "scale" then
			if args then
				scale = tonumber(args)
				if scale then
					if scale > 0 then
						hudmap.pref[name].scale = scale
						remove_hud(player, name)
						update_hud(player)
						return
					end
				end
			end
			minetest.chat_send_player(name, "Invalid scale!")
		end
	end,
})

