local addonName, ns = ...

---[[Debug]]--[=[
print(addonName, "'s ui.lua has loaded")

local myDBValue

---[[
myDBValue = ns.db.autoEnabled
print("ui.lua: We have '", myDBValue, "' in ns.db, as it should be")
--]]

--[[
do
	ns.db = PetWalkerDB
	myDBValue = ns.db.autoEnabled
	print("ui.lua: We have '", myDBValue, "' in ns.db after re-assigning 'PetWalker' DB name")
end
--]]

--[[
myDBValue = PetWalkerDB.autoEnabled
print("ui.lua: We have '", myDBValue, "' in literal PetWalkerDB")
--]]
--]=]


