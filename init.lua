--Variables
local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)

--Settings
pickp = {}
local modpath = minetest.get_modpath(modname)
assert(loadfile(modpath.. "/settings.lua"))(modpath)

local _contexts = {}

--Aunction for copy a table in deep (children too)
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

function pickp.make_sound(dest_type, dest, soundfile, max_hear_distance)
	if dest_type == "object" then
		minetest.sound_play(soundfile, {object = dest, gain = 0.5, max_hear_distance = max_hear_distance or 10,})
	 elseif dest_type == "player" then
		local player_name = dest:get_player_name()
		minetest.sound_play(soundfile, {to_player = player_name, gain = 0.5, max_hear_distance = max_hear_distance or 10,})
	 elseif dest_type == "pos" then
		minetest.sound_play(soundfile, {pos = dest, gain = 0.5, max_hear_distance = 10 or max_hear_distance,})
	end
end

local function enable_steal(clicker, clicked, rob_table, angle_2d)
	local steal_table = {}
	steal_table["clicked"] = clicked:get_player_name()
	steal_table["angle_2d"] = angle_2d
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
	for i=1,pickp.settings["hotbar_size"],1 do
		if list_inv[i]:get_count() > 0 then
			if math.random(0,1) < pickp.settings["hotbar_ratio"] then
				list_hotbar[#list_hotbar+1] = {itemstack = list_inv[i], type = "hotbar"}
			end
		end
	end
	local list_main = {}
	for i=pickp.settings["hotbar_size"]+1,#list_inv,1 do
		if list_inv[i]:get_count() > 0 then
			if math.random(0,1) < pickp.settings["main_ratio"] then
				list_main[#list_main+1] = {itemstack = list_inv[i], type = "main"}
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
		for key,value in pairs(list_main) do
			table.insert(list_hotbar, value)
		end
	end
	--minetest.chat_send_all("hotbar_after="..tostring(#list_hotbar))
	local i = 1
	local item_stack, item_name, columns
	for y= 1, 4 do
		if i > #list_hotbar then
			break
		end
		columns = y
		for x= 0,3 do
			if list_hotbar[i] then
				item_stack = list_hotbar[i].itemstack
				item_name = item_stack:get_name()
				rob_list = rob_list .. " item_image_button [".. tostring(x)..".3"..",".. tostring(y)..".6"..";1,1;"
				.. item_name .. ";item_name;"..tostring(i).."]"
				i = i + 1
			else
				i = i + 1
			end
			if i > #list_hotbar then
				break
			end
		end
	end
	--minetest.chat_send_all("rob_list="..rob_list)
	return rob_list, list_hotbar, columns
end

local function get_formspec(clicker, clicked, rob_list,columns)
	columns = columns + 1
	local formspec =
		"formspec_version[4]" ..
		"size[4.6,"..tostring(columns)..".9]" ..
		"image[0.30,0.30;1,1;pickp_thief_face.png]" ..
		"label[1.5,0.65;"..S("Pick up an item").."]" ..
		"label[1.5,1;"..S("quickly!").."]" ..
		rob_list
	return formspec
end

local function get_angle(clicker, clicked)
	local clicker_look_view = clicker:get_look_dir()
	local x1 = clicker_look_view.x
	local z1 = clicker_look_view.z
	local clicked_look_view = clicked:get_look_dir()
	local x2 = clicked_look_view.x
	local z2 = clicked_look_view.z
	return math.deg(math.acos((x1 * x2 + z1 * z2) / (math.sqrt(x1^2 + z1^2) * math.sqrt(x2^2 + z2^2))))
end

local function get_stealth_ratio(angle_2d)
	local stealth_ratio
	if angle_2d <= pickp.settings["zone_1_2_limit"] then
		stealth_ratio = pickp.settings["zone1_stealth_ratio"]
	elseif angle_2d > pickp.settings["zone_1_2_limit"] and angle_2d < pickp.settings["zone_2_3_limit"] then
		stealth_ratio = pickp.settings["zone2_stealth_ratio"]
	else
		stealth_ratio = pickp.settings["zone3_stealth_ratio"]
	end
	return stealth_ratio
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
	if formname ~= "pickp:form" then
		return
	end
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

		--DETECTION WARNING

		--Check the angle/ratio
		local angle_2d = get_angle(player, clicked)
		local stealth_ratio = get_stealth_ratio(angle_2d)
		local type_item_reduction_factor
		if steal_itemstack.type == "main" then
			type_item_reduction_factor = pickp.settings["warning_main_item"]
		else
			type_item_reduction_factor = pickp.settings["warning_hotbar_item"]
		end
		stealth_ratio = stealth_ratio + type_item_reduction_factor

		if math.random(0,1) >= stealth_ratio then
			--NOT detected
			minetest.chat_send_player(player:get_player_name(), S("Successful robbery!"))
		else
			--DETECTION WARNING
			local clicked_name = clicked:get_player_name()
			local msg
			if math.random(0,1) <= pickp.settings["warning_failed_thief_ratio"] then
				msg = S("Someone has stolen from you!")
			else
				msg = clicked_name.." "..S("has stolen from you")
			end
			minetest.chat_send_player(clicked_name, msg)
			if pickp.settings["sound_alarm"] then
				pickp.make_sound("player", clicked, "pickp_alarm", 10)
			end
		end
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
		disable_stealth(clicker, true, "The victim has walked away!")
		return
	end
	--2) CHECK THE ANGLE
	local angle_2d = get_angle(clicker, clicked)
	--minetest.chat_send_all(tostring(angle_2d))
	local stealth_ratio = get_stealth_ratio(angle_2d)
	--Detect the zone & get the ratio accordingly-->
	if math.random(0,1) >= stealth_ratio then --NOT detected
		minetest.after(pickp.settings["stealth_timing"], stealth, clicker, clicked)
		return
	end
	--DETECTED!
	disable_stealth(clicker, true, "Failed Robbery!")
	if pickp.settings["sound_fail"] then
		pickp.make_sound("player", clicker, "pickp_fail", 10)
	end
	--DETECTION WARNING
	local msg
	if math.random(0,1) <= pickp.settings["warning_failed_thief_ratio"] then
		msg = S("Someone has tried to steal from you!")
	else
		msg = clicked_name.." "..S("tried to steal from you!")
	end
	minetest.chat_send_player(clicked_name, msg)
	if pickp.settings["sound_alarm"] then
		pickp.make_sound("player", clicked, "pickp_alarm", 10)
	end
end

local function pickpocketing(clicker, clicked)
	local clicker_name = clicker:get_player_name()
	local rob_list, rob_table, columns = get_rob_list(clicked)
	if not(rob_list == "") then
		minetest.show_formspec(clicker_name,
			"pickp:form", get_formspec(clicker, clicked, rob_list, columns))
		local angle_2d = get_angle(clicker, clicked)
		enable_steal(clicker, clicked, rob_table, angle_2d) --mark as stealing
		minetest.after(pickp.settings["stealth_timing"], stealth, clicker, clicked)
	else
		minetest.chat_send_player(clicker_name, S("Failed robbery!"))
		if pickp.settings["sound_fail"] then
			pickp.make_sound("player", clicker, "pickp_fail", 10)
		end
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
