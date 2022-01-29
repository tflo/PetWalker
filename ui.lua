local addonName, ns = ...

--[[ debugging ]]
--[[
print(addonName, "'s ui.lua has loaded")

local myDBValue

do
	local ns = addonName
	myDBValue = ns.db.autoEnabled
	print("ui.lua: We have '", myDBValue, "' in ns.db after re-assigning 'PetWalker' namespace")
end

myDBValue = ns.db.autoEnabled
print("ui.lua: We have '", myDBValue, "' in ns.db")

myDBValue = PetWalkerDB.autoEnabled
print("ui.lua: We have '", myDBValue, "' in literal PetWalkerDB")
--]]
--[[ end ]]


