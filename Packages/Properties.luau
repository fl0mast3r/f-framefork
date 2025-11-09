--!strict

--[[
    Properties Module written by alex (@uid3v)
    Useful for getting all properties and it's values
    From Instance, or specific class name.

    Methods:
        Properties:GetProperties(): (class: Instance | string) -> (table, string?)
        Properties:HasProperty(): (class: Instance | string, property: string) -> (boolean, string?)
        Properties:GetAllClasses(): () -> (table, string?)
]]

type ClassData = {
    Superclass: string?,
    Properties: {string}?,
    Derived: { [string]: ClassData }?
}

type ClassesMap = { [string]: ClassData }
type InstancesMap = { [string]: {string?} }

local HttpService = game:GetService("HttpService")

local FILTERED_CLASS_TAGS = { NotCreatable = true, Service = true, Deprecated = true }
local FILTERED_PROPERTY_TAGS = { Hidden = true, NotScriptable = true, Deprecated = true }

local function try(fn: (...any) -> ...any, ...): (...any)
    local ok, res = pcall(fn, ...)
    return if ok then res else nil, not ok and res
end

local Properties = {
    _classes = {} :: ClassesMap,
    _instancesProperties = {} :: InstancesMap,
    _classList = {} :: {string?},
    
    _api = "https://tss-dev.ru" :: string,
    _initializing = false :: boolean,
    _initialized = false :: boolean,
}

