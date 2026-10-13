local Log = require("shared.log")
local Data = require("data.game_data")
local C = require("shared.constants")

local CGCharUseSkillHandler = {}
CGCharUseSkillHandler.ThreadID = 1

---@param pPacket CGCharUseSkill
function CGCharUseSkillHandler.Execute(pPacket, pPlayer)
    Log.fn("CGCharUseSkillCGCharUseSkillHandler::Execute")

    if pPlayer == nil then
        Log.error("pGamePlayer == NULL")
        Log.back(C.PACKET_EXE_CONTINUE)
        return C.PACKET_EXE_CONTINUE
    end

    local pHuman = pPlayer:GetHuman()
    if pHuman == nil then
        Log.error("pHuman == NULL")
        Log.back(C.PACKET_EXE_CONTINUE)
        return C.PACKET_EXE_CONTINUE
    end

    local pScene = pHuman:GetScene()
    if pScene == nil then
        Log.error("pScene == NULL")
        Log.back(C.PACKET_EXE_CONTINUE)
        return C.PACKET_EXE_CONTINUE
    end

    if pScene.m_ThreadID ~= CGCharUseSkillHandler.ThreadID then
        Log.error("pScene.m_ThreadID != CGCharUseSkillHandler.ThreadID")
        Log.back(C.PACKET_EXE_CONTINUE)
        return C.PACKET_EXE_CONTINUE
    end

    local idSkill = math.floor(pPacket:GetSkillDataID() / 100)
    local nLevel = pPacket:GetSkillDataID() % 100
    local idTarget = pPacket:GetTargetID()
    local guidTarget = pPacket:GetTargetGUID()
    local posTarget = pPacket:GetTargetPos()
    local fDir = pPacket:GetDir()

    Log.msg(string.format("idSkill=%d, nLevel=%d, idTarget=%d, guidTarget=%d, fDir=%f", idSkill, nLevel, idTarget, guidTarget, fDir))

    -- 阵营前置拦截

    local pTarget = pScene:GetObjManager():GetObj(idTarget)
    if pTarget then
        local pSkillTemplate = Data.g_SkillTemplateDataMgr:GetInstanceByID(idSkill)
        local skillType = pSkillTemplate and pSkillTemplate:GetStandFlag() or 0
        if skillType > 0 then
            if pHuman:IsEnemy(pTarget) then
                Log.error(string.format("%s 与 %s 阵营不同 正面技能被拦截", pHuman:GetName(), pTarget:GetName()))
                pHuman:SendOperateResultMsg(C.OR_INVALID_TARGET)
                Log.back(C.PACKET_EXE_CONTINUE)
                return C.PACKET_EXE_CONTINUE
            end
        elseif skillType < 0 then
            if not pHuman:IsEnemy(pTarget) then
                Log.error(string.format("%s 与 %s 阵营不同 背面技能被拦截", pHuman:GetName(), pTarget:GetName()))
                pHuman:SendOperateResultMsg(C.OR_INVALID_TARGET)
                Log.back(C.PACKET_EXE_CONTINUE)
                return C.PACKET_EXE_CONTINUE
            end
        end
    else
        Log.warn("目标不存在 （继续流程）")
    end

    -- 分流技能
    if pPacket:GetObjID() == pHuman:GetID() then
        local oResult = pHuman:GetHumanAI():PushCommand_UseSkill(
            idSkill, nLevel, idTarget, posTarget.m_fX, posTarget.m_fZ, fDir, guidTarget
        )
        if C.OR_FAILED(oResult) then
            pHuman:SendOperateResultMsg(oResult)
        end
    else
        local pPet = pHuman:GetMyPet()
        if pPet ~= nil and pPet:GetID() == pPacket:GetObjID() then
            Log.msg("使用宠物技能")
            pPet:GetPetAI():PushCommand_UseSkill(
                idSkill, nLevel, idTarget, posTarget.m_fX, posTarget.m_fZ, fDir, guidTarget
            )
        end
    end

    Log.msg(string.format("S:%s D:%s Skill:%s (%.1f,%.1f) DIR=%.1f", pHuman:GetID(), pPacket:GetObjID(), idSkill, posTarget.m_fX, posTarget.m_fZ, fDir))
    Log.back(C.PACKET_EXE_CONTINUE)
    return C.PACKET_EXE_CONTINUE
end

return CGCharUseSkillHandler