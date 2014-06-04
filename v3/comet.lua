--- ************************************************************************************************************************************************************************
---
---				Name : 		comet.lua
---				Purpose :	COMET (Component/Entity Framework for Corona/Lua), version 3.0
---				Created:	30 May 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s o:initialise(...) return o end, initialise = function() end }

local Comet, Component, Entity, Query, QueryCache, CachedQuery, System 							-- this to avoid fwd referencing issues.

--- ************************************************************************************************************************************************************************
--//	Comet class. This is the manager of the current set of entities, components and systems.
--- ************************************************************************************************************************************************************************

Comet = Base:new()

--//	Initialise the Comet object

function Comet:initialise()
	self.cm_components = {} 																	-- known components (ref => ref)
	self.cm_entities = {} 																		-- known entities (ref => ref)
	self.cm_systems = {} 																		-- known systems (index => ref)
	self.cm_invalidComponentList = nil 															-- components whose cached queries are now invalid (ref=>ref)
	self.cm_queryCache = QueryCache:new(self) 													-- create a query cache.
end 

--//	Delete the Comet object

function Comet:remove() 
	-- TODO: Delete all systems ?
	for k,v in pairs(self.cm_entities) do v:remove() end 										-- remove all entities
	for k,v in pairs(self.cm_systems) do v:remove() end 										-- remove all systems
	self.cm_queryCache:remove() 																-- remove query cache
	self.cm_components = nil self.cm_invalidComponentList = nil 								-- and tidy up.
	self.cm_entities = nil self.cm_queryCache = nil self.cm_systems = nil
end 

--//%	Given either a csv string, or a table of strings, convert it to a table of component references.
--//	@table 		[string/table]		csv strings or table of strings
--//	@return 	[table]				table of component references

