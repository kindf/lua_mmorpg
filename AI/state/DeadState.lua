local State = require("AI.State.State")
local Class = require("Tool.Class")
local Log = require("Tool.Log")

---@class DeadState:State
local DeadState = Class("DeadState", State)

function DeadState:StateLogic(pAI, uTime)
    Log.msg("DeadState::StateLogic -> AI_Logic_Dead")
    pAI:AI_Logic_Dead(uTime)
end

return DeadState