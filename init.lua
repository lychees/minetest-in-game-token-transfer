--Variables
local modname = minetest.get_current_modname()
local S = minetest.get_translator(modname)

--Settings
web3 = {}
local modpath = minetest.get_modpath(modname)
assert(loadfile(modpath.. "/settings.lua"))(modpath)

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
			minetest.chat_send_player(s, ".EM_ASM alert(feature not implement yet...)")
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
    _contexts[player:get_player_name()] = nil
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