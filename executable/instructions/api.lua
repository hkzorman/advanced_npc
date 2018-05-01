--
-- Created by IntelliJ IDEA.
-- Date: 3/8/18
-- Time: 2:06 PM
--
-- Global namespace
npc.programs.instr = {
    helper = {}
}
-- Private namespace
local _programs = {
    instr = {
        registered_instructions = {}
    }
}

-- Registration function
function npc.programs.instr.register(name, func)
    if _programs.instr.registered_instructions[name] ~= nil then
        npc.log("ERROR", "Attempted to register instrcution with name: "..dump(name)..".\nInstruction already exists.")
        return
    end
    _programs.instr.registered_instructions[name] = {func = func}
end

-- Execution function
function npc.programs.instr.execute(self, name, args)
    if _programs.instr.registered_instructions[name] == nil then
        npc.log("ERROR", "Attempted to execute instruction with name "..dump(name)..".\nInstruction doesn't exists.")
        return
    end
    -- Enqueue callbacks if any
    if npc.monitor.callback.exists(npc.monitor.callback.type.instruction, name) then
        -- Enqueue all callbacks for this instruction
        npc.monitor.callback.enqueue_all(self, npc.monitor.callback.type.instruction, name)
    end
    --npc.log("INFO", "Executing instruction '"..dump(name).."' with args:\n"..dump(args))
    return _programs.instr.registered_instructions[name].func(self, args)
end
