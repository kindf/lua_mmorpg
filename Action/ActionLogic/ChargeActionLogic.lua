local Class = require("Tool.Class")
local C = require("Define.Constants")
local ActionLogic = require("Action.ActionLogic")

---@class ChargeActionLogic : ActionLogic
local ChargeActionLogic = Class("ChargeActionLogic", ActionLogic)

function ChargeActionLogic:_init(id)
    self.__base:_init(self, id)
end

function ChargeActionLogic:HeartBeat(actionParam, deltaTime)
    local pCallBack = actionParam.GetCallBackFunctor()

    if pCallBack==nil then
        return false
    end

    if(false==pCallBack:CanDoThisActionInThisStatus(actionParam)) then
        return false
    end

    local nContinuance = actionParam.GetContinuance() - deltaTime
    local bRet = true

    if 0 > nContinuance then
        nContinuance = 0
    end

    actionParam.SetContinuance(nContinuance)

    if 0 == nContinuance then
        bRet = pCallBack:OnActivateOnce(actionParam)
    end

    return bRet
end

function ChargeActionLogic:OnDisturb(actionParam)
    local pCallBack = actionParam.GetCallBackFunctor()
    if pCallBack ~= nil then
        if true == pCallBack:InterruptWhenDisturbed(actionParam) then
            return false
        end
        return pCallBack:OnDisturbForCharging(actionParam)
    end
    return true
end

function ChargeActionLogic:OnInterrupt(actionParam)
    local pCallBack = actionParam.GetCallBackFunctor()
    if pCallBack ~= nil then
        return pCallBack:OnInterrupt(actionParam)
    end
    return false
end

return ChargeActionLogic
