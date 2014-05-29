--- ************************************************************************************************************************************************************************
---
---				Name : 		comet.lua
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

	self.cm_systems = {} 																					-- list of systems.

	self.cm_queryCache = {} 																				-- cache of query results.
	self.cm_invalidComponents = nil 																		-- component refs added/removed from entities
	self.cm_cacheInfo = { hits = 0, total = 0 } 															-- track success of query cache.

	self.cm_lastTime = 0 																					-- last system process time.
end 

--//	Destroy *all* entities and components.

function Comet:destroyAll()
	for _,ref in pairs(self.cm_entities) do self:removeEntity(ref) end 										-- remove all entities.
	self.cm_nextComponentID = nil self.cm_nextEntityID = nil 												-- and erase members
	self.cm_components = nil self.cm_entities = nil self.cm_queryCache = nil 					
	self.cm_cacheInfo = nil self.cm_invalidComponents = nil self.cm_lastTime = nil
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

--//%	Find a component, throw an error if it does not exist
--//	@name 	[string] 		Name of component
--//	@return [table] 		Reference of component table.

function Comet:getComponentByName(name)
	assert(name ~= nil and name ~= "")
	name = name:lower() 																					-- no caps.
	assert(self.cm_components[name] ~= nil,"Unknown component "..name) 										-- check it exists
	return self.cm_components[name]
end 

--//	Define a new entity, with n optional list of components.  Components added this way (or any way in a group) cannot have paremeterised
--//	constructors. The entity object has three methods addC() remC() and remove(), buf if is not a class in its own right. 
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
	ent.addC = function(...) self.insertComponent(ent,...) return ent end 									-- decorate with methods
	ent.remC = function(...) self.removeComponent(ent,...) return ent end
	ent.remove = function(...) self.removeEntity(ent,...) end
	return ent
end 

--//%	Insert a new component or components. If the entity is a comma list or a table the constructor parameters are not available
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

--//%	Insert a single entity by reference.
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
	self.cm_invalidComponents = self.cm_invalidComponents or {} 											-- instantiate invalid list if required
	self.cm_invalidComponents[component] = true 															-- any index with this component in is now invalid

	for _,members in ipairs(component.cm_members) do 														-- give the members default values.
		entity[members.name] = entity[members.name] or members.default
	end 

	if component.cm_constructor ~= nil then 																-- does the component have a constructor ?
		component.cm_constructor(entity,...) 																-- then call it.
	end 
end 

--//%	Remove an entity permanently. leaves data members unaffected.
--//	@entity [entity]	Entity to remove (by reference)

function Comet:removeEntity(entity)
	assert(entity ~= nil,"No entity parameter")
	if entity.en_eID == nil then return end																	-- entity already removed, exit.
	local owner = entity.en_owner 																			-- this is the comet instance.
	for _,compRef in pairs(entity.en_components) do  														-- scan through all the components
		owner:removeComponentByReference(entity,compRef) 													-- and remove them.
	end
	assert(owner.cm_entities[entity.en_eID] == entity) 														-- check the entity table is okay.
	owner.cm_entities[entity.en_eID] = nil 																	-- remove entry from the entity table.
	entity.addC = nil entity.remC = nil entity.remove = nil 												-- null out the methods
	entity.en_components = nil entity.en_eID = nil entity.en_owner = nil 									-- remove other data.
end 

--//%	Remove a compenent or components from an entity
--//	@entity 	[entity reference]		entity to remove from.
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

--//%	Remove a component from an entity by reference.
--//	@entity 	[entity reference]		entity to remove component from
--//	@component 	[string/table]			string, comma seperated items, or table of strings.

