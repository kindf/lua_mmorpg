local Class = require("Tool.Class")
local C = require("Define.Constants")
local SkillCondDeplete = require("Skill.SkillCondDeplete.SkillCondDeplete")
local Log = require("Tool.Log")
local ActionDelegator = require("Action.ActionDelegator")
local Combat = require("Skill.CombatCore")
local Targeting = require("Skill.Targeting")

local function GetTargetObj(rMe)
    local param = rMe:GetTargetAndDepletingParams()
    return rMe:GetSpecificObjInSameSceneByID(param:GetTargetObj())
end

---@class BaseSkillLogic
local BaseSkillLogic = Class("BaseSkillLogic")

-- 子类覆盖接口
function BaseSkillLogic:IsPassive() return false end
function BaseSkillLogic:CancelSkillEffect(rMe) return false end
function BaseSkillLogic:SpecificOperationOnSkillStart(rMe) return true end
function BaseSkillLogic:SpecificConditionCheck(rMe) return true end
function BaseSkillLogic:SpecificDeplete(rMe) return true end
function BaseSkillLogic:EffectOnUnitOnce(rMe, rTar, bCriticalFlag) return true end
function BaseSkillLogic:EffectOnUnitEachTick(rMe, rTar, bCriticalFlag) return true end
function BaseSkillLogic:OnInterrupt(rMe) return false end
function BaseSkillLogic:OnUseSkillSuccessfully(rImp, rMe, rSkill) end

function BaseSkillLogic:OnCancel(rMe)
    local params = rMe:GetTargetAndDepletingParams()
    params:SetErrCode(C.OR_INVALID_SKILL)
    params:SetErrParam(params:GetActivatedSkill())
    return false
end

function BaseSkillLogic:IsConditionSatisfied(rMe)
    if not self:CommonConditionCheck(rMe) then
        return false
    end
    if not self:SpecificConditionCheck(rMe) then
        return false
    end
    return true
end

function BaseSkillLogic:DepleteProcess(rMe)
    if not self:CommonDeplete(rMe) then
        return false
    end
    if not self:SpecificDeplete(rMe) then
        return false
    end
    return true
end

function BaseSkillLogic:CommonConditionCheck(rMe)
    local si = rMe:GetSkillInfo()
    for idx = 0,  C.CONDITION_AND_DEPLETE_TERM_NUMBER - 1 do
        local term = si.condep_terms[idx + 1]
        if term then
            if not SkillCondDeplete.GetInstance():ConditionCheck(rMe, term) then
                return false
            end
        end
    end
    if not self:TargetCheckForActivateOnce(rMe) then
        return false
    end
    return true
end

function BaseSkillLogic:CommonDeplete(rMe)
    local si = rMe:GetSkillInfo()
    for idx = 0,  C.CONDITION_AND_DEPLETE_TERM_NUMBER - 1 do
        local term = si.condep_terms[idx + 1]
        if term then
            if not SkillCondDeplete.GetInstance():Deplete(rMe, term) then
                return false
            end
        end
    end
    return true
end

function BaseSkillLogic:TargetCheckForActivateOnce(rMe)
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetAndDepletingParams()

    if si.select_type ~= C.SELECT_TYPE.CHARACTER then
        if si.select_type == C.SELECT_TYPE.POS then
            if rMe:IsOutOfRangePos(params:GetTargetPosition()) then
                Log.warn("目标距离太远")
                return false
            end
        end
        return true
    end

    local pObj = GetTargetObj(rMe)
    if pObj then
        -- 目标对象类型要求
        local byType = si.target_check_by_obj_type
        if byType == 0 and pObj:GetObjType() ~= C.OBJ_TYPE.HUMAN then
            params:SetErrCode(C.OR_INVALID_TARGET)
            params:SetErrParam(0)
            return false
        elseif byType == 1 and pObj:GetObjType() ~= C.OBJ_TYPE.PET then
            params:SetErrCode(C.OR_INVALID_TARGET)
            params:SetErrParam(0)
            return false
        elseif byType == 2 and pObj:GetObjType() ~= C.OBJ_TYPE.MONSTER then
            params:SetErrCode(C.OR_INVALID_TARGET)
            params:SetErrParam(0)
            return false
        end
        -- 使用者和目标应该时友好关系
        if si.target_logic_by_stand == 0 then
            if not rMe:IsFriend(pObj) then
                params:SetErrCode(C.OR_INVALID_TARGET)
                params:SetErrParam(0)
                return false
            end
        -- 使用者和目标应该时敌对关系
        elseif si.target_logic_by_stand == 1 then
            if not rMe:IsEnemy(pObj) then
                params:SetErrCode(C.OR_INVALID_TARGET)
                params:SetErrParam(0)
                return false
            end
        end

        local nState = si.target_must_in_special_state
        if nState == 0 and (not pObj:IsAlive()) then
            params:SetErrCode(C.OR_TARGET_DIE)
            params:SetErrParam(0)
            return false
        elseif nState == 1 and pObj:IsAlive() then
            params:SetErrCode(C.OR_INVALID_TARGET)
            params:SetErrParam(0)
            return false
        end

        if rMe:IsOutOfRange(pObj) then
            params:SetErrCode(C.OR_OUT_RANGE)
            params:SetErrParam(0)
            return false
        end
    end
    return true
