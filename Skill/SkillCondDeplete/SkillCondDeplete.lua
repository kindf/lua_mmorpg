local Class = require("Tool.Class")
local Log = require("Tool.Log")
local C = require("Define.Constants")

---@class SkillCondDeplete
local SkillCondDeplete = Class("SkillCondDeplete")

function SkillCondDeplete:ConditionCheck(rMr, term)
    local params = rMr:GetTargetAndDepletingParams()
    if term.kind == "mp" then
        if rMr:GetMP() < term.value then
            params:SetErrCode(C.OR_LACK_MANA)
            Log.warn(string.format("%s 没有足够的法力 %s/%s", rMr:GetName(), rMr:GetMP(), term.value))
            return false
        end
    elseif term.kind == "rage" then
        if rMr:GetRage() < term.value then
            params:SetErrCode(C.OR_NOT_ENOUGH_RAGE)
            Log.warn(string.format("%s 没有足够的怒气 %s/%s", rMr:GetName(), rMr:GetRage(), term.value))
            return false
        end
    end
    return true
end

function SkillCondDeplete:Deplete(rMe, term)
    local params = rMe:GetTargetAndDepletingParams()
    if term.kind == "mp" then
        if rMe:GetMP() < term.value then
            params:SetErrCode(C.OR_LACK_MANA)
            Log.warn(string.format("%s 没有足够的法力 %s/%s", rMe:GetName(), rMe:GetMP(), term.value))
            return false
        end
        rMe:SetMP(rMe:GetMP() - term.value)
        Log.msg(string.format("%s 消耗 %s 法力", rMe:GetName(), term.value))
    elseif term.kind == "rage" then
        if rMe:GetRage() < term.value then
            params:SetErrCode(C.OR_NOT_ENOUGH_RAGE)
            Log.warn(string.format("%s 没有足够的怒气 %s/%s", rMe:GetName(), rMe:GetRage(), term.value))
            return false
        end
        rMe:SetRage(rMe:GetRage() - term.value)
        Log.msg(string.format("%s 消耗 %s 怒气", rMe:GetName(), term.value))
    end
    return true
end

---@type SkillCondDeplete
local GSkillCondDeplete
function SkillCondDeplete.GetInstance()
    if not GSkillCondDeplete then
        GSkillCondDeplete = SkillCondDeplete.new()
    end
    return GSkillCondDeplete
end

return SkillCondDeplete