local Class = require("Tool.Class")

---@class ActionParam
local ActionParam = Class("ActionParam")

function ActionParam:_init()
    self:Reset()
end

function ActionParam:Reset()
    self.m_nContinuance = 0
    self.m_nInterval = 0
    self.m_nIntervalElapsed = 0
    self.m_pActor = nil
    self.m_pCallBack = nil
end

function ActionParam:GetContinuance()
    return self.m_nContinuance
end

function ActionParam:SetContinuance(nTime)
    self.m_nContinuance = nTime
end

function ActionParam:GetInterval()
    return self.m_nInterval
end

function ActionParam:SetInterval(nTime)
    self.m_nInterval = nTime
end

function ActionParam:GetIntervalElapsed()
    return self.m_nIntervalElapsed
end

function ActionParam:SetIntervalElapsed(nTime)
    self.m_nIntervalElapsed = nTime
end

function ActionParam:GetActor()
    return self.m_pActor
end

function ActionParam:SetActor(pActor)
    self.m_pActor = pActor
end

function ActionParam:GetCallBackFunctor()
    return self.m_pCallBack
end

function ActionParam:SetCallBackFunctor(rCallBack)
    self.m_pCallBack = rCallBack
end

return ActionParam