end

function BaseSkillLogic:TargetCheckForEachTick(rMe)
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetAndDepletingParams()
    if si.select_type ~= C.SELECT_TYPE.CHARACTER then
        return true
    end
    local pObj = GetTargetObj(rMe)
    if pObj then
        local nState = si.target_must_in_special_state
        if nState == 0 and (not pObj:IsAlive()) then
            params:SetErrCode(C.OR_TARGET_DIE)
            params:SetErrParam(0)
            return false
        elseif nState == 1 and pObj:IsAlive() then
            params:SetErrCode(C.OR_INVALID_TARGET)
            params:SetErrParam(0)
            return false
        end
        if rMe:IsOutOfRange(pObj) then
            params:SetErrCode(C.OR_OUT_RANGE)
            params:SetErrParam(0)
            return false
        end
    end
    return true
end

function BaseSkillLogic:CalculateActionTime(rMe)
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetAndDepletingParams()
    return si.play_action_time
end

function BaseSkillLogic:CooldownProcess(rMe)
    Log.fn("BaseSkillLogic:CooldownProcess")
    local si = rMe:GetSkillInfo()
    local nPlayActionTime = si.play_action_time
    local nCooldown = si.cooldown_time
    if nCooldown < nPlayActionTime then
        nCooldown = nPlayActionTime
    end
    if si.auto_shot then
        rMe:SetAutoRepeatCooldown(nCooldown)
        Log.msg(string.format("%s 设置自动重复冷却时间 %s", rMe:GetName(), nCooldown))
    else
        rMe:SetCooldown(si.cooldown_id, nCooldown)
        Log.msg(string.format("%s 设置冷却时间 %s", rMe:GetName(), nCooldown))
    end
    Log.back(nil)
end

-- 瞬发
function BaseSkillLogic:StartLaunching(rMe)
    Log.fn("BaseSkillLogic:StartLaunching")
    local bRet = self:Action_ActivateOnceHandler(rMe)
    Log.back(bRet)
    return bRet
end

-- 聚气
function BaseSkillLogic:StartCharging(rMe)
    Log.fn("BaseSkillLogic:StartCharging")
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetAndDepletingParams()
    local nMaxTime = si.charge_time
    local bRet
    if nMaxTime <= 0 then
        bRet = self:Action_ActivateOnceHandler(rMe)
    else
        bRet = ActionDelegator.GetInstance():RegisterChargeActionForSkill(rMe, si.skill_id, nMaxTime, function()
            return self:Action_ActivateOnceHandler(rMe)
        end)
    end
    if bRet then
        params:SetErrCode(C.OR_OK)
    end
    Log.back(bRet)
    return bRet
end

-- 引导
function BaseSkillLogic:StartChanneling(rMe)
    Log.fn("BaseSkillLogic:StartChanneling")
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetAndDepletingParams()
    local nMaxTime = si.channel_time
    if nMaxTime <= 0 then
        Log.error("引导时间必须大于0")
        params:SetErrCode(C.OR_ERROR)
        Log.back(false)
        return false
    end
    local bRet = true
    if not params:GetIgnoreConditionCheckFlag() then
        bRet = self:DepleteProcess(rMe)
    end
    if bRet then
        rMe:OnUseSkillSuccessfully(si)
        local ok = ActionDelegator.GetInstance():RegisterChannelActionForSkill(rMe, si.skill_id, nMaxTime, si.charges_or_interval, function()
            self:Action_ActivateEachTickHandler(rMe)
        end)
        if ok then
            self:CooldownProcess(rMe)
            params:SetErrCode(C.OR_OK)
            self:ActivateOnce(rMe)
            Log.back(true)
            return true
        end
    end
    Log.back(false)
    return false
end

