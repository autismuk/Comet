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
local queryCount = 50 																					-- number of queries
local maxQuerySize = 5 																					-- max length of query

local entityKillChance = 5 																				-- chance of randomly chosen entity being killed. 

local compRefs = {} 																					-- reference of components.
local entityRefs = {} 																					-- reference of entities
local entityComps = {} 																					-- entity components, keyed on the component entity reference, table of component keys.
local queryRef = {} 																					-- query references.

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
			iCount[component] = (iCount[component] or 0) + 1 	 										-- count the total number of components in the entity.
			assert(component.co_entities[entity] ~= nil)  												-- true if the component table shows it is in this entity - should be !
		end 
	end 
	for _,component in ipairs(compRefs) do  															-- work through all the components
		assert(component.co_instanceCount == (iCount[component] or 0))  								-- do the entity counts match ?
		assert(component.co_instanceCount == tableCount(component.co_entities)) 						-- do the entity counts match the number of entries in the table.
	end 
end

--- ************************************************************************************************************************************************************************

function randomKill() 
	local n = math.random(1,entityCount)
	entityRefs[n]:remove()
	entityRefs[n] = comet:newE()
	entityRefs[n].ref = n
	entityComps[entityRefs[n]] = {}
end 

--- ************************************************************************************************************************************************************************

function calculateQueryResult(componentList)
	local result = {} 																					-- results entityRef => entityRef
	for _,entity in pairs(entityRefs) do  																-- check all known entities
		local ok = true 
		for _,comp in ipairs(componentList) do  														-- look through every component list of query
			ok = ok and (entityComps[entity][comp] ~= nil) 												-- check it is in the entity
		end 
		if ok then result[entity] = entity end  														-- if all are, then add to the result hash.
	end
	return result 
end 

--- ************************************************************************************************************************************************************************

function processQueries() 
	local n = math.random(1,queryCount) 																-- randomly kill a query
	if queryRef[n] ~= nil then 
		queryRef[n]:remove()
		queryRef[n] = nil 
	end 
	for i = 1,queryCount do 																			-- work through queries
		if queryRef[i] == nil then 																		-- new query required ?
			local s = "" 																				-- build a new query.
			local size = math.random(1,maxQuerySize)
			for p = 1,size do 
				local newPart = ""
				repeat 
					newPart = compRefs[math.random(1,componentCount)].co_name 
				until s:find(newPart) == nil 
				if #s > 0 then s = s .. "," end s = s .. newPart
			end
			queryRef[i] = comet:newQ(s) 																-- create a new query instance.
		end
		local result = queryRef[i]:query() 																-- run the query
		local cResult = calculateQueryResult(queryRef[i].qu_query)										-- calculate it the long way.
		assert(tableCount(cResult) == #result) 															-- tabes have the same number of members ?
		for _,entity in ipairs(result) do assert(cResult[entity] ~= nil) end  							-- check every entity in the result is in the calculated one.
	end
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
	entityRefs[i].ref = i
	entityComps[entityRefs[i]] = {} 																	-- clear the table of components for this entity.
end 

for i = 1,queryCount do  																				-- clear all queries
	queryRef[i] = nil 
end 

for i = 1,100*1000 do 
	if i % 250 == 0 then print("Processed ",i) end 														-- progress report
	changeAnEntity()  																					-- randomly change one entity
	if math.random(1,entityKillChance) == 1 then randomKill() end 										-- randomly kill one entity
	checkInstanceCount() 																				-- check the instance count.
	processQueries() 																					-- check the queries.
end 

print("Done") print(cdCount) comet:remove() print(cdCount)
