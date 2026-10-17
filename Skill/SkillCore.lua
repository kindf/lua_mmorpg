local C = require("Define.Constants")
local Log = require("Tool.Log")
local ActionDelegator = require("Action.ActionDelegator")
local Class = require("Tool.Class")
local SkillLogicMgr = require("Skill.SkillLogic.SkillLogicMgr")
local SkillHelper = require("Skill.SkillHelper")

---@class SkillCore
local SkillCore = Class("SkillCore")

function SkillCore._init()
end

local function skillTypeName(t)
    if t == C.SKILL_INSTANT_LAUNCHING then return "SKILL_INSTANT_LAUNCHING" end
    if t == C.SKILL_NEED_CHARGING then return "SKILL_NEED_CHARGING" end
    if t == C.SKILL_NEED_CHANNELING then return "SKILL_NEED_CHANNELING" end
    if t == C.SKILL_PASSIVE then return "SKILL_PASSIVE" end
    return "UNKNOWN(" .. tostring(t) .. ")"
end

---@param rMe ObjCharacter
function SkillCore:ProcessSkillRequest(rMe, nSkillID, nLevel, nTargetID, rTargetPos, fTargetDir, guidTarget)
    Log.fn("SkillCore:ProcessSkillRequest", string.format("skill=%s lv=%s target=%s pos=%s dir=%s guid=%s", nSkillID, nLevel, nTargetID, rTargetPos, fTargetDir, guidTarget))

    local params = rMe:GetTargetAndDepletingParams()
    local tmpl = SkillHelper.GetSkillTemplate(nSkillID)

    if tmpl == nil then
        params:SetErrCode(C.OR_INVALID_SKILL)
        Log.error("模板不存在 -> OR_INVALID_SKILL")
        Log.back(false)
        return false
    end

    if nSkillID == C.INVALID_ID then
        params:SetErrCode(C.OR_OK)
        Log.back(true)
        return true
    end

    if not rMe:IsAlive() then
        params:SetErrCode(C.OR_DIE)
        Log.error("已死亡 -> OR_DIE")
        Log.back(false)
        return false
    end

    if not rMe:Skill_CanUseThisSkillInThisStatus(nSkillID) then
        params:SetErrCode(C.OR_LIMIT_USE_SKILL)
        Log.error("当前状态不允许 -> OR_LIMIT_USE_SKILL")
        Log.back(false)
        return false
    end

    if rMe:GetObjType() == C.OBJ_TYPE.HUMAN and tmpl.class_by_user == C.CLASS_BY_USER_PLAYER then
        if (not rMe:Skill_HaveSkill(nSkillID, nLevel)) and (not params:GetIgnoreConditionCheckFlag()) then
            params:SetErrCode(C.OR_INVALID_SKILL)
            Log.error("角色不会这个技能 -> OR_INVALID_SKILL")
            Log.back(false)
            return false
        end
    end

    if not rMe:Skill_IsSkillCooldowned(nSkillID) then
        params:SetErrCode(C.OR_COOL_DOWNING)
        Log.error("技能冷却中 -> OR_COOLDOWN")
        Log.back(false)
        return false
    end

    if  not ActionDelegator.GetInstance():CanDoNextAction(rMe) then
        params:SetErrCode(C.OR_BUSY)
        Log.error("正在做其他事 -> OR_LIMIT_USE_SKILL")
        Log.back(false)
        return false
    end

    if tmpl.skill_class == C.INVALID_ID and tmpl.menpai == C.INVALID_ID then
        nLevel = 1
    end

    if rMe:GetObjType() == C.OBJ_TYPE.HUMAN then
        local inst = SkillHelper.GetSkillInstance(nSkillID, nLevel)
        if inst == nil then
            params:SetErrCode(C.OR_INVALID_SKILL)
            Log.back(false)
            return false
        end

        if rMe:GetLevel() < (inst.study_level or 0) then
            params:SetErrCode(C.OR_NEED_HIGH_LEVEL_XINFA)
            Log.error("等级不够 -> OR_NEED_HIGH_LEVEL_XINFA")
            Log.back(false)
            return false
        end
    end

    params:SetActivatedSkill(nSkillID)
    params:SetSkillLevel(nLevel)
    params:SetTargetObj(nTargetID)
    params:SetTargetPosition(rTargetPos)
    params:SetTargetDirection(fTargetDir)
    params:SetTargetGuid(guidTarget)

    local bRet = self:ActiveSkillNow(rMe)
    if not bRet then
        self:OnException(rMe)
    end
    Log.back(bRet)
    return bRet
end

