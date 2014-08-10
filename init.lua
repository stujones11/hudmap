hudmap = {
	id = {},
	map = {},
	pref = {},
}

HUDMAP_UPDATE_TIME = 2
HUDMAP_MARKER_SIZE = {x=15, y=15}
HUDMAP_DEFAULT_TEXTURE = "hudmap_default.png"
HUDMAP_DEFAULT_PREFS = {visible=true, scale=1}

function hudmap:register_map(name, def)
	local scale_size = {
		x = def.maxp.x - def.minp.x,
		z = def.maxp.z - def.minp.z,
	}
	local map = {
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
	}
	table.insert(hudmap.map, map)
	table.sort(hudmap.map, function(a, b) return a.area < b.area end)
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

local function get_map_texture(player)
	local texture = HUDMAP_DEFAULT_TEXTURE
	local pos = player:getpos()
	if pos then
		local map = nil
		for _, v in ipairs(hudmap.map) do
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
			x = x / map.scale.x - marker_offset.x
			y = map.size.y - y / map.scale.y - marker_offset.y
			texture = "[combine:"..map.size.x.."x"..map.size.y..
				":0,0,="..map.texture..":"..x..","..y..",=hudmap_marker.png"
		end
	end
	return texture
end

local function update_hud(player)
	local name = player:get_player_name()
	if hudmap.id[name] then
		player:hud_change(hudmap.id[name], "text", get_map_texture(player))
	else
		local scale = hudmap.pref[name].scale
		hudmap.id[name] = player:hud_add({
			hud_elem_type = "image",
			position = {x=1,y=0},
			scale = {x=scale, y=scale},
			text = get_map_texture(player),
			offset = {x=0,y=0},
			alignment = {x=-1,y=1},
		})
	end
end

minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	hudmap.pref[name] = HUDMAP_DEFAULT_PREFS
	minetest.after(1, function(player)
		if player then
			if hudmap.pref[name].visible == true then
				update_hud(player)
			end
		end
	end, player)
end)

minetest.register_globalstep(function(dtime)
	timer = timer + dtime
	if timer > HUDMAP_UPDATE_TIME then
		for _,player in ipairs(minetest.get_connected_players()) do
			local name = player:get_player_name()
			if hudmap.pref[name].visible == true then
				update_hud(player)
			end
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
			player:hud_remove(hudmap.id[name])
			hudmap.id[name] = nil
		elseif cmd == "scale" then
			if args then
				scale = tonumber(args)
				if scale then
					if scale > 0 then
						hudmap.pref[name].scale = scale
						player:hud_remove(hudmap.id[name])
						hudmap.id[name] = nil
						update_hud(player)
						return
					end
				end
			end
			minetest.chat_send_player(name, "Invalid scale!")
		end
	end,
})

