local modpath = ...

pickp.settings = {}

local settings = Settings(modpath .. "/pickp.conf")

pickp.settings.hotbar_size = tonumber(settings:get("hotbar_size"))
pickp.settings.hotbar_ratio = tonumber(settings:get("hotbar_ratio"))
pickp.settings.main_ratio = tonumber(settings:get("main_ratio"))
pickp.settings.stealing_distance = tonumber(settings:get("stealing_distance"))
pickp.settings.stealth_timing = tonumber(settings:get("stealth_timing"))
pickp.settings.zone_1_2_limit = tonumber(settings:get("zone_1_2_limit"))
pickp.settings.zone_2_3_limit = tonumber(settings:get("zone_2_3_limit"))
pickp.settings.zone1_stealth_ratio = tonumber(settings:get("zone1_stealth_ratio"))
pickp.settings.zone2_stealth_ratio = tonumber(settings:get("zone2_stealth_ratio"))
pickp.settings.zone3_stealth_ratio = tonumber(settings:get("zone3_stealth_ratio"))
pickp.settings.warning_failed_thief_ratio = tonumber(settings:get("warning_failed_thief_ratio"))
pickp.settings.warning_hotbar_item = tonumber(settings:get("warning_hotbar_item"))
pickp.settings.warning_main_item = tonumber(settings:get("warning_main_item"))

