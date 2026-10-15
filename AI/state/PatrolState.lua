local State = require("AI.State.State")
local Class = require("Tool.Class")
local Log = require("Tool.Log")

--巡逻状态
---@class PatrolState:State
local PatrolState = Class("PatrolState", State)
function PatrolState:StateLogic(pAI, uTime)
    Log.msg("PatrolState::StateLogic -> AI_Logic_Patrol")
    pAI:AI_Logic_Patrol(uTime)
end

return PatrolState