--[=[
    Retrieves all properties and current values of an instance or class
    
    ```lua
    local instance = Instance.new("Part")
    local properties, err = Properties:GetProperties(instance)

    if not properties then
        warn("Failed to get properties: " .. err)
    else
        -- Fetching all property names
        local props = {}
        for name in pairs(properties) do
            table.insert(props, name)
        end

        -- Output: "Part properties: Name, Parent, Material, ..."
        print("Part properties: " .. table.concat(props, ", "))
    end
    ```

    @param class Target class
    @return { [string]: any } Table of Property pairs
    @return string? Error Message
]=]
function Properties.GetProperties(self: Properties, class: Instance | string): ({ [string]: any }, string?)
    if (not self._initialized) or (not self._instancesProperties) then
        return {}, "Properties are not initialized"
    end

    local name = if typeof(class) == "string" then class else class.ClassName
    local properties = self._instancesProperties[name] :: {}
    
    if not properties then
        return {}, `Unknown class: {name}`
    end
    
    local obj = if typeof(class) == "Instance" then class else nil
    local result = table.create(#properties) :: {}

    for _, property in pairs(properties) do
        if obj then
            local success, value = pcall(function()
                return (obj :: any)[property]
            end)

            result[property] = if success then value else nil
        else
            result[property] = nil
        end
    end
    
    return result, nil
end


--[=[
    Checks if a property exists on an instance or class

    ```lua
    local part = Instance.new("Part")
    local existing = Properties:HasProperty(part, "Transparency")
    
    if existing then
        -- If the property exists, modifying it
        part.Transpareny = math.random(0.5, 1)
    end
    ```

    @param class Target class
    @param property Property to check
    @return boolean Whether property exists
    @return string? Error Message
]=]
function Properties.HasProperty(self: Properties, class: Instance | string, property: string): (boolean, string?)
    if not self._initialized then
        return false, "Properties are not initialized"
    end

    local name = if typeof(class) == "string" then class else class.ClassName
    local properties = self._instancesProperties[name]

    if not properties then
        return false, `Unknown class: {name}`
    end

    for _, propName in ipairs(properties) do
        if propName == property then
            return true, nil
        end
    end

    return false, nil
end

--[=[
    Returns all class names in alphabetical order

    ```lua
    local classes = Properties:GetAllClasses()

    -- Looping through all classes
    for _, class in ipairs(classes) do
        local props = Properties:GetProperties(class)
        local propCount = 0

        -- Counting properties in class
        for _ in pairs(props) do
            propCount += 1
        end

        -- Output: "BasePart (30 properties), ..."
        print(class .. ` ({propCount} properties)`)
    end
    ```

    @return { string } Sorted list of classes
    @return string? Error Message
]=]
function Properties.GetAllClasses(self: Properties): ({string?}, string?)
    if not self._initialized then
        return {}, "Properties are not initialized"
    end

    if #self._classList == 0 then
        for name in ipairs(self._instancesProperties :: any) do
            table.insert(self._classList, name)
        end

        table.sort(self._classList)
    end

    return table.clone(self._classList), nil
end

function Properties._fetchApiDump(self: Properties): ({any}?, string?)
    local get, decode = HttpService.GetAsync, HttpService.JSONDecode

    local dump, derr = try(get, HttpService, `{self._api}/api-dump`)
    if not dump then
        return nil, "Failed to fetch API dump: " .. tostring(derr)
    end

    return try(decode, HttpService, dump)
end

function Properties._buildDerivedStructure(self: Properties, apiData: { [string]: any }): ({ [string]: any? }?)
    local result_data = table.create(#apiData.Classes) :: {{}?}

    for _, class_data: { [string]: any } in ipairs(apiData.Classes) do
        if class_data.Tags then
            local exclude = false

            for _, tag in ipairs(class_data.Tags) do
                if table.find(FILTERED_CLASS_TAGS, tag) then
                    exclude = true
                    break
                end
            end

            if not exclude then
                table.insert(result_data, class_data)
            end
        else
            table.insert(result_data, class_data)
        end
    end

    for _, result_class: any? in ipairs(result_data) do
        local className, superclassName = result_class.Name :: string, result_class.Superclass :: string
        local superclass = if superclassName ~= "<<<ROOT>>>" then superclassName else nil

        self._classes[className] = {
            Superclass = superclass,
            Properties = {},
            Derived = {}
        }

        for _, member in ipairs(result_class.Members) do
            if (member.MemberType == "Property") and (not FILTERED_PROPERTY_TAGS[member.Name]) then
                table.insert(self._classes[className].Properties :: {string}, member.Name)
            end
        end
    end

    local function convertClass(classData: any): (any)
        local result = {
            Properties = classData.Properties or {},
            Derived = {}
        }
        
        for derived_name, derived_data in pairs(classData.Derived) do
            result.Derived[derived_name] = convertClass(derived_data)
        end
        
        return result
    end

    local derivedStructure = {}
    for class_name, class_data in pairs(self._classes) do
        derivedStructure[class_name] = convertClass(class_data)
    end

    return derivedStructure
end

function Properties._buildPropertiesTable(self: Properties, derivedStructure: { [string]: any? })
    table.clear(self._instancesProperties)

    local function processType(typeName: string, typeData: any, parsedProps: {string}?): ({string}?)
        local currentProps = table.clone(typeData.Properties or {})
        local allProps = if parsedProps then table.clone(parsedProps) else {}

        for _, property in ipairs(currentProps) do
            if table.find(allProps, property) then
                continue
            end

            table.insert(allProps, property)
        end

        self._instancesProperties[typeName] = allProps
        
        if typeData.Derived then
            for derived_name, derived_data in pairs(typeData.Derived) do
                processType(derived_name, derived_data, allProps)
            end
        end

        return allProps
    end

    for class_name, class_data in pairs(derivedStructure) do
        processType(class_name, class_data)
    end

    return
end

function Properties._isInitialized(self: Properties): (boolean)
    if self._initialized then
        return true
    end
    
    if self._initializing then 
        repeat task.wait()
        until self._initialized 
        return true 
    end
    
    self._initializing = true
    local success, err = pcall(function()
        local apiData = self:_fetchApiDump() :: {}
        local derivedStructure = self:_buildDerivedStructure(apiData)

        if (apiData) and (derivedStructure) then
            self:_buildPropertiesTable(derivedStructure)
            self._initialized = true
        end
    end)
    
    self._initializing = false
    if not success then
        warn(`Properties module initialization failed: {err}`)
        return false
    end

    return true
end

type Properties = typeof(Properties)
task.spawn(function()
    Properties:_isInitialized()
end)

return Properties