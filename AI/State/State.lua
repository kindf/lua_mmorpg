local Class = require("Tool.Class")
local Log = require("Tool.Log")
local C = require("Define.Constants")

---@class State
local State = Class("State")

function State:_init(state_id)
    self.state_id = state_id
end

function State:GetStateID()
    return self.state_id
end

function State:CanUseSkill(pAI)
    return C.OR_OK
end

function State:UseSkill(pAI, idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
    Log.fn("State::UseSkill", string.format("skill=%s", idSkill))

    local oResult = self:CanUseSkill(pAI)
    if oResult ~= C.OR_OK then
        Log.back(oResult)
        return oResult
    end

    local pCharacter = pAI:GetCharacter()
    if pCharacter:GetObjType() == C.OBJ_TYPE.HUMAN then
        Log.msg("Human: 不直接执行 -> 交由技能队列")
        Log.back(C.OR_OK)
        return C.OR_OK
    end

    if pCharacter and pCharacter:CanUseSkillNow() then
        local pos = {m_fX = fTargetX, m_fZ = fTargetZ}
        local r = pCharacter:Do_UseSkill(idSkill, nLevel, idTarget, pos, fDir, guidTarget)
        Log.back(r)
        return r
    end
    Log.back(C.OR_OK)
    return oResult
end

function State:Obj_UseSkill(pAI, idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
    Log.fn("State:Obj_UseSkill", string.format("skill=%s", idSkill))

    local pCharacter = pAI:GetCharacter()
    if pCharacter and pCharacter:CanUseSkillNow() then
        local pos = {m_fX = fTargetX, m_fZ = fTargetZ}
        local r = pCharacter:Do_UseSkill(idSkill, nLevel, idTarget, pos, fDir, guidTarget)
        Log.back(r)
        return r
    end
    Log.back(C.OR_OK)
    return C.OR_OK
end

function State:CanMove(pAI)
    local pCharacter = pAI:GetCharacter()
    if pCharacter == nil then return C.OR_ERROR end
    if pCharacter:IsDie() then return C.OR_DIE end
    return C.OR_OK
end

-- 不执行实际的移动逻辑，只检测和预设路径点，实际移动由tick触发
function State:Move(pAI, nHandleID, wNumTargetPos, paTargetPos)
    Log.fn("State::Move", string.format("handle=%d nodes=%d", nHandleID, wNumTargetPos))

    local oResult = self:CanMove(pAI)
    if oResult ~= C.OR_OK then
        Log.back(oResult)
        return oResult
    end

    local pCharacter = pAI:GetCharacter()
    if pCharacter then
        local r = pCharacter:Do_Move(nHandleID, wNumTargetPos, paTargetPos)
        Log.back(r)
        return r
    end
    Log.back(C.OR_OK)
    return C.OR_OK
end

-- 不做状态过滤，直接执行（内部调用用）
function State:Obj_Move(pAI, nHandleID, wNumTargetPos, paTargetPos)
    local pCharacter = pAI:GetCharacter()
    if pCharacter then
        return pCharacter:Do_Move(nHandleID, wNumTargetPos, paTargetPos)
    end
    return C.OR_OK
end

function State:Stop(pAI)
    local pCharacter = pAI:GetCharacter()
    if pCharacter then
        pCharacter:StopCharacterLogic(true)
    end
    return C.OR_OK
end

function State:Logic(pAI, uTime)
    self:StateLogic(pAI, uTime)
    return true
end

function State:StateLogic(pAi, uTime)
end

return State