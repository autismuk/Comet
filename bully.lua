--- ************************************************************************************************************************************************************************
---
---				Name : 		bully.lua
---				Purpose :	COMET (Component/Entity Framework for Corona/Lua) - be really nasty test.
---				Created:	28 May 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

math.randomseed(57)

local comet = Comet:new()

local componentCount = 50
local entityCount = 100
local queryCount = 100
local querySizeMax = 4

local compName = {}																						-- a list of component names.
local entity = {} 																						-- list of entities.
local entityData = {} 																					-- component list for entity (for cross check)
local queries = {} 																						-- queries

for i = 1,componentCount do 																			-- create all the components we are using.
	compName[i] = "comp"..(i+1000)
	comet:newC(compName[i],"n:int")
end

function makeList(n)  																					-- create a list of n unique components.
	local used = {} 	
	local result = ""
	while n > 0 do 
		local nc = math.random(1,componentCount)
		if used[nc] == nil then 
			used[nc] = true
			result = result .. compName[nc] .. ","
			n = n - 1
		end 
	end
	return result:sub(1,-2) 
end 

for i = 1,entityCount do 
	entityData[i] = makeList(math.random(1,math.floor(componentCount/4)))
	entity[i] = comet:newE(entityData[i])
end

function validateEntityList(textList,compList)
	textList = comet:split(textList) 																	-- convert csv to array of strings
	local ctList = {}
	for i = 1,#textList do  																			-- scan text list
		local cRef = comet:getComponentByName(textList[i]) 												-- get component
		ctList[cRef] = cRef 																			-- create hash of component refs in text list
		local cID = cRef.cm_cID 																		-- get ID
		assert(compList[cID] ~= nil) 																	-- check it is in the entities component list
	end 
	for id,ref in pairs(compList) do  																	-- for all entities in entity component list
		assert(ctList[ref] ~= nil) 																		-- check there is a text list equivalent.
	end 
end 

function checkQuery(query,entity) 
	for _,cCheck in ipairs(query) do 																	-- for each component in the query.
		if entity.en_components[cCheck.cm_cID] == nil then return false end
	end
	return true
end 

function validateQueryResult(query,result)
	query = comet:split(query) 																			-- convert query to an array of strings.
	for i = 1,#query do query[i] = comet:getComponentByName(query[i]) end 								-- convert to component references.	
	local success = {} 																					-- make a hash where key is the successful entity ref.
	for _,entity in ipairs(result) do success[entity] = entity end 										-- success if in hash, fail otherwise.
	for _,entity in ipairs(entity) do 																	-- now check each entity manually.
		local pass = checkQuery(query,entity) 															-- check the query result.
		assert(pass == (success[entity] ~= nil)) 														-- if successful should be there, not otherwise.
	end 
end

print("Start")

for testCount = 1,100 do
	if testCount % 1 == 0 then print(testCount) end

	for chg = 1,3 do 																					-- changing components.
		local comp = compName[math.random(1,componentCount)] 											-- this is the component we are adding and removing.
		local ent = math.random(1,entityCount) 															-- and this is the entity.
		if entityData[ent]:find(comp) == nil then 														-- is it in the entity already ?
			entityData[ent] = entityData[ent] .. "," .. comp 											-- add to the text version.
			entity[ent]:addC(comp) 																		-- and the internal version
		else
			entityData[ent] = entityData[ent]:gsub(comp,""):gsub(",,",",")								-- remove from the text version
			entity[ent]:remC(comp) 																		-- and the internal version.
		end		
		if entityData[ent]:match("%,$") then entityData[ent] = entityData[ent]:sub(1,-2) end
		if entityData[ent]:sub(1,1) == "," then entityData[ent] = entityData[ent]:sub(2) end

		if math.random(1,50) == 1 then 																	-- occasionally, get a new empty entity.
			ent = math.random(1,entityCount)
			entity[ent]:remove()
			entity[ent] = comet:newE()
			entityData[ent] = ""
		end
	end
	
	for i = 1,entityCount do  																			-- check the entity components match.
		entity[i].myID = i
		validateEntityList(entityData[i],entity[i].en_components)
	end 

	for i = 1,queryCount do  																			-- check all the query results are still valid
		--if math.random(1,100) == 1 then queries[i] = nil end 											-- occasionally, have a new query
		if queries[i] == nil then  																		-- create it if it doesn't exist
			queries[i] = makeList(2)
		end 
		local result = comet:query(queries[i]) 															-- run the query
		validateQueryResult(queries[i],result) 															-- check it matches.
	end
end 
print(comet.cm_cacheInfo.hits," of ",comet.cm_cacheInfo.total)
print(math.floor(100*comet.cm_cacheInfo.hits/comet.cm_cacheInfo.total).."% cache success")

comet:destroyAll()
print("Done")
