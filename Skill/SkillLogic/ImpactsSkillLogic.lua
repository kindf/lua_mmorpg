local Class = require("Tool.Class")
local BaseSkillLogic = require("Skill.SkillLogic.BaseSkillLogic")
local Combat = require("Skill.CombatCore")
local ActionDelegator = require("Action.ActionDelegator")
local Log = require("Tool.Log")
local C = require("Define.Constants")
local ImpactCore = require("Skill.ImpactCore")

---@class ImpactsSkillLogic:BaseSkillLogic
local ImpactsSkillLogic = Class("ImpactsSkillLogic", BaseSkillLogic)

function ImpactsSkillLogic:EffectOnUnitOnce(rMe, rTar, bCriticalFlag)
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetAndDepletingParams()
    local impactId = si.impact_id
    Log.fn("ImpactsSkillLogic:EffectOnUnitOnce",
        string.format("target=%s impact=%s crit=%s", rTar:GetName(), impactId, bCriticalFlag))
    if impactId ~= C.INVALID_ID then
        ImpactCore.GetInstance():SendSpecificImpactToUnit(rMe, rTar, impactId, params:GetDelayTime(), ActionDelegator.GetInstance():Now())
    end
    Log.back(true)
    return true
end

function ImpactsSkillLogic:EffectOnUnitEachTick(rMe, rTar, bCriticalFlag)
    local si = rMe:GetSkillInfo()
    local params = rMe:GetTargetAndDepletingParams()
    local impactId = si.tick_impact_id
    Log.fn("ImpactsSkillLogic:EffectOnUnitEachTick",
        string.format("target=%s impact=%s crit=%s", rTar:GetName(), impactId, bCriticalFlag))
    if impactId ~= C.INVALID_ID then
        ImpactCore.GetInstance():SendSpecificImpactToUnit(rMe, rTar, impactId, params:GetDelayTime(), ActionDelegator.GetInstance():Now())
    end
    Log.back(true)
    return true
end

return ImpactsSkillLogic