-- 放技能流程
function BaseSkillLogic:Action_ActivateOnceHandler(rMe)
    Log.fn("BaseSkillLogic:Action_ActivateOnceHandler")
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetAndDepletingParams()

    if not self:IsConditionSatisfied(rMe) then
        Log.error("条件不满足 -> OR_LIMIT_USE_SKILL")
        Log.back(false)
        return false
    end

    local bRet = true
    if not params:GetIgnoreConditionCheckFlag() then
        bRet = self:DepleteProcess(rMe)
    end

    if bRet then
        rMe:OnUseSkillSuccessfully(si)

        local nPlayActionTime = self:CalculateActionTime(rMe)
        if not ActionDelegator.GetInstance():RegisterInstantActionForSkill(rMe, si.skill_id, nPlayActionTime) then
            Log.back(false)
            return false
        end
        rMe:SetActionTime(nPlayActionTime)

        self:CooldownProcess(rMe)

        local nActivateTimes = si.charges_or_interval
        if nActivateTimes <= 0 then
            nActivateTimes = 1
        end
        Log.msg(string.format("%s 发动 %s 次", rMe:GetName(), nActivateTimes))
        for _ = 1, nActivateTimes do
            params:SetDelayTime(params:GetDelayTime() + si.delay_time)
            self:ActivateOnce(rMe)
        end
        Log.back(true)
        return true
    end
    Log.back(false)
    return false
end

function BaseSkillLogic:Action_ActivateEachTickHandler(rMe)
    Log.fn("BaseSkillLogic:Action_ActivateEachTickHandler")
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetAndDepletingParams()
    if self:TargetCheckForEachTick(rMe) then
        params:SetDelayTime(si.delay_time)
        self:ActivateEachTick(rMe)
        Log.back(true)
        return true
    end
    Log.back(false)
    return false
end

-- 一次技能结算
function BaseSkillLogic:ActivateOnce(rMe)
    Log.fn("BaseSkillLogic:ActivateOnce")
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetAndDepletingParams()

    local targets = {}
    if not Targeting.CalculateTargetList(rMe, targets) then
        Log.warn("无法计算目标")
        Log.back(false)
        return false
    end

    local hitFlags = {}
    for i, pTarget in ipairs(targets) do
        if self:HitThisTarget(rMe, pTarget) then
            hitFlags[i] = true
        end
        Combat.RegisterBeSkillEvent(pTarget, rMe, si.skill_id, si.delay_time)
    end
    params:SetTargetCount(#targets)
    Log.msg(string.format("广播目标队列：%s 个目标", #targets))

    for i, pTarget in ipairs(targets) do
        if hitFlags[i] then
            local bCriticalHit = self:CriticalHitThisTarget(rMe, pTarget)
            self:EffectOnUnitOnce(rMe, pTarget, bCriticalHit)
        end
    end

    Log.back(true)
    return true
end

function BaseSkillLogic:ActivateEachTick(rMe)
    Log.fn("BaseSkillLogic:ActivateEachTick")
    local si = rMe:GetSkillInfo()
    local targets = {}
    if not Targeting.CalculateTargetList(rMe, targets) then
        Log.warn("无法计算目标")
        Log.back(false)
        return false
    end
    local hitFlags = {}
    for i, pTarget in ipairs(targets) do
        if self:HitThisTarget(rMe, pTarget) then
            hitFlags[i] = true
        end
    end
    for i, pTarget in ipairs(targets) do
        if hitFlags[i] then
            local bCriticalHit = self:CriticalHitThisTarget(rMe, pTarget)
            self:EffectOnUnitEachTick(rMe, pTarget, bCriticalHit)
        end
    end
    Log.back(true)
    return true
end

function BaseSkillLogic:HitThisTarget(rMe, rTar)
    local si = rMe:GetSkillInfo()
    if rMe:IsFriend(rTar) then
        return true
    end
    if not Combat.IsHit(rMe, rTar, si.accuracy) then
        Combat.RegisterSkillMissEvent(rTar, rMe, si.skill_id)
        return false
    end
    Combat.RegisterSkillHitEvent(rTar, rMe, si.skill_id)
    return true
end

function BaseSkillLogic:CriticalHitThisTarget(rMe, rTar)
    local si = rMe:GetSkillInfo()
    if rMe:IsFriend(rTar) then
        return false
    end
    if Combat.IsCriticalHit(rMe, rTar, si.critical_rate) then
        rMe:OnCriticalHitTarget(si.skill_id, rTar)
        return true
    end
    return false
end

return BaseSkillLogic