function Comet:removeComponentByReference(entity,component)
	assert(entity.en_components[component.cm_cID] == component)												-- check the refs are right
	assert(component.cm_entities[entity.en_eID] == entity.en_eID)
	entity.en_components[component.cm_cID] = nil 															-- then remove them, entity no longer has this component
	component.cm_entities[entity.en_eID] = nil 																-- this component no longer used by this entity
	component.cm_entityCount = component.cm_entityCount - 1 												-- decrement the count
	self.cm_invalidComponents = self.cm_invalidComponents or {} 											-- instantiate invalid list if required
	self.cm_invalidComponents[component] = true 															-- any index with this component in is now invalid
	if component.cm_destructor ~= nil then 																	-- does this component have a destructor
		component.cm_destructor(entity) 																	-- then call it.
	end
end 

--//%	Convert a query to a list of required components. A query is a list of components that is required to be present.
--//	@componentList [string/table]		component name, table of names, comma seperated lists.
--//	@return 	   [table] 				array of component references.

function Comet:createQuery(componentList)
	if type(componentList) == "string" then  																-- convert a string to an array of strings.
		componentList = self:split(componentList)
	end
	if type(componentList[1]) == "table" then return componentList end 										-- already converted to object list.
	local query = {} 																						-- this is the resulting query.
	for i = 1,#componentList do 																			-- work through the array
		query[i] = self:getComponentByName(componentList[i])												-- convert component names to component references.
	end 
	return query
end

--//%	Optimise a query by sorting the components so the components most used are at the end. 
--//	@query 	[table]		query
--//	@return [table]		optimised query

function Comet:optimiseQuery(query)
	if #query > 1 then 																						-- if there are at least two lists.
		table.sort(query,function(a,b) return a.cm_entityCount < b.cm_entityCount end) 						-- sort so the component with the lowest entity count is first.
	end 
	return query
end 

--//%	Execute a query. This does two things - if a method is provided it calls method(entity). If an objectList is provided
--//	it adds the entity address to that object list, thus maintaing a list of such. So it can be used for executing 
--//	methods or querying the entity database.

--//	@query 	[table]		query, which may have been optimised, table of component references
--//	@method [function]	a method to be called on all successful matches (optional)
--//	@objectList [table]	a table which can contain all matching entities (optional)

