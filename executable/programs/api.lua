--
-- User: hfranqui
-- Date: 3/8/18
-- Time: 2:06 PM
--

-- Global namespace
npc.programs = {}
-- Private namespace
local _programs = {
    registered_programs = {}
}

-- Registration function
function npc.programs.register(name, func)
    if _programs.registered_programs[name] ~= nil then
        npc.log("ERROR", "Attempted to register program with name: "..dump(name)..".\nProgram already exists.")
        return
    end
    _programs.registered_programs[name] = {func = func }
    npc.log("INFO", "Successfully registered program '"..dump(name).."'")
end

function npc.programs.is_registered(name)
    return _programs.registered_programs[name] ~= nil
end

-- Execution function
function npc.programs.execute(self, name, args)
    if _programs.registered_programs[name] == nil then
        npc.log("ERROR", "Attempted to execute program with name "..dump(name)..".\nProgram doesn't exists.")
        return
    end
    -- Enqueue callbacks if any
    if npc.monitor.callback.exists(npc.monitor.callback.type.program, name) then
        -- Enqueue all callbacks for this instruction
        npc.monitor.callback.enqueue_all(self, npc.monitor.callback.type.program, name)
    end
    --npc.log("INFO", "Executing program '"..dump(name).."' with args:\n"..dump(args))
    return _programs.registered_programs[name].func(self, args)
end