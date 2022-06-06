local modpath = ...

web3.settings = {}

local settings = Settings(modpath .. "/web3.conf")
web3.settings.distance = tonumber(settings:get("distance"))
