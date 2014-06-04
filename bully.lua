--- ************************************************************************************************************************************************************************
---
---				Name : 		bully.lua
---				Purpose :	COMET (Component/Entity Framework for Corona/Lua), version 4 testing
---				Created:	4th June 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s o:initialise(...) return o end, initialise = function() end }

local comet = Comet:new() 																							-- create a component.

local comCount = 100 
local entCount = 100 												

local components = {} 																								-- component references.
local entities = {} 																								-- entity references
local entComp = {}  																								-- components used in entities (eid => (compref =>compref))
local compEnt = {} 																									-- entities using components (cid => (entref => entref))

--- ************************************************************************************************************************************************************************

function changeEntity()
	local cn = math.random(1,comCount)																				-- pick a random component
	local en = math.random(1,entCount) 																				-- pick a random entity.

	if entComp[en][components[cn]] == nil then 																		-- not present
		entities[en]:addC(components[cn])
		entComp[en][components[cn]] = components[cn]
		compEnt[cn][entities[en]] = entities[en]
	else 
		entities[en]:remC(components[cn])
		entComp[en][components[cn]] = nil 
		compEnt[cn][entities[en]] = nil
	end 
end 

--- ************************************************************************************************************************************************************************

function tableLen(t)
	local count = 0
	for _,_ in pairs(t) do count = count + 1 end
	return count 
end 

--- ************************************************************************************************************************************************************************

function validateEC()
	for i = 1,entCount do  																							-- check hash inside entity listing components
		assert(tableLen(entComp[i]) == tableLen(entities[i]._eInfo.components)) 									-- check tables the same size
		for k,v in pairs(entComp[i]) do assert(entities[i]._eInfo.components[v] ~= nil) end 						-- check every entComp in entity's internal list.
	end
	for i = 1,comCount do  																							-- check hash inside components listing entities
		assert(tableLen(compEnt[i]) == tableLen(components[i]._cInfo.entities))
		for k,v in pairs(compEnt[i]) do assert(components[i]._cInfo.entities[v] ~= nil) end
	end
end 

--- ************************************************************************************************************************************************************************

for i = 1,comCount do 
	local name = "comp_"..i 																						-- component name
	local options = {} 																								-- component options (members)
	for i = 1,10 do options[string.char(math.random(1,26)+64)] = math.random(1,10) end 								-- add the members
	components[i] = comet:newC(name,options)																		-- store reference.
end

print("Created components")


for i = 1,entCount do 																								-- create entities.
	entities[i] = comet:newE() 
	entComp[i] = {} 
	compEnt[i] = {}
end

print("Created entities")

for i = 1,1000 do 
	for j = 1,10 do changeEntity() end
	validateEC()
end

print("Completed")