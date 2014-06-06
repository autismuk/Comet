--- ************************************************************************************************************************************************************************
--- ************************************************************************************************************************************************************************
---
---				Name : 		comet.lua
---				Purpose :	COMET (Component/Entity Framework for Corona/Lua), version 4.1
---				Created:	3rd June 2014
---				Author:		Paul Robson (paul@robsons.org.uk)
---				License:	MIT
---
--- ************************************************************************************************************************************************************************
--- ************************************************************************************************************************************************************************

-- Standard OOP (with Constructor parameters added.)
_G.Base =  _G.Base or { new = function(s,...) local o = { } setmetatable(o,s) s.__index = s o:initialise(...) return o end, initialise = function() end }

local Comet, Component, Entity, Query, QueryCache, System, AbstractSystemClass 					-- this to avoid fwd referencing issues.

--- ************************************************************************************************************************************************************************
--//	The Comet class is a factory class and instance storage class. It can be used to create Components, Entities and Systems, and keeps instance records of the 
--//	various things so that they can be accessed easily.
--- ************************************************************************************************************************************************************************

local Comet = Base:new() 																		-- create Comet Class

--//	Comet constructor.

function Comet:initialise() 
	self.components = {} 																		-- hash of known components, keyed on the component name.
	self.entities = {} 																			-- hash of entities, keyed on the entity reference (key = value)
	self.systems = {} 																			-- array of references to created systems.
	self.systemInfo = {} 																		-- information used in systems
	self.queryCache = QueryCache:new() 															-- cache for queries.
	self.isAutomatic = false 																	-- true when the RTEL enterFrame is used by this object.
	self.lastUpdate = 0 																		-- time of last update
	self.terminate = false 																		-- should Comet terminate itself ?
	self.inUpdate = false 																		-- true when updating.
end

--//	Comet close and tidy up.

function Comet:remove()
	if self.inUpdate then self.terminate = true return end 										-- if updating terminate after we have finished.
	self:stopAutomatic() 																		-- remove the RTEL if there is one.
	for _,entity in pairs(self.entities) do entity:remove() end 								-- remove all the entities
	for _,system in pairs(self.systems) do system:remove() end 									-- remove all the systems.
	self.components = nil self.queryCache = nil self.isAutomatic = nil 							-- tidy up.
	self.entities = nil self.systems = nil self.systemInfo = nil self.terminate = nil
	self.inUpdate = nil self.lastUpdate = nil
end 

--//	Call methods on all systems in the Framework. This can be called automatically using the runAutomatic() method.

function Comet:update()
	self.inUpdate = true 																		-- we are updating
	local currentTime = system.getTimer() 														-- get the current time.
	self.systemInfo.deltaClock = math.min(100,currentTime - self.lastUpdate)					-- work out deltaClock value (elapsed time in ms)
	self.systemInfo.deltaTime = self.systemInfo.deltaClock / 1000 								-- work out deltaTime value (elapsed time in s)
	self.lastUpdate = currentTime 																-- update current time.
	for i = 1,#self.systems do self.systems[i]:runUpdate() end  								-- update all known systems.
	self.inUpdate = false 																		-- no longer updating.
	if self.terminate then self:remove() end 													-- if terminated during this then remove itself.
end 

--//%	enterFrame event handler.

function Comet:enterFrame()
	self:update()
end 

--//	Make systems run automatically by calling update on the EnterFrame Runtime Event Listener

function Comet:runAutomatic()
	if not self.isAutomatic then 
		Runtime:addEventListener("enterFrame",self)
		self.isAutomatic = true
	end
end 

--//	Stop systems from running automatically by calling update on the EnterFrame Runtime Event Listener

function Comet:stopAutomatic()
	if self.isAutomatic then 
		Runtime:removeEventListener("enterFrame",self)
		self.isAutomatic = false
	end
end 

--//%	Convert a string, single instance of component, or list of components or names into a list of components. This is a generic preprocessor
--//	for methods which have a component or component list as a parameter.
--//	@comp 	[<components>]	Components either as a CSV list, a list of strings, a component reference, or a list of component references.
--//	@return [table] 		Array of component references.

