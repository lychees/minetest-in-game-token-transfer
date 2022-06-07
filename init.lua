--Variables
local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)

--Settings
web3 = {}
local modpath = minetest.get_modpath(modname)
assert(loadfile(modpath.. "/settings.lua"))(modpath)

--Follow
followlist = {}
backtracklist = {}

local function register_follow(target_name, follower_name)
	if followlist[target_name] == nil then
		followlist[target_name] = {}
	end
	followlist[target_name][follower_name] = true
	backtracklist[follower_name] = target_name
end

-- calculate distance
local get_distance = function(a, b)

	if not a or not b then return 50 end -- nil check

	return vector.distance(a, b)
end

minetest.register_globalstep(function(dtime)
	for target_name, follower_list in pairs(followlist) do
		local target = minetest.get_player_by_name(target_name)
		for follower_name, v in pairs(follower_list) do
			local follower = minetest.get_player_by_name(follower_name)
			if follower:get_player_control_bits() ~= 0 then
				if followlist[target_name][follower_name] ~= nil then
					followlist[target_name][follower_name] = nil
				end
				if backtracklist[follower_name] ~= nil then
					backtracklist[follower_name] = nil
				end
				minetest.chat_send_player(target_name, follower_name .. " stop following you")
				minetest.chat_send_player(follower_name, "you you have stopped following " .. target_name)
			elseif get_distance(follower:get_pos(), target:get_pos()) > 5 then
				follower:set_pos(target:get_pos())
			end
		end
	end
end)

local _contexts = {}
local function get_context(name)
    local context = _contexts[name] or {}
    _contexts[name] = context
    return context
end

minetest.register_on_player_receive_fields(function(player, formname, fields)

    if formname == "player:interact" then
		local s = player:get_player_name()
		local t = get_context(s).target	
		if fields.profile then
			minetest.chat_send_player(s, ".EM_ASM window.open(\"https://" .. t .. ".test.w3itch.io/zh-CN\", \"new\")")
		end
		if fields.transfer then
			minetest.chat_send_player(s, ".EM_ASM window.parent.MINETEST_METAMASK.sendTransaction('" .. t .."', '0')")
		end
		if fields.follow then
			register_follow(t, s)
			minetest.chat_send_player(s, "you have started following " .. t)
			minetest.chat_send_player(t, s .. " starts to follow you")
		end
		return true
    end
end)

local function check_distance(clicker, clicked)
	local pos1 = clicker:get_pos()
	local pos2 = clicked:get_pos()
	local distance = vector.distance(pos1, pos2)
	if distance > web3.settings["distance"] then
		return false
	else
		return true
	end
end

minetest.register_on_leaveplayer(function(player)
	local player_name = player:get_player_name()
    _contexts[player_name] = nil
	if followlist[player_name] ~= nil and backtracklist[player_name] ~= nil then
		followlist[player_name] = nil
		followlist[backtracklist[player_name]][player_name] = nil
		backtracklist[player_name] = nil
	end
end)

minetest.register_on_rightclickplayer(function(player, clicker)
	local s = clicker:get_player_name()
	local t = player:get_player_name()
	local controls = clicker:get_player_control()
	if not(check_distance(clicker, player)) then
		minetest.chat_send_player(s, S("Target too far."))
		return
	end
	local context = get_context(s)
	context.target = t	
	local formspec = {
		"formspec_version[4]",
		"size[4.5,5.25]",
		"label[0.375,0.5;", minetest.formspec_escape("This is " .. t .. "."), "]",
		"button_exit[0.5,1;3.5,0.8;profile;Profile]",
		"button_exit[0.5,2;3.5,0.8;transfer;Transfer]",
		"button_exit[0.5,3;3.5,0.8;follow;Follow]",
		"button_exit[0.5,4;3.5,0.8;cancel;Cancel]"
	}
	minetest.show_formspec(s, "player:interact", table.concat(formspec, ""))
end)

minetest.register_chatcommand("go", {	
    func = function(name)
		local context = get_context(name)
		context.target = name
		local formspec = {
			"formspec_version[4]",
			"size[4.5,5.25]",
			"label[0.375,0.5;", minetest.formspec_escape("This is " .. name .. "."), "]",
			"button_exit[0.5,1;3.5,0.8;profile;Profile]",
			"button_exit[0.5,2;3.5,0.8;transfer;Transfer]",
			"button_exit[0.5,3;3.5,0.8;follow;Follow]",
			"button_exit[0.5,4;3.5,0.8;cancel;Cancel]"
		}
		minetest.show_formspec(name, "player:interact", table.concat(formspec, ""))
    end,
})