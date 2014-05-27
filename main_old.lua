--- ************************************************************************************************************************************************************************
---
---				Name : 		main.lua
---				Purpose :	Mark 1 C/E/S
---				Created:	27 May
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

local CES = {}

CES.componentList = {} 																	-- Components [name] => [table]
CES.entityList = {} 																	-- Entities [name] => [table] 

CES.nextComponentID = 1000 																-- Next component ID.
CES.nextEntityID = 10000 																-- Next entity ID.

CES.addComponent = function(name,options)
	assert(name ~= nil,"No component name")												-- Basic checks.
	name = name:lower() 																-- Case independent
	assert(CES.componentList[name] == nil,"Duplicate component name") 					-- Components must be unique.
	options = options or {} 															-- Create default table value.
	local comInfo = {} 																	-- This is the new component table entry.
	comInfo.id = CES.nextComponentID  													-- component ID.
	comInfo.name = name 																-- name 
	comInfo.members = options.members or {} 											-- members.
	comInfo.constructor = options.create 												-- 'constructor' function
	comInfo.destructor = options.destroy 												-- 'destructor' function
	comInfo.entityList = {} 															-- the Entity IDs of all entities that have this component are keys.
	comInfo.entityCount = 0 															-- the number of entity IDs that have this component.
	CES.componentList[name] = comInfo 													-- store it under name and ID so it can be accessed by either.
	CES.componentList[comInfo.id] = comInfo
	CES.nextComponentID = CES.nextComponentID + 1 										-- advance the component ID.
	return CES
end 

CES.typeDefaults = { table = {}, string = "", number = 0, boolean = false, object = nil }

CES.addComponentToEntity = function(self,component, ...)
	assert(component ~= nil,"No component name") 										-- check present
	local compRec = CES.componentList[component:lower()] 								-- get component Information
	assert(compRec ~= nil,"Unknown component")											-- does it exist
	local compID = compRec.id 															-- get component ID.
	assert(self.components[compID] == nil,"Component already present")					-- check component not already present.
	for _,member in ipairs(compRec.members) do 											-- work through all members.
		local name,mtype = member:match("^(.*)%:(.*)$")									-- split into name and type
		assert(mtype ~= nil,"Component has bad member definition")
		assert(type(self.name) ~= "function","Member name is a function")
		mtype = mtype:lower() 															-- type is l/c
		assert(CES.typeDefaults[mtype] ~= nil,"Unknown member type") 					-- check type known
		self[name] = self[name] or CES.typeDefaults[mtype] 								-- add in the type defaults.
	end
	if compRec.constructor ~= nil then 
		compRec.constructor(self,...)
	end 
	compRec.entityList[self.id] = self.id  												-- Add to the entity list for this component
	self.components[compID] = compID 													-- Add component to the list for this entity
	compRec.entityCount = compRec.entityCount + 1 										-- end 
	return self
end 

CES.removeComponentFromEntity = function(self,component) 
	assert(component ~= nil,"No component name") 										-- check present
	local compRec = CES.componentList[component:lower()] 								-- get component Information
	assert(compRec ~= nil,"Unknown component")											-- does it exist
	local compID = compRec.id 															-- get component ID.
	assert(self.components[compID] ~= nil,"Component not present")						-- check component present.
	if compRec.destructor ~= nil then 													-- component destructor present
		compRec.destructor(self) 		
	end
	compRec.entityList[self.id] = nil  													-- Remove from the entity list for this component
	self.components[compID] = nil 														-- Remove component from the list for this entity
	compRec.entityCount = compRec.entityCount - 1 										-- decrement the number of entities in the component list.
	return self
end 

CES.newEntity = function() 																-- create a new entity.
	local id = CES.nextEntityID 														-- remember the ID
	CES.nextEntityID = CES.nextEntityID + 1 											-- bump the entity ID.
	local entInfo = {} 																	-- create the entity.
	entInfo.id = id 																	-- save the entity ID
	entInfo.components = {} 															-- list of component IDs.
	CES.entityList[id] = entInfo 														-- save a reference to it in the entity list
	entInfo.addComponent = CES.addComponentToEntity 									-- decorate with required methods.
	entInfo.removeComponent = CES.removeComponentFromEntity 
	return entInfo 
end

CES.updateSystem = function(self) 
	-- TODO: if entity count higher, then sort sysInfo.componentList on the number of entities having it, so fewest first.
	--print(CES.componentList[1000].entityCount)
	--for k,v in pairs(CES.componentList[1000].entityList) do print(k,v) end
	for _,entity in pairs(CES.componentList[self.componentList[1]].entityList) do 		-- list of entities containing the first component 
		local present = true  															-- check it contains the rest of them
		local rec = 2 																	-- start with second
		while present and rec <= #self.componentList do  								-- done them all
			local req = self.componentList[rec] 										-- the component we need to be present
			present = present and (CES.entityList[entity].components[req] ~= nil) 		-- set present to false if entity does not have it.
			rec = rec + 1 																-- advance to next
		end
		if present then self.updateFunction(CES.entityList[entity]) end 				-- if was found then call update
	end 
end 


CES.newSystem = function(components,sysDef) 
	local sysInfo = {} 																	-- system information structure.
	assert(components ~= nil and components ~= "","Bad component list") 				-- must be a list of component
	sysInfo.componentList = {} 															-- list of components.
	components = components .. "," 														-- add a trailing comma for splitting.
	while components ~= "" do 															-- go through the componenty list.
		local component  																-- rip out the first componenty
		component,components = components:match("^(%w+)%,(.*)$")
		component = component:lower() 													-- check it exists, case insensitive
		assert(CES.componentList[component] ~= nil,"Unknown component")
		sysInfo.componentList[#sysInfo.componentList+1] = 								-- add component list.
													CES.componentList[component].id
	end
	sysInfo.preFunction = sysDef.before 												-- remember the methods
	sysInfo.updateFunction = sysDef.update 
	sysInfo.postFunction = sysDef.after 
	sysInfo.update = CES.updateSystem 													-- decorate with required methods
	return sysInfo
end 


CES.addComponent("position",{ members = { "x:number","y:number" }})

CES.addComponent("sprite", { members = { "displayObject:table" },
							 create = function(self,imageFile) self.displayObject = display.newImage(imageFile) end ,
							 destroy = function(self) self.displayObject.alpha = 0.2 end })

CES.addComponent("size", { members = { "width:number", "height:number"}})

s = CES.newSystem( "position,sprite",
					{ 
						update = function(entity) entity.displayObject.x = entity.x entity.displayObject.y = entity.y end
					})

s2 = CES.newSystem( "sprite,size",
					{ 
						update = function(entity) entity.displayObject.width = entity.width entity.displayObject.height = entity.height end
					})

s3 = CES.newSystem("position", 
					{
						update = function(entity) entity.x = (entity.x + 1) % 320 end
					})

local x = CES.newEntity()
x:addComponent("sprite","cat.jpg")
x:addComponent("position")
x:addComponent("size")
x.x = 160 x.y = 240
x.width = 32 x.height = 32

local x2 = CES.newEntity()
x2:addComponent("sprite","crab.png")
x2:addComponent("position")
x2:addComponent("size")
x2.x = 32 x2.y = 32
x2.width = 64 x2.height = 64
--x2:removeComponent("size")
-- for k,v in pairs(x2) do print("x2",k,v) end

Runtime:addEventListener( "enterFrame",function()
	s:update()
	s2:update()
	s3:update()
end)

-- {} or ",,," optional.
-- Query
-- Entity Remove
-- Sorting.


