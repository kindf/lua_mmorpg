local State = require("AI.State.State")
local Class = require("Tool.Class")
local Log = require("Tool.Log")

---@class CombatState:State
local CombatState = Class("CombatState", State)
function CombatState:StateLogic(pAI, uTime)
    Log.msg("CombatState::StateLogic -> AI_Logic_Combat")
    pAI:AI_Logic_Combat(uTime)
end

return CombatState