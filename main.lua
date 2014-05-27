--- ************************************************************************************************************************************************************************
---
---				Name : 		main.lua
---				Purpose :	COMET (Component/Entity Framework for Corona/Lua)
---				Created:	27 May 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s o:initialise(...) return o end, initialise = function() end }

--- ************************************************************************************************************************************************************************
--//	Comet Class. This can act both as a prototype and an instance. Manages collections of components, entities and systems. This is fairly standard - except that
--//	components can have constructors and destructors. This is somewhat like Crafty - the idea is that if a sprite component is defined it can create itself.
--- ************************************************************************************************************************************************************************

local Comet = Base:new() 

--// 	Constructor. Initialises the list of components and entities, and the next IDs.

function Comet:initialise() 
	self.cm_nextComponentID = 10000 																		-- next component number
	self.cm_components = {} 																				-- components (id/name => component data)
	self.cm_nextEntityID = 20000 																			-- next entity number
	self.cm_entities = {} 																					-- entities (id/name => entity data)
end 

--//	Helper method which converts a comma seperated string into an array of strings. Same as split() in Python.
--//	@csString 	[string]			string seperated by commas.
--//	@return 	[table]				array of those strings.

function Comet:split(csString) 
	local table = {} 																						-- this is the final table 
	if csString == "" then return table end  																-- no entries.
	csString = csString .. "," 																				-- add a trailing comma 
	while csString ~= "" do 																				-- do the whole string.
		local item  item,csString = csString:match("^([%w%:%_%.]+)%,(.*)$") 								-- split off the first bit.
		table[#table+1] = item 																				-- put in the table.
	end 
	return table 
end 

--//	Define a new Component. This has a name a list of members with default type values, and optional constructors, destructors
--//	and required sub-components.
--//
--//	@name 		[name] 				name of component (case independent)
--//	@members 	[string/table]		list or array of members in <name>:<type> format.
--//	@cInfo 		[table]				component info. constructor (function) destructor (function) requires (string/table)
--//	@return 	[number]	 		Component ID Number.

function Comet:newC(name,members,cInfo) 
	assert(name ~= nil and members ~= nil and name ~= "","Bad parameter") 									-- basic checks 
	name = name:lower() 																					-- case independent
	assert(self.cm_components[name] == nil,"Duplicate named component") 									-- check only one.
	cInfo = cInfo or {} 																					-- if nothing provided.
	local comp = { } 																						-- build a component table.
	comp.cm_cID = self.cm_nextComponentID 																	-- component ID.
	comp.cm_name = name 																					-- name 
	comp.cm_entities = {} 																					-- IDs of entities that use this component (key and data the same)
	comp.cm_entityCount = 0 																				-- number of entities that use this component.
	comp.cm_members = {} 																					-- array of (name = <name>, default = <value> for members)
	comp.cm_requires = {} 																					-- list of component references that this component requires.
	comp.cm_constructor = cInfo.constructor 																-- clear up and create methods, so you can have a component that is a sprite. 
	comp.cm_destructor = cInfo.destructor 
	comp.cm_requires = cInfo.requires or {}  																-- get list of required components.

	if type(comp.cm_requires) == "string" then  															-- if string list 
		comp.cm_requires = self:split(comp.cm_requires) 													-- convert to an array of strings
	end 
	for i = 1,#comp.cm_requires do  																		-- scan through them
		if type(comp.cm_requires[i]) == "string" then 														-- is it a string, e.g. a textual name
			comp.cm_requires[i] = self:getComponentByName(comp.cm_requires[i]) 								-- convert to a component ID.
		end
	end

	if type(members) == "string" then 																		-- convert member string to a list.
		members = self:split(members)
	end 
	for _,def in ipairs(members) do 																		-- scan through the members.
		if def:find(":") == nil then def = def .. ":object" end 											-- default type of number
		local memItem = {}
		memItem.name,memItem.default = def:match("^(.*)%:(.*)$") 											-- split it up.
		memItem.default = Comet.defaultTypeValues[memItem.default] 											-- store it.
		comp.cm_members[#comp.cm_members+1] = memItem 														-- put in members table
	end

	self.cm_components[name] = comp 																		-- store in components table under id and name
	self.cm_components[comp.cm_cID] = comp 
	self.cm_nextComponentID = self.cm_nextComponentID + 1 													-- bump component ID
	return comp.cm_cID 																						-- return the ID
end

Comet.defaultTypeValues = { int = 0, number = 0, table = nil, string = "", object = nil,boolean = false }	-- default type values.

--//	Find a component, throw an error if it does not exist
--//	@name 	[string] 		Name of component
--//	@return [table] 		Reference of component table.

function Comet:getComponentByName(name)
	assert(name ~= nil and name ~= "")
	name = name:lower() 																					-- no caps.
	assert(self.cm_components[name] ~= nil,"Unknown component "..name) 										-- check it exists
	return self.cm_components[name]
end 

--//	Define a new entity.
--//	@cList 	[string] 		List of components, optional. Saves addC() calls.
--//	@return [entity]		reference to entity

function Comet:newE(cList)
	local ent = {} 																							-- build entity
	ent.en_eID = self.cm_nextEntityID 																		-- entity ID.
	ent.en_components = {} 																					-- list of components that make up the entity.
	ent.en_owner = self 																					-- point to the owner.
	self.cm_entities[ent.en_eID] = ent 																		-- save in the entities table under ID.
	self.cm_nextEntityID = self.cm_nextEntityID + 1 														-- bump the entity ID
	if cList ~= nil then self:insertComponent(ent,cList) end 												-- insert into the list if component list provided.
	ent.addC = function(...) self.insertComponent(ent,...) end 												-- decorate with methods
	ent.remC = function(...) self.removeComponent(ent,...) end
	ent.remove = function(...) self.removeEntity(ent,...) end
	return ent
end 

--//	Insert a new component or components. If the entity is a comma list or a table the constructor parameters are not available
--//	as there is no way of identifying which constructor. 
--//	@entity 	[entity reference]		entity to insert component(s) into
--//	@cList 		[string/table]			string, comma seperated items, or table of strings.
--//	@return 	[entity]				chaining.

function Comet:insertComponent(entity,cList,...)
	local owner = entity.en_owner 																			-- this is the comet instance.
	if type(cList) == "string" and cList:find(",") ~= nil then 												-- string with commas in, convert to a table.
		cList = owner:split(cList) 
	end
	if type(cList) == "table" then 																			-- if it is a table 
		for _,component in ipairs(cList) do owner:insertComponent(entity,component) end 					-- insert all the listed components with no constructor parameters
		return entity 																						-- return reference to the entity
	end 
	local newComponent = owner:getComponentByName(cList) 													-- get the component that we want.
	owner:insertComponentByRef(entity,newComponent,...) 													-- insert component by reference
	return entity
end 

--//	Insert a single entity by reference.
--//	@entity 	[entity reference]		entity to insert component(s) into

function Comet:insertComponentByRef(entity,component,...)
	if entity.en_components[entity.en_eID] ~= nil then return end 											-- if already in the entity, then return.
	for _,reqComponent in ipairs(component.cm_requires) do 													-- insert all the required components.
		self:insertComponentByRef(entity,reqComponent)
	end
	if entity.en_components[component.cm_cID] ~= nil then return end 										-- if already in the entity, then return (could be circular)
	entity.en_components[component.cm_cID] = component 														-- put the component in the entity's component table.
	assert(component.cm_entities[entity.en_eID] == nil) 													-- check the tables match up.
	component.cm_entities[entity.en_eID] = entity.en_eID 													-- put the entity in the component's table for that entity
	component.cm_entityCount = component.cm_entityCount + 1 												-- bump the component count.

	for _,members in ipairs(component.cm_members) do 														-- give the members default values.
		entity[members.name] = entity[members.name] or members.default
	end 

	if component.cm_constructor ~= nil then 																-- does the component have a constructor ?
		component.cm_constructor(entity,...) 																-- then call it.
	end 
end 

--//	Remove an entity permanently. leaves data members unaffected.
--//	@entity [entity]	Entity to remove.

function Comet:removeEntity(entity)
	local owner = entity.en_owner 																			-- this is the comet instance.
	for _,compRef in pairs(entity.en_components) do  														-- scan through all the components
		owner:removeComponentByReference(entity,compRef) 													-- and remove them.
	end
	assert(owner.cm_entities[entity.en_eID] == entity) 														-- check the entity table is okay.
	owner.cm_entities[entity.en_eID] = nil 																	-- remove entry from the entity table.
	entity.addC = nil entity.remC = nil entity.remove = nil 												-- null out the methods
	entity.en_components = nil entity.en_eID = nil entity.en_owner = nil 									-- remove other data.
end 

--//	Remove a component.
--//	@entity 	[entity reference]		entity to insert component(s) into
--//	@cList 		[string/table]			string or table or comma list of components that are going.
--//	@return 	[entity]				chaining.

function Comet:removeComponent(entity,cList) 
	local owner = entity.en_owner 																			-- this is the comet instance.
	if type(cList) == "string" and cList:find(",") ~= nil then 												-- string with commas in, convert to a table.
		cList = owner:split(cList) 
	end
	if type(cList) == "table" then 																			-- if it is a table 
		for _,component in ipairs(cList) do owner:removeComponent(entity,component) end 					-- remove all listed components with no constructor parameters
		return entity 																						-- return reference to the entity
	end 
	local component = owner:getComponentByName(cList) 														-- get the component reference.
	owner:removeComponentByReference(entity,component)
	return entity
end

--//	@entity 	[entity reference]		entity to remove component from
--//	@component 	[string/table]			string, comma seperated items, or table of strings.

function Comet:removeComponentByReference(entity,component)
	assert(entity.en_components[component.cm_cID] == component)												-- check the refs are right
	assert(component.cm_entities[entity.en_eID] == entity.en_eID)
	entity.en_components[component.cm_cID] = nil 															-- then remove them, entity no longer has this component
	component.cm_entities[entity.en_eID] = nil 																-- this component no longer used by this entity
	component.cm_entityCount = component.cm_entityCount - 1 												-- decrement the count
	if component.cm_destructor ~= nil then 																	-- does this component have a destructor
		component.cm_destructor(entity) 																	-- then call it.
	end
end 

--- ************************************************************************************************************************************************************************
--- ************************************************************************************************************************************************************************

local c = Comet:new()

local c1 = c:newC("position","x:int,y:int")
local c2 = c:newC("size","width:number,height:number")
local c4 = c:newC("coronaobject","displayObj:object")
local c3 = c:newC("sprite","",{ requires = "position,size,coronaobject",
								constructor = function(entity,fileName,size) entity.displayObj = display.newImage(fileName) end,
								destructor = function(entity) entity.displayObj:removeSelf() entity.displayObj = nil end })

local e1 = c:newE()
e1:addC("sprite","crab.png",42)
e1.displayObj.x = 200
--e1:remC({"size","position","coronaobject"})

local e2 = c:newE({"position","size","coronaobject"})
e2:addC("sprite","cat.jpg",44)
--e2:remC("sprite")

e1:remove()
e2:remove()
for k,v in pairs(e1) do print(k,v) end
