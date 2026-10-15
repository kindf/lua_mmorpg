local State = require("AI.State.State")
local Class = require("Tool.Class")
local Log = require("Tool.Log")

-- 待机状态
---@class IdleState : State
local IdleState = Class("IdleState", State)

function IdleState:StateLogic(pAI, uTime)
    pAI:AI_Logic_Idle(uTime)
end

return IdleState