--Variables
local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)

--Settings
pickp = {}
local modpath = minetest.get_modpath(modname)
assert(loadfile(modpath.. "/settings.lua"))(modpath)

local _contexts = {}

local function deepCopy(original)
	local copy = {}
	for k, v in pairs(original) do
		if type(v) == "table" then
			v = deepCopy(v)
		end
		copy[k] = v
	end
	return copy
end

local function enable_steal(clicker, clicked, rob_table)
	local steal_table = {}
	steal_table["clicked"] = clicked:get_player_name()
	steal_table["items"] = deepCopy(rob_table)
	_contexts[clicker:get_player_name()] = steal_table
end

local function disable_stealth(player, close_form, msg)
	local player_name = player:get_player_name()
	_contexts[player_name] = nil
	if msg then
		minetest.chat_send_player(player_name, S(msg))
	end
	if close_form then
		minetest.close_formspec(player_name,	"pickp:form")
	end
end

local function is_stealing(player) --it returns the rob table of items too
	if _contexts[player:get_player_name()] then
		return true
	else
		return false
	end
end

local function get_steal_table(player)
	return _contexts[player:get_player_name()] or nil
end

minetest.register_on_leaveplayer(function(player)
	disable_stealth(player, false, false)
end)

minetest.register_on_punchplayer(function(player, hitter, time_from_last_punch, tool_capabilities, dir, damage)
	if is_stealing(player) then
		disable_stealth(player, true, "Aborted robbery!")
	end
end)

local function get_rob_list(clicked)
	local inv = clicked:get_inventory()
	local list_inv = inv:get_list("main")
	local list_hotbar = {}
	for i=1,pickp.settings["hotbar_size"] do
		if list_inv[i]:get_count() > 0 then
			if math.random(0,1) < pickp.settings["hotbar_ratio"] then
				table.insert(list_hotbar, {itemstack = list_inv[i], type = "hotbar"})
			end
		end
	end
	local list_main = {}
	for i=pickp.settings["hotbar_size"]+1,#list_inv do
		if list_inv[i]:get_count() > 0 then
			if math.random(0,1) < pickp.settings["main_ratio"] then
				table.insert(list_main, {itemstack = list_inv[i], type = "main"})
			end
		end
	end
	local rob_list = ""
	if #list_hotbar == 0 and #list_main == 0 then
		return rob_list, nil
	end
	--minetest.chat_send_all("hotbar_before="..tostring(#list_hotbar))
	--minetest.chat_send_all("main="..tostring(#list_main))
	--merge the tables
	if #list_main > 0 then
		local j = 1
		for i = 1, #list_main do
			list_hotbar[#list_hotbar+j] = list_main[i]
			j = j + 1
		end
	end
	--minetest.chat_send_all("hotbar_after="..tostring(#list_hotbar))
	local i = 0
	local item_stack, item_name
	for y= 0, 3 do
		if i > #list_hotbar then
			break
		end
		for x= 0,3 do
			i = i + 1
			if i > #list_hotbar then
				break
			end
			item_stack = list_hotbar[i].itemstack
			item_name = item_stack:get_name()
			rob_list = rob_list .. " item_image_button [".. tostring(x)..",".. tostring(y) ..";1,1;"
				.. item_name .. ";item_name;"..tostring(i).."]"
		end
	end
	minetest.chat_send_all("rob_list="..rob_list)
	return rob_list, list_hotbar
end

local function get_formspec(clicker, clicked, rob_list)
	local formspec =
		"size[4,4]" ..
		rob_list
	return formspec
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "pickp:form" then
		return
	end
	minetest.chat_send_all("TEST")
	if not player then
		return
	end
	if not(fields.item_name) then
		return
	end
	local steal_table = get_steal_table(player)
	local steal_itemstack = steal_table.items[tonumber(fields.item_name)].itemstack
	local clicked = minetest.get_player_by_name(steal_table.clicked)
	local inv_clicker = player:get_inventory()
	local inv_clicked = clicked:get_inventory()
	--Search the item to rob in the clicked player
	if inv_clicked:contains_item("main", steal_itemstack) then
		local steal_itemstack_name = steal_itemstack:get_name()
		local steal_amount = math.random(1, steal_itemstack:get_count())
		local final_steal_itemstack = steal_itemstack_name .. " " .. tostring(steal_amount)
		inv_clicked:remove_item("main", final_steal_itemstack)
		inv_clicker:add_item("main", final_steal_itemstack)
		disable_stealth(player, true, false)
	else
		disable_stealth(player, true, "The player has moved his items!")
	end
	return true
end)

local function check_distance(clicker, clicked)
	local pos1 = clicker:get_pos()
	local pos2 = clicked:get_pos()
	local distance = vector.distance(pos1, pos2)
	if distance > pickp.settings["stealing_distance"] then
		return false
	else
		return true
	end
end

local function stealth(clicker, clicked)
	local clicker_name = clicker:get_player_name()
	local clicked_name = clicked:get_player_name()
	if not(clicker_name) or not(clicked_name) or not(is_stealing(clicker)) then
		return
	end
	--1) CHECK THE DISTANCE
	if not(check_distance(clicker, clicked)) then
		disable_stealth(clicker, true, "Failed Robbery!")
		return
	end
	--2) CHECK THE ANGLE
	local clicker_look_view = clicker:get_look_dir()
	local x1 = clicker_look_view.x
	local z1 = clicker_look_view.z
	local clicked_look_view = clicked:get_look_dir()
	local x2 = clicked_look_view.x
	local z2 = clicked_look_view.z
	local angle_2d = math.deg(math.acos((x1 * x2 + z1 * z2) / (math.sqrt(x1^2 + z1^2) * math.sqrt(x2^2 + z2^2))))
	--minetest.chat_send_all(tostring(angle_2d))
	local stealth_ratio
	--Detect the zone -->
	if angle_2d <= pickp.settings["zone_1_2_limit"] then
		stealth_ratio = pickp.settings["zone1_stealth_ratio"]
	elseif angle_2d > pickp.settings["zone_1_2_limit"] and angle_2d < pickp.settings["zone_2_3_limit"] then
		stealth_ratio = pickp.settings["zone2_stealth_ratio"]
	else
		stealth_ratio = pickp.settings["zone3_stealth_ratio"]
	end
	if math.random(0,1) >= stealth_ratio then --NOT detected
		minetest.after(pickp.settings["stealth_timing"], stealth, clicker, clicked)
		return
	end
	--DETECTED!
	disable_stealth(clicker, true, "Failed Robbery!")
end

local function pickpocketing(clicker, clicked)
	local clicker_name = clicker:get_player_name()
	local rob_list, rob_table = get_rob_list(clicked)
	if not(rob_list == "") then
		minetest.show_formspec(clicker_name,
			"pickp:form", get_formspec(clicker, clicked, rob_list))
		enable_steal(clicker, clicked, rob_table) --mark as stealing
		minetest.after(pickp.settings["stealth_timing"], stealth, clicker, clicked)
	else
		minetest.chat_send_player(clicker_name, S("Failed robbery!"))
	end
end

p2p.register_on_right_clickplayer(function(clicker, clicked)
	local controls = clicker:get_player_control()
	if controls.sneak and not(is_stealing(clicker)) then
		if not(check_distance(clicker, clicked)) then
			minetest.chat_send_player(clicker:get_player_name(), S("Too far to steal!"))
			return
		end
		pickpocketing(clicker, clicked)
	end
end)
