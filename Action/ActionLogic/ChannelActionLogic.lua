local Class = require("Tool.Class")
local ActionLogic = require("Action.ActionLogic.ActionLogic")

---@class ChannelActionLogic : ActionLogic
local ChannelActionLogic = Class("ChannelActionLogic", ActionLogic)

function ChannelActionLogic:_init(id)
    self.__base._init(self, id)
end

function ChannelActionLogic:HeartBeat(actionParam, deltaTime)
    local pCallBack = actionParam:GetCallBackFunctor()

    if pCallBack == nil then
        return false
    end

    if(false == pCallBack:CanDoThisActionInThisStatus(actionParam)) then
        return false
    end

    local nIntervalElapsed = actionParam:GetIntervalElapsed()
    local nContinuance = actionParam:GetContinuance()
    local nInterval = actionParam:GetInterval()
    local bRet = true

    if 500 > nInterval then
        nInterval = 2000
    end

    if deltaTime > nContinuance then
        deltaTime = nContinuance
    end

    nIntervalElapsed = nIntervalElapsed + deltaTime
    nContinuance = nContinuance - deltaTime

    if 0 > nContinuance then
        nContinuance = 0
    end

    actionParam:SetContinuance(nContinuance)
    
    while nIntervalElapsed >= nInterval do
        nIntervalElapsed = nIntervalElapsed - nInterval
        bRet = pCallBack:OnActivateEachTick(actionParam)
        if false==bRet then
            break
        end
    end
    actionParam:SetIntervalElapsed(nIntervalElapsed)
    return bRet
end

function ChannelActionLogic:OnDisturb(actionParam)
    local pCallBack = actionParam:GetCallBackFunctor()
    if pCallBack ~= nil then
        return pCallBack:OnDisturbForChanneling(actionParam)
    end
    return false
end

function ChannelActionLogic:OnInterrupt(actionParam)
    local pCallBack = actionParam:GetCallBackFunctor()
    if pCallBack ~= nil then
        return pCallBack:OnInterrupt(actionParam)
    end
    return false
end

return ChannelActionLogic