--!strict

local Manager = {
    __services = {} :: {[string]: any},
}

function Manager.Get(self: Manager, name: string)
    return self.__services[name]
end

export type Manager = typeof(Manager)
return Manager