function SkillCore:InstanceSkill(rSkillInfoOut, rMe, nSkill, nLevel)
    Log.fn("SkillCore:InstanceSkill", string.format("skill=%s lv=%s", nSkill, nLevel))
    local params = rMe:GetTargetAndDepletingParams()
    local tmpl = SkillHelper.GetSkillTemplate(nSkill)
    if tmpl == nil then
        Log.error("模板不存在 -> OR_INVALID_SKILL")
        Log.back(false)
        return false
    end
    if nLevel == 0 or nLevel > C.MAX_CHAR_SKILL_LEVEL then
        Log.warn("技能等级越界 修正为1")
        nLevel = 1
    end

    params:SetSkillLevel(nLevel)
    local inst = SkillHelper.GetSkillInstance(nSkill, nLevel)
    if inst == nil then
        Log.error("实例不存在 -> OR_INVALID_SKILL")
        Log.back(false)
        return false
    end
    rSkillInfoOut:CopyFrom(inst, tmpl)
    Log.back(true)
    return true
end

function SkillCore:ActiveSkillNow(rMe)
    Log.fn("SkillCore:ActiveSkillNow")
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetAndDepletingParams()

    if (not rMe:IsAlive()) or (not rMe:IsActiveObj()) then
        params:SetErrCode(C.OR_DIE)
        Log.back(false)
        return false
    end

    si:Init()
    if not self:InstanceSkill(si, rMe, params:GetActivatedSkill(), params:GetSkillLevel()) then
        params:SetErrCode(C.OR_INVALID_SKILL)
        params:SetErrParam(params:GetActivatedSkill())
        Log.back(false)
        return false
    end

    rMe:RefixSkill(si)

    local pLogic = SkillLogicMgr.GetInstance():GetLogicById(si.logic_id)
    if pLogic == nil then
        params:SetErrCode(C.OR_INVALID_SKILL)
        params:SetErrParam(params:GetActivatedSkill())
        Log.error("找不到技能逻辑 -> OR_INVALID_SKILL")
        Log.back(false)
        return false
    end
    if pLogic:IsPassive() then
        params:SetErrCode(C.OR_ERROR)
        Log.error("被动技能不能主动释放")
        Log.back(false)
        return false
    end
    if pLogic:CancelSkillEffect(rMe) then
        params:SetErrCode(C.OR_OK)
        Log.back(true)
        return true
    end

    if (not rMe:Skill_IsSkillCooldowned(params:GetActivatedSkill())) 
        and (not params:GetIgnoreConditionCheckFlag()) then
        params:SetErrCode(C.OR_COOL_DOWNING)
        Log.error("冷却中 -> OR_COOL_DOWNING")
        Log.back(false)
        return false
    end

    if si.must_use_weapon_flag then
        if rMe:GetObjType() == C.OBJ_TYPE.HUMAN then
            params:SetErrCode(C.OR_NEED_A_WEAPON)
            Log.error("需要使用武器 -> OR_NEED_USE_WEAPON")
            Log.back(false)
            return false
        end
    end

    if not params:GetIgnoreConditionCheckFlag() then
        if not pLogic:IsConditionSatisfied(rMe) then
            Log.error("条件不满足 -> OR_LIMIT_USE_SKILL")
            Log.back(false)
            return false
        end
        if not pLogic:SpecificOperationOnSkillStart(rMe) then
            Log.error("特殊操作失败 -> OR_LIMIT_USE_SKILL")
            Log.back(false)
            return false
        end
    end

    local t = si.skill_type
    Log.msg("技能类型", skillTypeName(t))
    if t == C.SKILL_INSTANT_LAUNCHING then
        pLogic:StartLaunching(rMe)
    elseif t == C.SKILL_NEED_CHARGING then
        pLogic:StartCharging(rMe)
    elseif t == C.SKILL_NEED_CHANNELING then
        pLogic:StartChanneling(rMe)
    else
        Log.error("不支持的技能类型 -> OR_LIMIT_USE_SKILL")
    end
    Log.back(true)
    return true
end

function SkillCore:OnException(rMe)
    Log.fn("SkillCore:OnException")
    if rMe:GetObjType() == C.OBJ_TYPE.HUMAN then
        local params = rMe:GetTargetAndDepletingParams()
        if C.OR_FAILED(params:GetErrCode()) then
            rMe:SendOperateResultMsg(params:GetErrCode())
        end
    end
    Log.back(nil)
end

---@type SkillCore
local GSkillCore
function SkillCore.GetInstance()
    if not GSkillCore then
        GSkillCore = SkillCore.new()
    end
    return GSkillCore
end

return SkillCore