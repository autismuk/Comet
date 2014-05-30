--- ************************************************************************************************************************************************************************
---
---				Name : 		bully.lua
---				Purpose :	COMET (Component/Entity Framework for Corona/Lua) - be really nasty test.
---				Created:	30 May 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

local comet = Comet:new()

local componentCount = 100																				-- number of components.
local entityCount = 200 																				-- number of entities.
local entityKillChance = 5 																				-- chance of randomly chosen entity being killed. 

local compRefs = {} 																					-- reference of components.
local entityRefs = {} 																					-- reference of entities
local entityComps = {} 																					-- entity components, keyed on the component entity reference, table of component keys.

--- ************************************************************************************************************************************************************************

function tableCount(t)
	local c = 0
	for _,_ in pairs(t) do c = c + 1 end 
	return c 
end 

--- ************************************************************************************************************************************************************************

function tablesEq(a,b)
	if tableCount(a) ~= tableCount(b) then return false end 											-- tables must have same number of members.
	for k,v in pairs(a) do 
		if b[k] ~= v then return false end
	end
	return true 
end 

--- ************************************************************************************************************************************************************************

function changeAnEntity() 				
	local entity = entityRefs[math.random(1,entityCount)] 												-- pick a random entity 
	local component = compRefs[math.random(1,componentCount)] 											-- pick a random component

	if entityComps[entity][component] == nil or math.random(1,10) == 1 then 							-- component not in entity then add it, sometimes do it anyway.
		entityComps[entity][component] = component 
		entity:addC(component) 
	else  																								-- entity in component, remove it.
		entityComps[entity][component] = nil
		entity:remC(component) 
	end 
	for i = 1,entityCount do 																			-- process all entities.
		entity = entityRefs[i]
		assert(tablesEq(entityComps[entity],entity.en_components)) 										-- check the component tables match.
	end
end

--- ************************************************************************************************************************************************************************

function checkInstanceCount()
	local iCount = {}
	for _,entity in ipairs(entityRefs) do 																-- work through all the entity refs.
		for _,component in pairs(entity.en_components) do 												-- work through all the components.
			iCount[component] = (iCount[component] or 0) + 1 	
		end 
	end 
	for _,component in ipairs(compRefs) do 
		assert(component.co_instanceCount == (iCount[component] or 0)) 
	end 
end

--- ************************************************************************************************************************************************************************

function randomKill() 
	local n = math.random(1,entityCount)
	entityRefs[n]:remove()
	entityRefs[n] = comet:newE()
	entityComps[entityRefs[n]] = {}
end 

--- ************************************************************************************************************************************************************************

local cdCount = 0

math.randomseed(57)

for i = 1,componentCount do  																			-- create the components
	local cName = ("comp%03d"):format(i) 																-- this is their name.
	local members = {} 																					-- construct some random members for them.
	for i = 1,math.random(2,8) do members[string.char(math.random(97,122))] = math.random(-100,100) end
	members.constructor = function(c,e,p) cdCount = cdCount + 1 end 									-- add constructor/destructor
	members.destructor = function(c,e,p) cdCount = cdCount - 1 end
	compRefs[i] = comet:newC(cName,members)
end


for i = 1,entityCount do 																				-- initially they are all completely empty
	entityRefs[i] = comet:newE() 
	entityComps[entityRefs[i]] = {} 																	-- clear the table of components for this entity.
end 

for i = 1,1000 do 
	changeAnEntity()  																					-- randomly change one entity
	if math.random(1,entityKillChance) == 1 then randomKill() end 										-- randomly kill one entity
	checkInstanceCount() 																				-- check the instance count.
end 

print("Done") print(cdCount) comet:remove() print(cdCount)
