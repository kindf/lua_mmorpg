-- 动作的代理类 , 角色动作的公共接口和常用功能

local C = require("Define.Constants")
local Log = require("Tool.Log")
local Class = require("Tool.Class")
local ActionLogicMgr = require("Action.ActionLogic.ActionLogicMgr")
local ActionCallBack = require("Action.ActionCallBack")

---@class ActionDelegator
local ActionDelegator = Class("ActionDelegator")

function ActionDelegator:_init()
    self._now = 0
end

function ActionDelegator:Now()
    return self._now
end

---@param rActor ObjCharacter
function ActionDelegator:CanDoNextAction(rActor)
    local actionLogic = rActor:GetActionLogic()
    local actionParam = rActor:GetActionParam()
    if not actionLogic then
        return true
    end
    if 0 >= actionParam:GetContinuance() then
        return true
    end

    return false
end

-- 注册瞬发技能action
---@param rActor ObjCharacter
function ActionDelegator:RegisterInstantActionForSkill(rActor, nAction, nActionTime)
    local rActionParam = rActor:GetActionParam()
    if self:CanDoNextAction(rActor) == false then
        return false
    end
    rActionParam:Reset()
    rActionParam:SetActor(rActor)
    rActor:SetActionLogic(ActionLogicMgr.GetInstance():GetLogicById(C.ACTION_LOGIC_TYPE.INSTANCE))
    rActor:AddLogicCount()
    self:BroadcastUnitStartInstantAction(rActor, nAction, nActionTime)
    if 0 == rActor:GetActionTime() then
        rActor:SetActionTime(C.MIN_ACTION_TIME)
    end
    rActor:OnActionStarted()
    return true
end

-- 广播动作
function ActionDelegator:BroadcastUnitStartInstantAction(rActor, nAction, nActionTime)
end

---@param rActor ObjCharacter
function ActionDelegator:RegisterChargeActionForSkill(rActor, nAction, nContinuance)
    local rActionParam = rActor:GetActionParam()
    if false == self:CanDoNextAction(rActor) then
        return false
    end

    rActionParam:Reset()
    rActionParam:SetActor(rActor)
    rActionParam:SetContinuance(nContinuance)
    rActionParam:SetCallBackFunctor(ActionCallBack.new())
    rActor:SetActionLogic(ActionLogicMgr.GetInstance():GetLogicById(C.ACTION_LOGIC_TYPE.CHARGE))
    rActor:AddLogicCount()
    self:BroadcastUnitStartChargeAction(rActor,nAction, nContinuance)
    if 0 == rActor:GetActionTime() then
        rActor:SetActionTime(C.MIN_ACTION_TIME)
    end
    rActor:OnActionStarted()
    return true
end

function ActionDelegator:BroadcastUnitStartChargeAction(rActor, nAction, nActionTime)
end

--- 注册持续施法技能action
---@param rActor ObjCharacter
function ActionDelegator:RegisterChannelActionForSkill(rActor, nAction, nContinuance, nInterval)
local rActionParam = rActor:GetActionParam()
    if false == self:CanDoNextAction(rActor) then
        return false
    end

    rActionParam:Reset()
    rActionParam:SetActor(rActor)
    if 500 > nContinuance then
        nContinuance = 2000
    end
    rActionParam:SetContinuance(nContinuance)
    if 500 > nInterval then
        nInterval = 2000
    end
    rActionParam:SetInterval(nInterval)
    rActionParam:SetCallBackFunctor(ActionCallBack.new())
    rActor:SetActionLogic(ActionLogicMgr.GetInstance():GetLogicById(C.ACTION_LOGIC_TYPE.CHANNEL))
    rActor:AddLogicCount()
    self:BroadcastUnitStartChannelAction(rActor,nAction, nContinuance)
    if 0 == rActor:GetActionTime() then
        rActor:SetActionTime(C.MIN_ACTION_TIME)
    end
    rActor:OnActionStarted()
    return true
end

function ActionDelegator:BroadcastUnitStartChannelAction(rActor, nAction, nActionTime)
end

---@param rActor ObjCharacter
function ActionDelegator:OnHeartBeat(rActor, deltaTime)
    local bRet = false
    local pActionLogic = rActor:GetActionLogic()
    local rActionParam = rActor:GetActionParam()
    if not pActionLogic then
        return bRet
    end
    if rActor:IsAlive() == false or rActor:IsActiveObj() == false then
        return bRet
    end
    bRet = pActionLogic:HeartBeat(rActionParam, deltaTime)
    if bRet == false then
        self:InterruptCurrentAction(rActor)
    else
        if rActionParam:GetContinuance() <= 0 then
            self:CurrentActionFinished(rActor)
        end
    end
    return true
end

function ActionDelegator:CurrentActionFinished(rActor)
    local bRet = false
    local pActionLogic = rActor:GetActionLogic()
    local ActionParam = rActor:GetActionParam()
    if rActor:GetCharacterLogic() == C.CHARACTER_LOGIC.USE_SKILL then
        rActor:StopCharacterLogic(false)
    end
    self:ResetForNextAction(rActor)
end

function ActionDelegator:InterruptCurrentAction(rActor)
    local actionLogic = rActor:GetActionLogic()
    local rActionParam = rActor:GetActionParam()
    if actionLogic then
        actionLogic:OnInterrupt(rActionParam)
    end
    if(rActor:GetCharacterLogic() == C.CHARACTER_LOGIC.USE_SKILL) then
        rActor:StopCharacterLogic(true)
    end
    self:ResetForNextAction(rActor)
end

function ActionDelegator:ResetForNextAction(rActor)
    local rActionParam = rActor:GetActionParam()
    local pCallBack = rActionParam:GetCallBackFunctor()
    if pCallBack then
        pCallBack:ResetForNextAction(rActionParam)
    end
    rActionParam:Reset()
    rActor:SetActionLogic(nil)
end

---@type ActionDelegator
local GActionDelegator
function ActionDelegator.GetInstance()
    if not GActionDelegator then
        GActionDelegator = ActionDelegator.new()
    end
    return GActionDelegator
end

return ActionDelegator