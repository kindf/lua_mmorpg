local Class = require("Tool.Class")
local C = require("Define.Constants")

---@class ActionLogic
local ActionLogic = Class("ActionLogic")

function ActionLogic:_init(id)
    self._id = id
end

function ActionLogic:GetLogicID(pAI)
    return self._id
end

function ActionLogic:IsPerformingSpecificSkill(actionParam, skillId)
end

function ActionLogic:IsPerformingSpecificScript(actionParam, scriptId)
end

function ActionLogic:HeartBeat(actionParam, deltaTime)
    return false
end

function ActionLogic:OnDisturb(actionParam)
    return false
end

function ActionLogic:OnInterrupt(actionParam)
    return false
end

return ActionLogic