function Comet:runQuery(query,method,objectList) 
	for _,eid in pairs(query[1].cm_entities) do  															-- work through all entities in the first component.
		local success = true 																				-- this flag tracks success/failure of the match.
		local testNumber = 2 																				-- start by checking 2
		while success and testNumber <= #query do 															-- while still okay, and not checked all components.
			if query[testNumber].cm_entities[eid] == nil then success = false end 							-- fail if the entity is not in that component's list.
			testNumber = testNumber + 1 																	-- go to the next test.
		end
		if success then 																					-- did it match ?
			if objectList ~= nil then objectList[#objectList+1] = self.cm_entities[eid] end  				-- if list provided add entity to list.
			if method ~= nil then method(self.cm_entities[eid],self) end 									-- if method provided call with entity
		end
	end
	return objectList
end 

--//%	Create a query key which is unique for each query
--//	@query 	[table]			Table of component references (note this is sorted by this method.)
--//	@return [string]		Unique key for query.

function Comet:createQueryKey(query)
	table.sort(query,function(a,b) return a.cm_cID < b.cm_cID end) 											-- sort the table on component id
	local key = "" 																							-- build a composite key out of the ids
	for _,compRef in ipairs(query) do key = key .. compRef.cm_cID end 										-- no separator because IDs are 10000 and up
	return key 																								-- return it.
end 

--//	Run a query as an AND selection of components. Uses cached query if available and valid. Cached queries are invalidated if their
--//	component list contains a component that has recently been added to or removed from an entity.
--//	@queryDef [string/table]		component name, table of names, comma seperated lists.
--//	@return 	[table]			array of matching entities

function Comet:query(queryDef)
	assert(queryDef ~= nil,"No query provided")
	local query = self:createQuery(queryDef) 																-- convert into table of component refs.
	local queryKey = self:createQueryKey(query) 															-- get the key
	return self:queryInternal(queryKey,query) 																-- run the query.
end 

--//%	Check the cache of queries and validate it, if ok then use it if not run the query.
--//	@queryKey 	[string]		key of query
--//	@query 		[table]			table of component references.
--//	@return 	[table]			array of matching entities

function Comet:queryInternal(queryKey,query)

	if self.cm_invalidComponents ~= nil then  																-- are there invalid components ?
		for key,cacheEntry in pairs(self.cm_queryCache) do 													-- work through all the cached entries
			for _,compRef in ipairs(cacheEntry.components) do 												-- scan each entry's components
				if self.cm_invalidComponents[compRef] ~= nil then 											-- if it is in the invalid list
					self.cm_queryCache[key] = nil 															-- clear that cache entry.
				end 
			end
		end
		self.cm_invalidComponents = nil  																	-- clear the invalid components list.
	end
	self.cm_cacheInfo.total = self.cm_cacheInfo.total + 1 	

	if self.cm_queryCache[queryKey] ~= nil then  															-- is there a valid cache entry.
		self.cm_cacheInfo.hits = self.cm_cacheInfo.hits + 1 												-- increment the successful hit count.
		return self.cm_queryCache[queryKey].result 															-- return the result part.
	end 

	query = self:optimiseQuery(query) 																		-- optimise the query.
	local entities = self:runQuery(query,nil,{})															-- run the query and store the results.

	local newCache = { components = {}, result = entities }													-- create a new cache entry.
	for _,compRef in ipairs(query) do newCache.components[#newCache.components+1] = compRef end 			-- copy used components into it.
	self.cm_queryCache[queryKey] = newCache 																-- put in the results cache.
	return entities
end

--//	Create a new system. preProcess and postProcess take a list of entities (from the query). update takes the entity reference
--//	and a reference to the Comet instance.
--//
--//	@componentList 	[table/string]		List of components, component names, comma seperated variables.
--//	@updateMethod 	[function/class]	Function called, or if a table, call table:update() [and table:preProcess/postProcess]
--//	@options 		[table] 			preprocess = <function> postprocess = <function>

function Comet:newS(componentList,updateMethod,options)
	assert(componentList ~= nil and componentList ~= "","No component list provided") 						-- must provide components to be system for.
	assert(updateMethod ~= nil,"No update method") 		
	local system = options or {} 																			-- start with the system options.
	system.updateMethod = updateMethod 																		-- store the update method.
	system.query = self:createQuery(componentList)															-- preconvert it.
	assert(#system.query > 0,"Empty component list for System query") 										-- must have at least something in it.
	self.cm_systems[#self.cm_systems+1] = system 															-- store in the systems table.

	return self:query(system.query)
end 

function Comet:process()
	local info = { manager = self }
	local time = system.getTimer() 																			-- work out delta time
	info.deltaTime = math.min(time - self.cm_lastTime,100) / 1000 											-- delta time is time since last ms, max 0.1s
	self.cm_lastTime = time 																				-- update last time.
	for _,system in ipairs(self.cm_systems) do self:runSystem(system,info) end 								-- run all systems.
end

function Comet:runSystem(system,info)
	local result = self:query(system.query)																	-- perform the query
	if #result == 0 then return end 																		-- there are no matching entities.

	if system.preprocess ~= nil then 																		-- preprocess method provided 
		system.preprocess(result)
	elseif type(system.updateMethod) == "table" and system.updateMethod.preprocess ~= nil then 				-- or call it as a class.
		system.updateMethod:preprocess(result,info)
	end

	for _,entity in ipairs(result) do 																		-- work through all entities in system
		if type(system.updateMethod) == "function" then 													-- is it a function ?
			system.updateMethod(entity,info) 																-- call it.
		else 
			system.updateMethod:update(entity,info) 														-- else call it as a method 
		end
	end

	if system.postprocess ~= nil then 																		-- postprocess method provided 
		system.postprocess(result)
	elseif type(system.updateMethod) == "table" and system.updateMethod.postprocess ~= nil then 			-- or call it as a class.
		system.updateMethod:postprocess(result,info)
	end
end 

return Comet

-- members should not be duplicates (or warn !) ?
-- only execute entities with an eID value - entities may have been deleted for some reason.
-- .format on members,
-- allow markers ?
