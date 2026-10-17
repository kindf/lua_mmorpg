local Class = require("Tool.Class")

---@class ActionCallBack
local ActionCallBack = Class("ActionCallBack")

function ActionCallBack:IsPerformingSpecificSkill(rParams, nID) return false end


function ActionCallBack:IsPerformingSpecificScript(rParams, nID) return false end

function ActionCallBack:CanDoThisActionInThisStatus(rParams) return true end
function ActionCallBack:OnInterrupt(rParams) return false end
function ActionCallBack:OnActivateOnce(rParams) return false end
function ActionCallBack:OnActivateEachTick(rParams) return false end
function ActionCallBack:InterruptWhenDisturbed(rParams) return false end
function ActionCallBack:OnDisturbForCharging(rParams) return false end
function ActionCallBack:OnDisturbForChanneling(rParams) return false end
function ActionCallBack:ResetForNextAction(rParams) return false end

return ActionCallBack