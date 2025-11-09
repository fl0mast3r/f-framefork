--!strict

local Manager = {
    __controllers = {} :: {[string]: any},
}

function Manager.Get(self: Manager, name: string)
    return self.__controllers[name]
end

export type Manager = typeof(Manager)
return Manager