function Comet:processComponentList(comp) 
	if comp == nil or comp == "" then return {} end 											-- is it an empty list or string, then return an empty list
	if type(comp) == "string" then 																-- is it text, therefore it is a list of names or a name
		local result = {} 																		-- so convert it to a physical list of names.
		comp = comp .. "," 																		-- add a comma for regex
		while comp ~= "" do 																	-- dismantle the string into pieces.
			local newComp
			newComp,comp = comp:match("^([%w%_]+)%,(.*)$") 										-- split about next comma
			result[#result+1] = newComp 														-- add name to list
		end
		comp = result 																			
	end 
	if type(comp) == "table" and comp._cInfo ~= nil then 										-- is it a single component object ?
		comp = { comp } 																		-- make it into a one element array.
	end 
	local result = {} 																			-- finally, convert strings to component references 
	for i = 1,#comp do 																			-- work through the list
		local v = comp[i] 																		-- get the component.
		if type(v) == "string" then 															-- if it is a component name.
			v = v:lower() 																		-- case doesn't matter.
			assert(self.components[v] ~= nil,"Component does not exist ".. v) 					-- check the component does exists
			v = self.components[v] 																-- and v becomes a reference to it.
		end 
		result[i] = v 																			-- store in result table
	end
	return result
end 


--//	Create a new component using the given name (optional) and definition.The definition is a class or table containing
--//	member values for the component, functions for the component, and optionally may contain constructors, destructors and 
--//	a requires list.
--//	@name 	[string]		Component name, optional. If not present will be given an arbitrary name.
--//	@def 	[table/class]	Component Definition
--//	@return [component]		Reference to component.

function Comet:newC(name,def)
	return Component:new(self,name,def) 																
end 

--//	Create a new entity, using the optional components list given.
--//	@comp 	[<components>]	Components either as a CSV list, a list of strings, a component reference, or a list of component references.
--//	@values [table] 		Hash of initial values of specified data (optional)
--//	@return [entity] 		A new entity object.

function Comet:newE(comp,values)
	return Entity:new(self,comp,values)
end 

--//	Create a new Query.
--//	@comp 	[<components>]	Components either as a CSV list, a list of strings, a component reference, or a list of component references.
--//	@return [Query]			Reference to query object

function Comet:newQ(comp)
	return Query:new(self,comp)
end 

--//	Create a new System.
--//	@comp 	[<components>]	Components either as a CSV list, a list of strings, a component reference, or a list of component references.
--//	@update [function]		Update function.
--//	@methods [table]		Table of other methods
--//	@return [System]		Reference to system object

function Comet:newS(comp,update,methods)
	return System:new(self,comp,update,methods)
end 

--//	Install an external library. The library should return an object with three methods, installComponents, installEntities and installSystems
--//	that take a comet object as a parameter.
--//	@luaFile	[string]	Lua file name in require() format (e.g. "system.demo" ==> system/demo.lua)

function Comet:newL(luaFile)
	local src = require(luaFile)
	if src.installComponents ~= nil then src:installComponents(self) end
	if src.installEntities ~= nil then src:installEntities(self) end
	if src.installSystems ~= nil then src:installSystems(self) end
end 

--//	Get a base class for creating System classes
--//	@return [Class]			Class which can be subclassed to create a system class.

function Comet:getSystemClass()
	return AbstractSystemClass 
end 

--- ************************************************************************************************************************************************************************
--//	Component class. A component class is a bag of data with optional methods that operate on that data, additionally a component can have a constructor, destructor
--//	and private memory (per instance or per component)
--- ************************************************************************************************************************************************************************

Component = Base:new()

Component.reservedMixins = { requires = 1, constructor = 1, destructor = 1 }					-- known reserved mixin words.

--//%	Component constructor
--//	@comet 	[Comet]			Owning Comet object
--//	@name 	[String]		Name of component (optional)
--//	@def 	[table]			Component definition

function Component:initialise(comet,name,def) 																
	assert(comet ~= nil and comet.newC ~= nil,"Bad comet parameter")							-- Validate parameters
	if def == nil then  																		-- if only two parameters, e.g. no name
		def = name 																				-- the 'name' (2nd parameter is actual the definition)
		name = tostring(self):gsub("table%:%s","@") 											-- use the table reference to make a unique component name.
	end 
	def = def or {} 																			-- no actual definition is required for marker types
	assert(name ~= nil and type(name) == "string" and type(def) == "table","Bad parameter") 	
	assert(name:match("^[a-z][a-z0-9%_]*$") ~= nil,												-- check name of component is a legal lua identifier and l/c
							"Component name should be legal lua variable "..name)
	name = name:lower() 																		-- name is case insensitive
	assert(comet.components[name] == nil,"Duplicate component " .. name) 						-- check it doesn't already exist 
	self._cInfo = { name = name, mixins = def, entities = {}, instanceCount = 0, 				-- this is the information that goes int e component
																			comet = comet }
	self._cInfo.constructor = def.constructor  													-- copy constructor, destructor, requires into the info structure.
	self._cInfo.destructor = def.destructor 
	self._cInfo.requires = comet:processComponentList(def.requires) 							-- create requires list entry.
	comet.components[name] = self 																-- store in the component hash, keyed on the name.
end

--//	Convert component definition to string, for debugging
--//	@return 	[string]		String representation of component.

function Component:toString() 
	local s = "[Component] Name:" .. self._cInfo.name .. " Instances:" .. self._cInfo.instanceCount 
	if self._cInfo.requires ~= nil and #self._cInfo.requires > 0 then 
		s = s .. " Requires:"
		for _,comp in ipairs(self._cInfo.requires) do s = s .. comp._cInfo.name .. " " end 
	end
	s = s .. " Mixin:"
	for k,v in pairs(self._cInfo.mixins) do 
		if k ~= "requires" then
			s = s .. k .. "=" .. tostring(v).." "
		end
	end 
	return s
end 

--- ************************************************************************************************************************************************************************
--//	Entity Class. Entities are collections of components that are built as requested. Components can be added or removed at will
--- ************************************************************************************************************************************************************************

Entity = Base:new()

--//	Entity constructor
--//	@comet 	[Comet]			Owning Comet object
--//	@comp 	[<components>]	Components either as a CSV list, a list of strings, a component reference, or a list of component references (optional)
--//	@values [table] 		Hash of initial values of specified data (optional)

function Entity:initialise(comet,comp,values) 
	assert(comet ~= nil and comet.newC ~= nil,"Bad comet parameter")							-- Validate parameters
	local eInfo = { components = {}, comet = comet, values = values or {} } 					-- list of things stored in the entity.
	self._eInfo = eInfo  																		-- store appropriately.
	if comp ~= nil then self:addC(comp) end 													-- add components if provided
	comet.entities[self] = self 																-- add to comet entities list
end

--//	Remove the entity components and then mark as removed/

function Entity:remove()
	for _,comp in pairs(self._eInfo.components) do self:remComponentByReference(comp,true) end 	-- remove all components.
	self._eInfo.comet.entities[self] = nil  													-- remove from comet entities list
	self._eInfo = nil 																			-- remove eInfo to mark it dead.
end 

--//	Add a component or components to the entity
--//	@comp 	[<components>]	Components either as a CSV list, a list of strings, a component reference, or a list of component references.

function Entity:addC(comp)
	comp = self._eInfo.comet:processComponentList(comp) 										-- process the component list.
	for i = 1,#comp do self:addComponentByReference(comp[i]) end 								-- add the components
end 

--//	Remove a component or components from the entity
--//	@comp 	[<components>]	Components either as a CSV list, a list of strings, a component reference, or a list of component references.

function Entity:remC(comp) 
	comp = self._eInfo.comet:processComponentList(comp) 										-- process the component list.
	for i = 1,#comp do self:remComponentByReference(comp[i]) end 								-- add the components
end 

--//%	Add a single component by reference
--//	@comp 	[Component]		Component reference to add

function Entity:addComponentByReference(comp)
	if self._eInfo.components[comp] ~= nil then return end 										-- if it is already present, do nothing
	--print("adding ",comp._cInfo.name)
	local cName = comp._cInfo.name 																-- get component name
	self[cName] = {} 																			-- initialise component store
	local table = comp._cInfo.mixins 															-- work through the mixins
	while table ~= nil do  																		-- until completed
		for k,v in pairs(table) do  															-- work through this level mixins
			if k:match("^_") == nil and k ~= "requires" and k ~= "constructor"					-- don't include anything with _, requires, or anything already present.
										and k ~= "destructor" and self[cName][k] == nil then 	-- or constructors or destructors 				
				self[cName][k] = v 																-- add to the entity
				if type(v) ~= "function" and self._eInfo.values[cName] ~= nil then 				-- if it is not a function and there is local data.
					self[cName][k] = self._eInfo.values[cName][k] or v 							-- then the values override it.
				end
			end
		end 
		table = getmetatable(table) 															-- go to the parent metatable
	end
	local req = comp._cInfo.requires 															-- access requires.
	self._eInfo.components[comp] = comp 														-- add to components hash in entity
	comp._cInfo.entities[self] = self 															-- add to entity hash in components
	comp._cInfo.instanceCount = comp._cInfo.instanceCount + 1 									-- increment instance count
	local qc = self._eInfo.comet.queryCache 													-- access query cache
	if qc ~= nil then qc:invalidate(comp) end 	 												-- invalidate any cache with this component
	for i = 1,#req do self:addComponentByReference(req[i]) end 									-- add them recursively (here to stop recursion loop)
	if comp._cInfo.constructor ~= nil then self:executeMethod(comp._cInfo.constructor,comp) end -- call component constructor
end 

--//%	Remove a single component by reference
--//	@comp 	[Component]		Component reference to remove
--//	@enforce [boolean]		If true does not check that the component is required (for erasing entity, do not use normally)

function Entity:remComponentByReference(comp,enforce)
	assert(self._eInfo.components[comp] ~= nil,"Component not present in entity " .. comp._cInfo.name)
	enforce = enforce or false 																	-- enforce defaults to false.
	if not enforce then 																		-- if not enforcing testing
		for _,component in pairs(self._eInfo.components) do 									-- for each component
			if component ~= comp then  															-- if not the one being removed.
				local requires = component._cInfo.requires 										-- get the requires
				for i = 1,#requires do  														-- check that they are not needed.
					assert(requires[i] ~= comp,component._cInfo.name .. " requires "..comp._cInfo.name .. " component")
				end
			end
		end
	end
	-- print("removing ",comp._cInfo.name)
	if comp._cInfo.destructor ~= nil then self:executeMethod(comp._cInfo.destructor,comp) end 	-- call component destructor
	self._eInfo.components[comp] = nil 															-- remove from components hash in entity
	comp._cInfo.entities[self] = nil 															-- remove from entity hash in components
	comp._cInfo.instanceCount = comp._cInfo.instanceCount - 1 									-- decrement instance count
	self[comp._cInfo.name] = nil 																-- clear out members for this component.
	local qc = self._eInfo.comet.queryCache 													-- access query cache
	if qc ~= nil then qc:invalidate(comp) end 	 												-- invalidate any cache with this component
end 

--//%	Execute a method in the entity, on a given component. The method is given the entity as its 'self' object. 
--//	@method 		[function]	method to call
--//	@component 		[Component]	Component part of entity it is to be used on

function Entity:executeMethod(method,component)
	self._eInfo.currComponent = component 														-- identify component being acted on.
	method(self) 																				-- call it.
	self._eInfo.currComponent = nil 															-- clear component being acted on.
end 

--//	Check to see if the entity has not been removed - removed entities can appear if entities have been removed in updates
--//	@return 	[boolean]	true if still alive

function Entity:isAlive() 
	return self._eInfo ~= nil  																	-- this is how we detect it.
end 

--//	Get Comet Reference used by this Entity
--//	@return 	[Comet]			Owning Comet object

function Entity:getComet()
	return self._eInfo.comet  																	-- return Comet owner reference.
end 

--//	Get System Information
--//	@return 	[table]			System Information Table

function Entity:getInfo() 
	return self:getComet().systemInfo 															-- return system information (dt initially)
end 

--//	Get a table to use for private storage which is shared amongst components.
--//	@return 	[table]			Private data store

function Entity:getComponentData() 
	local comp = self._eInfo.currComponent 														-- access the current component
	comp._cInfo.privateStore = comp._cInfo.privateStore or {} 									-- create its private store if required
	return comp._cInfo.privateStore 															-- return it.
end 

--//	Retrieve the values used when constructing the entity.
--//	@return 	[table]			table of names => values

function Entity:getCreateValues()
	return self._eInfo.values 
end 

--//	Convert Entity to String form
--//	@return [string] 	entity as string.

function Entity:toString()
	local s = "[Entity] Ref:" .. tostring(self):sub(8) .. " Components:"
	for _,comp in pairs(self._eInfo.components) do 
		s = s .. comp._cInfo.name .. " [ " 
		for k,v in pairs(self[comp._cInfo.name]) do s = s .. k .. "=" .. tostring(v) .. " " end
		s = s .. "] "
	end
	return s
end 

--- ************************************************************************************************************************************************************************
--//	A Query class, that does an 'and' query on the presence of one of more components.
--- ************************************************************************************************************************************************************************

Query = Base:new()

--//	Query constructor
--//	@comet 	[Comet]			Owning Comet object
--//	@comp 	[<components>]	Components either as a CSV list, a list of strings, a component reference, or a list of component references (optional)

function Query:initialise(comet,comp)
	assert(comet ~= nil and comet.newC ~= nil,"Bad comet parameter")							-- Validate parameters
	assert(comp ~= nil,"Bad component list for query")
	self.comet = comet 																			-- save comet reference.
	self.componentList = self.comet:processComponentList(comp) 									-- process the component list.
	self.components = {} 																		-- components is a hash keyed on the component reference.
	local names = {}																			-- list of names
	table.sort(self.componentList,function(c1,c2) return c1._cInfo.name < c2._cInfo.name end) 	-- sort alphabetically on component name.
	for i = 1,#self.componentList do 															-- scan them all
		self.components[self.componentList[i]] = self.componentList[i]  						-- set up the existence hash
		names[i] = self.componentList[i]._cInfo.name 											-- get the name
	end
	table.sort(names)																			-- sort the names table, thus the key order doesn't matter.
	self.queryKey = table.concat(names,":") 													-- build a query key.
end 

--//	Remove a query.

function Query:remove()
	self.comet = nil self.componentList = nil self.components = nil
end

--//	Evaluate a query, using the cache if there is one defined.
--//	@return [array]		array of entities matching the query.

function Query:evaluate()
	if #self.componentList == 0 then return {} end 												-- no components provided, so return an empty list.
	if self.comet.queryCache ~= nil then 														-- anything in the cache
		local result = self.comet.queryCache:read(self.queryKey) 								-- get it
		if result ~= nil then return result end 												-- return it if something available.
	end 
	table.sort(self.componentList,																-- sort the componenent keys on their instance count
				function(c1,c2) return c1._cInfo.instanceCount < c2._cInfo.instanceCount end)	-- so we do the one with the fewest keys as an outer.
	local result = {} 																			-- this is where the query results go.
	if self.componentList[1]._cInfo.instanceCount > 0 then  									-- if the list is not empty, then....
		local firstList = self.componentList[1]._cInfo.entities 								-- a hash of the entities using that component.
		for _,ent1 in pairs(firstList) do 														-- scan through that hash.
			local canAdd = true 																-- initially, can add.
			for i = 2,#self.componentList do 													-- work through the remaining test components
				if self.componentList[i]._cInfo.entities[ent1] == nil then  					-- if req'd component absence
					canAdd = false 																-- then can't add, break loop
					break
				end 
			end
			if canAdd then result[#result+1] = ent1 end 										-- if everything passed, then add the result.
		end
	end 
	if self.comet.queryCache ~= nil then  														-- if the cache is there	
		self.comet.queryCache:update(self.queryKey,self.components,result) 						-- update it with this new result 
	end
	return result
end 

--//	Convert a query to a string
--//	@return 	[string] 	text description of query

function Query:toString()
	return "[Query] "..tostring(self).." Components:" ..self.queryKey:gsub("%:",",")
end 

--- ************************************************************************************************************************************************************************
--//	Query Cache class, caches query results and tracks them becoming invalid as components are added and removed.
--- ************************************************************************************************************************************************************************

QueryCache = Base:new()

--//%	Query Cache constructor

function QueryCache:initialise()
	self.results = {} 																			-- query results (text key => result list)
	self.refersTo = {} 																			-- query parts (text key => table { component => component })
	self.invalidTable = nil 																	-- invalidated components (ref => ref)
	self.queryCount = 0 																		-- tracking success.
	self.hitCount = 0
end 

--//%	Read an item from the cache if it's there, first checking to see if queries have been invalidated.
--//	@queryKey	[string]	Text Query Key
--//	@return 	[table]		Cached query result or nil if none available.

function QueryCache:read(queryKey)
	if self.invalidTable ~= nil then  															-- are there entries in the invalidity table ?
		for _,comp in pairs(self.invalidTable) do self:invalidComponent(comp) end  				-- for each, invalidate queries with that component in.
		self.invalidTable = nil 																-- those components have been allowed for, clear invalid table.
	end 
	self.queryCount = self.queryCount + 1
	if self.results[queryKey] ~= nil then self.hitCount = self.hitCount + 1 end
	return self.results[queryKey] 																-- return a cached query or nil if there is one.
end 

--//%	Invalidate all queries with a given component
--//	@component 			[Component]	Reference of a component whose query has become invalid.

function QueryCache:invalidComponent(comp)
	for key,refers in pairs(self.refersTo) do 													-- check all refers to entries for this component reference 
		if refers[comp] ~= nil then  															-- if found
			self.results[key] = nil 															-- kill the cache entry.
			self.refersTo[key] = nil
		end 
	end
end 

--//%	Update the query cache with a new result
--//	@queryKey			[string]	Text Query Key
--//	@queryComponents	[table]		Hash of components in query (compref => compref)
--//	@result 			[table]		Result of query

function QueryCache:update(queryKey,queryComponents,result)
	self.results[queryKey] = result  															-- update with result
	self.refersTo[queryKey] = queryComponents 													-- update with result parts.
end 

--//%	Add an invalidated component to the cache's invalid table.
--//	@component 			[Component]	Reference of a component whose query has become invalid.

function QueryCache:invalidate(component)
	self.invalidTable = self.invalidTable or {} 												-- create invalid table if needed.
	self.invalidTable[component] = component 													-- put the newly invalid component in the invalid table
end 

--- ************************************************************************************************************************************************************************
--// Systems are a query with associated methods, those methods are run on the queries at regular intervals. This can be done individually, as a group, or automatically
--// via a runtime event listener attached to the comet object.
--- ************************************************************************************************************************************************************************

System = Base:new()

--//% 	Create a new system, it is automatically added to the system list in the comet object
--//	@comet 	[Comet]			Owning Comet object
--//	@query 	[<components>]	Components either as a CSV list, a list of strings, a component reference, or a list of component references (optional)
--//	@update [function]		Update function.
--//	@methods[table] 		Table of system methods that are available

function System:initialise(comet,query,update,methods)
	if comet == nil then return end 															-- used as prototype.
	assert(comet ~= nil and comet.newC ~= nil,"Bad comet parameter")							-- Validate parameters
	assert(update ~= nil,"No update function")
	self.comet = comet  																		-- save the system information,
	self.query = comet:newQ(query)
	self.updateMethod = update
	self.methods = methods or {}
	comet.systems[#comet.systems+1] = self 														-- add system to the systems list.
end 

--//%	Private system remove - does not tidy the table in the comet object, don't use it.

function System:remove()
	self.comet = nil self.query = nil self.updateMethod = nil self.methods = nil 
end 

--//%	Run the update on a system

function System:runUpdate()
	local result = self.query:evaluate() 														-- calculate the result
	self:runMethod("preProcess",result) 														-- run before
	self:update(result) 																		-- update all entities in system
	self:runMethod("postProcess",result) 														-- run before
end

--//%	Run a method passing the whole result list as a parameter.
--//	@methodName 	[string]		Method name to check (checks both as done, and all l/c)
--//	@result 		[array]			Array of matching entities

function System:runMethod(methodName,result)
	local mt = self.methods[methodName] or self.methods[methodName:lower()] 					-- check for name and l/c name 
	if mt ~= nil then mt(result) end 															-- if it exists, run it
end 

--//%	Update a system using a given entity List
--//	@entityList 	[array]			Array of matching entities

function System:update(entityList)
	for i = 1,#entityList do 																	-- scan through the list
		if entityList[i]:isAlive() then self.updateMethod(entityList[i]) end  					-- it is possible to delete entities in the list, so check alive.
	end
end

--- ************************************************************************************************************************************************************************
--//	This is a system which you can create by subclassing.
--- ************************************************************************************************************************************************************************

AbstractSystemClass = System:new()

--//% 	Create a new system, it is automatically added to the system list in the comet object
--//	@comet 	[Comet]			Owning Comet object
--//	@query 	[<components>]	Components either as a CSV list, a list of strings, a component reference, or a list of component references (optional)
--//	@methods[table] 		Table of system methods that are available

function AbstractSystemClass:initialise(comet,query,methods)
	System.initialise(self,comet,query,self.update,methods) 									-- call super constructor with self.update as the update method.
end 

--//	This is the method that must be subclassed if you use Abstract System Classes.
--//	@entityList [array]		Array of entity lists.

function AbstractSystemClass:update(entityList)
	error("AbstractSystemClass is abstract and must be subclassed")
end 

return Comet 

--- ************************************************************************************************************************************************************************
--//	This is a class which instantiates standard components.
--- ************************************************************************************************************************************************************************

-- TODO Creating entities from a JSON, returning a structure. 
-- TODO Nameable entities ?
-- TODO ext to reserved words (why ????)
-- TODO Collision (Rough)
-- TODO Synonym components ?
-- TODO Timer Components, simple and complex.
-- TODO Broadcast messaging system (listener)
-- TODO Standard colour components, position, velocity, size, anchor , coronaobject
-- TODO Endless, Long particle effects
-- TODO Some Corona Objects
-- TODO Collision (Spatial)