function Comet:createList(table)
	local result = {}
	if type(table) == "table" then 																-- is it a table already ?
		for k,v in pairs(table) do result[k] = self:getComponentByName(v) end 					-- copy the components in.
	elseif type(table) == "string" then 														-- is it a string ?
		table = table .. "," 																	-- add a comma for regex
		while table ~= "" do 																	-- dismantle the string into pieces.
			local newComp
			newComp,table = table:match("^([%w%_]+)%,(.*)$") 									-- split about next comma
			result[#result+1] = self:getComponentByName(newComp) 								-- add reference to list
		end
	else
		error("Bad createList() source object")
	end
	return result
end

--//% 	A preprocessor for component list arguments - takes a variety of formats and converts them to a list of component references.
--//	@components [string, Component, table]	A name or CSV Names, a single component, or a list of components.

function Comet:processList(components)
	local result 
	if type(components) == "string" then 														-- if it is a string already ?
		result = self:createList(components)
	elseif type(components) == "table" then 													-- if it is a table ?
		if type(components[1]) == "string" then 												-- table of strings ?
			result = self:createList(components)
		end
		if type(components[1] == "table") then 													-- is it a table of tables ?
			result = components  																-- this for a table of references.
			if result.co_name ~= nil then result = { result } end 								-- this for a single component object.
		end
	end
	if result == nil then
		error("Unknown component list format")
	end
	return result
end 

--//	Find a component by name
--//	@name 	[string]				Name of required component
--//	@return [component]				Component object. Throws error on not found.

function Comet:getComponentByName(name)
	assert(name ~= nil and type(name) == "string","Bad component name") 
	name = name:lower() 																		-- case independent
	assert(self.cm_components[name] ~= nil,"Component does not exist ["..name.."]")				-- check it actually exists
	return self.cm_components[name]
end 

--//% 	When a component is added or removed from the cache, any query featuring it that has been cached becomes invalid.
--//	@component 	[component] 		Component added or removed.

function Comet:invalidateCache(component)
	self.cm_invalidComponentList = self.cm_invalidComponentList or {} 							-- create the list if needed
	self.cm_invalidComponentList[component] = component 										-- mark that component as not valid (entity add/removed it.)
end

--//%	Get the list of components that have been invalidated since the last call to this function (or the start). Components are 'invalidated' if they
--//	have been added to or removed from entities (hence, any cached list of entities that match those components are wrong)
--//	@return 	[table]				List of those components, nil if the list is empty

function Comet:getInvalidateCacheAndReset() 
	local invalidList = self.cm_invalidComponentList 											-- get the list (component => component)
	self.cm_invalidComponentList = nil															-- reset the list
	return invalidList 
end 

--//% 	Retrieve the query cache object address
--//	@return [QueryCache] 			QueryCache instance.

function Comet:getQueryCache() 
	return self.cm_queryCache 
end 

--//% 	Register a new system with comet
--//	@system 	[System]				System to be registered.

function Comet:registerSystem(system) 
	self.cm_systems[#self.cm_systems+1] = system 												-- add to system list
end 

--//	Update all systems.

function Comet:updateSystems()
	for _,system in ipairs(self.cm_systems) do 													-- work through all systems
		system:update()																			-- and update them.
	end 
end 

--//	Create a new component. Uses component.new effectively, but shorthand
--//	@name 		[string] 				Component Name (optional parameter, can be name in source table)
--//	@source 	[table/object]			Table, Class or Instance being used to create the component.

function Comet:newC(name,source)
	return Component:new(self,name,source) 														-- calls the component constructor.
end 

--//	Create a new entity. Uses entity.new effectively, but shorthand
--//	@name 		[string] 				Component Name (optional parameter, can be name in source table)
--//	@info 	 	[table/object]			Table, Class or Instance being used to create the component.

function Comet:newE(name,info)
	return Entity:new(self,name,info)
end 

--//	Create a new query. Uses CachedQuery.new effectively, but shorthand.
--//	@query 	 	[table/object]			Table, Class or Instance being used to create the query

function Comet:newQ(query)
	return CachedQuery:new(self,query)
end 

--//	Create a new System. Uses System.new
--//	@query  	[string, Component, table]	A name or CSV Names, a single component, or a list of query, that go to make up the query.
--//	@updater 	[function/table/class]		If a function, it is a standalone update, otherwise a collection of methods.

function Comet:newS(query,updater)
	return System:new(self,query,updater)
end 

--- ************************************************************************************************************************************************************************
--//	Component Class. This is a Hybrid system so Components and contain Methods, Message Recipients, Constructors, Destructors and anything else you like.
--//	Components are built out of tables containing member variables they use, functions they use, and requires (the components that are required), and 
--// 	a constructor and destructor method (the last three are optional). All methods are called with the first two parameters being self (the entity reference)
--//	and private (the components private members). Components can be constructed simply out of tables, or from classes. Constructors and Destructors do not
--//	take any parameters.
--- ************************************************************************************************************************************************************************

Component = Base:new()

--//	Component constructor. Takes a table containing members, functions, and optionsl require, constructor and destructor methods. Any member or function
--//	preceded with an underscore is not added to the component. 
--//	@comet 		[Comet]					Comet object being added to.
--//	@name 		[string] 				Component Name (optional parameter, can be name in source table)
--//	@info 	 	[table/object]			Table, Class or Instance being used to create the component.

function Component:initialise(comet,name,info)
	assert(comet ~= nil and type(comet) == "table" and comet.cm_components ~= nil,"Bad Comet")	-- Check the first parameter is a comet.
	if info ~= nil then 																		-- two parameters.
		assert(type(name) == "string","Component name must be a string") 						-- check the first is a string.
		self.co_name = name:lower() 															-- store the name in the component entry.
	else 
		info = name 																			-- otherwise the second parameter is the info structure
	end  																					
	assert(info ~= nil and type(info) == "table","Bad component definition parameter") 			-- check legality.

	self.co_comet = comet 																		-- save reference to commt
	self.co_requires = {} 																		-- list of required components by reference
	self.co_members = {} 																		-- table of members name => default value
	self.co_methods = {} 																		-- table of methods name => function
	self.co_entities = {} 																		-- hash of entities that use this component (ref->ref)
	self.co_instanceCount = 0 																	-- number of instances.

	self:addInfo(info) 																			-- add basic information from the source object.
	assert(self.co_name ~= nil and type(self.co_name) == "string","Bad component name")			-- check name is a string.
	self.co_name = self.co_name:lower() 														-- make it lower case as we are not case sensitive
	assert(comet.cm_components[self.co_name] == nil,											-- check component name duplicated.
									"Component name duplicated [" .. self.co_name .. "]") 		
	comet.cm_components[self.co_name] = self 													-- add the component into the manager's list of components.
end

--//%	Add the information from the given table to the new component.
--//	@source 	[table/object]			Table, class or instance being used to create it.

function Component:addInfo(info)
	for k,v in pairs(info) do 																	-- scan through the information structure
		if k:sub(1,1) ~= "_" then  																-- if the name does not begin with an underscore
			self:addItem(k,v)  																	-- add it to the component.
		end
	end 
	local mt = getmetatable(info) 																-- get the metatable.
	if mt ~= nil then 																			-- is there a metatable, then unless the coder is doing
		self:addInfo(mt) 																		-- something wierd, it's a superclass, so import those
	end 																						-- methods and members as well.

end

--//%	Add a single item to the new component, can be a table, function, string, number etc.
--//	@name 	[sstring] 					Member/Function etc. name
--//	@value 	[anything] 					What is going in.

function Component:addItem(name,value)
	if type(value) == "function" then 															-- functions are handled specially.
		if name == "constructor" or name == "destructor" then 									-- constructor or destructor ?
			assert(self["co_"..name] == nil,"Duplicate ".."name in component definition") 		-- each must only have one constructor/destructor
			self["co_"..name] = value 															-- store value in constructor/destructor part.
		elseif name ~= "new" and name ~= "initialise" then 										-- do not import new() or initialise() 
			self.co_methods[name] = value 														-- if neither, store in the methods table.
		end
	else
		if name == "requires" then 																-- is it a requires list ?
			self.co_requires = self.co_comet:createList(value) 									-- store a list of components in the requires entry.
		elseif name == "name" then 																-- is it the component name
			self.co_name = value 																-- then store that.
		else
			self.co_members[name] = value 														-- otherwise add it to the members list.
		end
	end 
end 

--//	Convert the component to a string
--//	@return 	[string] 				String representation of component.

function Component:toString()
	local s = "[Component] Name:" .. self.co_name .. " Reference:" .. tostring(self)
	if #self.co_requires > 0 then
		s = s .. " Requires:"
		for _,r in ipairs(self.co_requires) do s = s .. " " .. r.co_name end 
	end
	s = s .. "\nMembers:"
	for k,v in pairs(self.co_members) do s = s .. " " .. k .. "=" .. tostring(v) end
	if self.co_constructor ~= nil then s = s .. "\nConstructor: ".. tostring(self.co_constructor) end
	if self.co_destructor ~= nil  then s = s .. " Destructor: ".. tostring(self.co_destructor) end
	local m = ""
	for k,v in pairs(self.co_methods) do m = m .. " " .. k .. "=" .. tostring(v) end 
	if m ~= "" then s = s .. "\nMethods: " .. m end
	return s
end 

--- ************************************************************************************************************************************************************************
--//	An entity is a collection of components that can have things added to and removed from them arbitrarily to form working entities. An entity is class in its own
--//	right and as such could be subclassed to provide a factory for entities rather than using individual factory methods, or as part of a factory pattern.
--- ************************************************************************************************************************************************************************

Entity = Base:new()

--//	Entity constructor. Takes a parent comet object and a list of components, which is optional - empty entites are allowable, but don't make much sense.
--//	@comet 		[Comet]						comet object
--//	@initial 	[table] 					Initialisation values for members.
--//	@components [string, Component, table]	A name or CSV Names, a single component, or a list of components.

function Entity:initialise(comet,initial,components)
	self.en_components = {} 																	-- a list of components this entity has [comp ref => comp ref]
	self.en_comet = comet 																		-- save reference to comet object
	self.en_memberValues = initial or {} 														-- save the initialisation values.
	self.en_privateComponentStore = {} 															-- private storage for components
	comet.cm_entities[self] = self 																-- add into the known entities list.
	if components ~= nil then self:addC(components) end 										-- add the relevant components.
end 

--//	Remove an entire entity. Repeated removes are harmless.

function Entity:remove()
	if self.en_comet == nil then return end 													-- it already has been removed if there is no 'comet' reference.
	for k,v in pairs(self.en_components) do self:removeComponentByReference(v) end 				-- remove all components, call destructors etc.
	self.en_comet.cm_entities[self] = nil 														-- clear reference in comet's entity table.
	self.en_comet = nil self.en_components = nil self.en_memberValues = nil						-- and tidy up.
	self.en_privateComponentStore = nil
end 

--//	Add a collection of components (which may take various forms)
--//	@components [string, Component, table]	A name or CSV Names, a single component, or a list of components.
--//	@return 	[self] 						Chainable

function Entity:addC(components)
	components = self.en_comet:processList(components) 											-- convert to useable list.
	for k,v in ipairs(components) do self:addComponentByReference(v) end 						-- and add them all in.
end 

--//	Remove a collection of components, or a component from the entity.
--//	@components [string, Component, table]	A name or CSV Names, a single component, or a list of components.
--//	@return 	[self] 						Chainable

function Entity:remC(components)
	components = self.en_comet:processList(components) 											-- convert to useable list.
	for k,v in ipairs(components) do self:removeComponentByReference(v) end 					-- and remove them all.
end 

--//%	Add a single component by reference
--//	@component 	[component]		Reference to the component to add

function Entity:addComponentByReference(component)
	if self.en_components[component] ~= nil then return end 									-- if it is already there, we do not mind.
	-- print("Adding",component.co_name)
	self.en_components[component] = component 													-- add it in to the entity list
	component.co_entities[self] = self 															-- add it to the component's entity record
	component.co_instanceCount = component.co_instanceCount + 1 								-- increment component instance count
	self:initialiseMembers(component) 															-- initialise the members on this component
	self.en_comet:invalidateCache(component) 													-- invalidate the query cache for this component
	if component.co_requires ~= nil then 														-- add in any required components.
		self:addC(component.co_requires) 
	end
	if component.co_constructor ~= nil then 													-- call the constructor if there is one.
		self:methodCall(component,component.co_constructor) 
	end 		
end 

--//%	If the members for this component do not exist in the entity add them and load their initial values from
--//	the en_memberValues member.
--//	@component 	[Component]		Component to initialise members for.

function Entity:initialiseMembers(component)
	for k,v in pairs(component.co_members) do 													-- work through all the component members
		if self[k] == nil then 																	-- if not already defined 
			self[k] = v  																		-- define it.
			if self.en_memberValues[k] ~= nil then self[k] = self.en_memberValues[k] end 		-- override with the member initialiser value
		end
	end
end 

--//%	Remove a single component by reference
--//	@component 	[component]		Reference to the component to remove

function Entity:removeComponentByReference(component)
	assert(self.en_components[component] ~= nil,												-- however, we can only remove it once.
			"Component is not present and/or has already been removed [" .. component.co_name.."]")
	-- print("Removing",component.co_name)
	self.en_components[component] = nil 														-- remove it from the component list.
	component.co_entities[self] = nil 															-- remove it from the component's entity record
	component.co_instanceCount = component.co_instanceCount - 1 								-- decrement component instance count
	if component.co_destructor ~= nil then 														-- call the destructor if there is one.
		self:methodCall(component,component.co_destructor) 
	end 		
	self.en_privateComponentStore[component.co_name] = nil 										-- free the private storage.
	self.en_comet:invalidateCache(component) 													-- invalidate the query cache for this component
end 

--//%	Call an entity method. There are two parameters, the entity and its private informaton
--//	@component 	[component]		Component to call it on.
--//	@method 	[function]		The function to call.

function Entity:methodCall(component,method)
	if self.en_privateComponentStore[component.co_name] == nil then 							-- create components private information if needed
		self.en_privateComponentStore[component.co_name] = {}
	end
	method(component,self,self.en_privateComponentStore[component.co_name]) 					-- call the method.
end 

--//	Convert an entity to a string representation
--//	@return [string]	String representation of entity

function Entity:toString()
	if self.en_components == nil then return "[Entity] <Deleted>" end 
	local s = "[Entity] Components:"
	for k,v in pairs(self.en_components) do s = s .. " " .. v.co_name end 
	s = s .. "\nMembers:"
	for k,v in pairs(self) do 
		if type(v) ~=  "function" and k:sub(1,3) ~= "en_" then 
			s = s .. " " .. k .. "=" .. tostring(v) 
		end
	end
	return s 
end 

--- ***********************************************************************************************************************************************************************
--//								Non-cached query class. Maintains a query which is immutable, and calculates the result set.
--- ************************************************************************************************************************************************************************

Query = Base:new() 

--//	Prepare a query. Queries are immutable in terms of what they are querying on.
--//	@comet 		[Comet]						comet object
--//	@query  	[string, Component, table]	A name or CSV Names, a single component, or a list of query, that go to make up the query.

function Query:initialise(comet,query)
	if comet == nil then return end
	assert(comet ~= nil and type(comet) == "table" and comet.cm_entities ~= nil,"Bad Comet")-- Check the first parameter is a comet.
	self.qu_comet = comet 																	-- save comet.
	query = comet:processList(query) 														-- convert to useable list.
	assert(#query > 0,"Query must have at least one component to check")
	self.qu_query = query 																	-- save the query part.
	self.qu_size = #query 																	-- number of elements in the query.
end

--//	Clean up a query object.

function Query:remove()
	self.qu_comet = nil self.qu_query = nil self.qu_size = nil 								-- tidy up
end

--//	Execute a query.
--//	@return 	[table]			List of entities satisfying that query.

function Query:query() 	
	if self.qu_size > 1 then 																-- if more than one component, sort by instance size
		table.sort(self.qu_query,  															-- so when we scan we start with the smallest entity list.
						function(a,b) return a.co_instanceCount < b.co_instanceCount end)
	end 

	local result = {} 																		-- this is the result of the query.
	local firstLevel = self.qu_query[1].co_entities 										-- this is a list of entities present in the first level.
	for _,entity in pairs(firstLevel) do 													-- scan through all entities in the first level of the query
		local level = 2
		local isOk = true 
		while isOk and level <= self.qu_size do 											-- now check all the sub levels.
			isOk = self.qu_query[level].co_entities[entity] ~= nil 							-- ok if the component list at that level contains the entity we are checking.
			level = level + 1 																-- advance to next level.
		end 
		if isOk then result[#result+1] = entity end 										-- if matched, then add to the result set.
	end
	return result
end 

--- ***********************************************************************************************************************************************************************
--//	Query Cache. Maintains two tables, a cache of a result and a list of the components used in the query (in the keys of the table), and tracks whether the
--//	cached query can be reused.
--- ***********************************************************************************************************************************************************************

QueryCache = Base:new()

--//	Initialise the query cache.
--//	@comet 		[Comet]						comet object

function QueryCache:initialise(comet)
	self.qc_comet = comet 																	-- save commet reference
	self.qc_resultCache = {} 																-- query key to result cache.
	self.qc_queryComponents = {} 															-- query key to components in query (as keys)
	self.qc_queryCount = 0 self.qc_cacheHitCount = 0 										-- check effectiveness of caching.
end 

--//	Close and tidy up. Also (optionally using comment) prints the cache efficiency on the debug screen.

function QueryCache:remove()
	print(math.round(self.qc_cacheHitCount/self.qc_queryCount*100).." % cache hits")
	self.qc_comet = nil self.qc_resultCache = nil self.qc_queryComponents = nil 			-- tidy up
	self.qc_queryCount = nil self.qc_cacheHitCount = nil 
end 

--//	Cache access check. First it gets the list of the components that are invalid - i.e. have been added or removed from an entity (because any query
--//	featuring those components will have changed its result) and scans through the cache looking for queries that have any of those components
--//	they are consequently invalidated.
--//	@queryKey 	[string] 		Unique identifier for any query

function QueryCache:access(queryKey)
	local invalidList = self.qc_comet:getInvalidateCacheAndReset() 							-- get the changed components list and reset.
	if invalidList ~= nil then 
		for key,qComp in pairs(self.qc_queryComponents) do 									-- work through all the queries.
			for c,_ in pairs(invalidList) do  												-- work through the invalid list for each.
				if qComp[c] ~= nil then  													-- is the component present.
					self.qc_resultCache[key] = nil  										-- if so, invalidate the query.
					self.qc_queryComponents[key] = nil
					break 																	-- and break the loop, we don't need to check any more
				end
			end 
		end
	end 
	self.qc_queryCount = self.qc_queryCount + 1 											-- track caching effectiveness.
	if self.qc_resultCache[queryKey] ~= nil then self.qc_cacheHitCount = self.qc_cacheHitCount + 1 end
	return self.qc_resultCache[queryKey]													-- return the cached result, or nil if there is none.
end

--//	Update the key with a new result
--//	@queryKey 	 	 [string] 		Unique identifier for any query
--//	@queryResult 	 [table] 		List of entities from successful query
--//	@queryComponents [table]		List of components used in that query (component ref -> <true>)
function QueryCache:update(queryKey,queryResult,queryComponents)
	self.qc_resultCache[queryKey] = queryResult 											-- save result
	self.qc_queryComponents[queryKey] = queryComponents 									-- save components of query.
end 

--- ***********************************************************************************************************************************************************************
--//	Query which caches. This extends the normal always-calculate Query class, creating two extra members, a key which can be used to uniquely identify any
--//	query, and a table where the keys are the component references. The latter is so the query checker can answer the question very quickly, does this 
--//	query contains this component (by testing for the key existence)
--- ***********************************************************************************************************************************************************************

CachedQuery = Query:new()

--//	Prepare a cached query. Queries are immutable in terms of what they are querying on.
--//	@comet 		[Comet]						comet object
--//	@query  	[string, Component, table]	A name or CSV Names, a single component, or a list of query, that go to make up the query.

function CachedQuery:initialise(comet,query) 
	Query.initialise(self,comet,query)														-- do superclass
	local keyNames = {} 																	-- used convert query back to a list of names.
	self.qu_fastComponentCheck = {} 														-- a key is present for each component in the query - fast test.
	for i = 1,#self.qu_query do 															-- for each query
		keyNames[i] = self.qu_query[i].co_name  											-- get the key name.
		self.qu_fastComponentCheck[self.qu_query[i]] = true 								-- set the key in the fast test table.
	end
	table.sort(keyNames) 																	-- sort those names alphabetically.
	self.qu_queryKey = table.concat(keyNames,":")											-- make it a unique key for this query.
end 

--//	Execute a query, accessing the cache if there is something in the cache and it is still valud.
--//	@return 	[table]			List of entities satisfying that query.

function CachedQuery:query()
	local cacheResult = self.qu_comet:getQueryCache():access(self.qu_queryKey) 				-- try to read it from the cache.
	if cacheResult ~= nil then return cacheResult end 										-- if found, return it.
	local result = Query.query(self)														-- otherwise access the query the hard way.
	self.qu_comet:getQueryCache():update(self.qu_queryKey,result,self.qu_fastComponentCheck)-- update the cache using the string key, result, and fast
	return result
end

--//	Clean up a cached query object.

function CachedQuery:remove() 
	Query.remove(self) 																		-- call superclass destructor.
	self.qu_queryKey = nil self.qu_fastComponentCheck = nil									-- tidy up.
end 

--- ***********************************************************************************************************************************************************************
--		System Class. A system is basically a query - a collection of entities with common components, that have associated functions for preProcess, postProcess, and 
--		update.
--- ***********************************************************************************************************************************************************************

System = Base:new()

--//	System Constructor.
--//	@comet 		[Comet]						comet object
--//	@query  	[string, Component, table]	A name or CSV Names, a single component, or a list of query, that go to make up the query.
--//	@updater 	[function/table/class]		If a function, it is a standalone update, otherwise a collection of methods.

function System:initialise(comet,query,updater)
	assert(comet ~= nil and type(comet) == "table" and comet.cm_entities ~= nil,"Bad Comet")-- Check the first parameter is a comet.
	self.sy_comet = comet 																	-- save comet reference
	self.sy_query = CachedQuery:new(comet,query)											-- create a query.
	if type(updater) == "function" then 													-- is updater just a function.
		updater = { update = updater }														-- convert to one element table with an update function.
	end 
	assert(updater.update ~= nil,"No update() method for system")							-- if nothing else, there's an update method.
	self.sy_methods = updater 																-- save the methods.
	self.sy_comet:registerSystem(self) 														-- tell Comet about the new system.
	self.sy_lastUpdate = system.getTimer() 													-- last update (i.e. basically none)
end 

--//	Remove a system.

function System:remove() 
	self.sy_query:remove() 																	-- remove the query
	self.sy_query = nil self.sy_comet = nil self.sy_methods = nil 							-- and tidy up.
	self.sy_lastUpdate = nil self.deltaTime = nil
end 

--//	Update a system.

function System:update() 
	local result = self.sy_query:query() 
	if self.sy_methods.preProcess ~= nil then 												-- call pre-processing if present.
		self.sy_methods.preProcess(result)
	end 

	local time = system.getTimer()
	self.deltaTime = math.min(100,time - self.sy_lastUpdate) / 1000
	self.sy_lastUpdate = time

	for _,entity in ipairs(result) do 														-- call update on every entity.
		self.sy_methods.update(self.sy_comet,entity,self)
	end 

	if self.sy_methods.postProcess ~= nil then 												-- call post-processing if present.
		self.sy_methods.postProcess(result)
	end 
end 


return Comet 