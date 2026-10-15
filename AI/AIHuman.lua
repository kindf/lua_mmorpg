local Class = require("Tool.Class")
local C = require("Define.Constants")
local AI_Character = require("AI.AICharacter")
local Log = require("Tool.Log")
local Vec = require("Tool.Vec")
local ActionDelegator = require("Action.ActionDelegator")

---@class UseSkillParam
local UseSkillParam = Class("UseSkillParam")

function UseSkillParam:_init()
    self:CleanUp()
end

function UseSkillParam:CleanUp()
    self.m_nQueueSkill = C.INVALID_SKILL_ID
    self.m_nAutoShotSkill = C.INVALID_SKILL_ID
    self.m_nSkillLevel = 0
    self.m_nQueueTargetObjID = C.INVALID_ID
    self.m_QueueTargetPosition = {m_fX = 0.0, m_fZ = 0.0}
    self.m_fQueueTargetDirection = -1.0
    self.m_guidQueueTarget = C.INVALID_GUID
    self.m_nAutoShotTargetObjID = C.INVALID_ID
end

---@class UseItemParam
local UseItemParam = Class("UseItemParam")
function UseItemParam:_init()
    self:CleanUp()
end

function UseItemParam:CleanUp()
    self.m_BagIndex = C.INVALID_ID
end

---@class AI_Human:AI_Character
local AI_Human = Class("AI_Human", AI_Character)

function AI_Human:_init(pCharacter)
    self.__base._init(self, pCharacter)
    self.m_paramAI_UseSkill = UseSkillParam.new()
    self.m_paramAI_UseItem = UseItemParam.new()
end

function AI_Human:IsEnterCombatState(idSkill, nLevel, idTarget)
    local pCharacter = self:GetCharacter()
    if not pCharacter then
        return false
    end

    if idSkill == C.INVALID_SKILL_ID then
        self.m_paramAI_UseSkill:CleanUp()
        return false
    end

    if not pCharacter:IsAlive() then
        return false
    end

    local pSkill = Data.g_SkillTemplateDataMgr:GetInstanceByID(idSkill)
    if not pSkill then
        return false
    end
    if idTarget ~= C.INVALID_ID then
        pCharacter:SetLockedTarget(idTarget)
    end

    if pSkill:IsAutoShotSkill() and pCharacter:GetObjType() == C.OBJ_TYPE.HUMAN then
        self.m_paramAI_UseSkill.m_nAutoShotSkill = idSkill
        self.m_paramAI_UseSkill.m_nSkillLevel = nLevel
        self.m_paramAI_UseSkill.m_nAutoShotTargetObjID = idTarget
        return true
    end

    return false
end

-- 把技能push到队列中
function AI_Human:PushCommand_UseSkill(idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
    Log.fn("AI_Hunam::PushCommand_UseSkill", string.format("skill=%s", idSkill))

    if not self:GetCharacter():IsActiveObj() then
        Log.back(C.OR_ERROR)
        return C.OR_ERROR
    end

    local oResult = self:UseSkill(idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)

    if oResult == C.OR_OK then
        self:ChangeState(C.ESTATE.COMBAT)

        if not self:IsEnterCombatState(idSkill, nLevel, idTarget) then
            self:PushSkillToQueue(idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
        end
    end
    Log.back(oResult)
    return oResult
end

function AI_Human:PushSkillToQueue(idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
    Log.fn("AI_Hunam::PushSkillToQueue", string.format("skill=%s", idSkill))
    local pSkill = Data.g_SkillTemplateDataMgr:GetInstanceByID(idSkill)
    if pSkill == nil then
        Log.back(nil)
        return
    end

    local pCharacter = self:GetCharacter()
    if pCharacter then
        local rParams = pCharacter:GetTargetAndDepletingParams()
        if not ActionDelegator.GetInstance():CanDoNextAction(pCharacter) then
            if idSkill == rParams:GetActivatedSkill() then
                Log.msg("过滤掉重复按键")
                Log.back(nil)
                return
            end
        end

        if pSkill:CanInterruptAutoShot() then
            self.m_paramAI_UseSkill.m_nAutoShotSkill = C.INVALID_SKILL_ID
            self.m_paramAI_UseSkill.m_nAutoShotTargetObjID = C.INVALID_ID
        end

        self.m_paramAI_UseSkill.m_nQueueSkill = idSkill
        self.m_paramAI_UseSkill.m_nSkillLevel = nLevel
        self.m_paramAI_UseSkill.m_nQueueTargetObjID = idTarget
        self.m_paramAI_UseSkill.m_QueueTargetPosition.m_fX = fTargetX
        self.m_paramAI_UseSkill.m_QueueTargetPosition.m_fZ = fTargetZ
        self.m_paramAI_UseSkill.m_fQueueTargetDirection = fDir
        self.m_paramAI_UseSkill.m_guidQueueTarget = guidTarget
        Log.msg("已写入 m_nQueueSkill")
    end

    Log.back(nil)
end

function AI_Human:GetSkillInstanceByLevel(nSkillID, nLevel)
    local tmpl = Data.g_SkillTemplateDataMgr:GetInstanceByID(nSkillID)
    if tmpl == nil then
        return nil
    end
    if nLevel == nil or nLevel == 0 then
        nLevel = 1
    end
    local instId = tmpl:GetSkillInstance(nLevel - 1)
    if instId == nil then
        return nil
    end
    return Data.g_SkillInstanceDataMgr:GetInstanceByID(instId)
end

-- 检查目标是否有效（技能选择类型为 CHARACTER 时才会检查）
function AI_Human:CheckTargetValid(nSkillID, TargetID, nLevel)
    local tmpl = Data.g_SkillTemplateDataMgr:GetInstanceByID(nSkillID)
    if tmpl == nil then
        return false
    end

    -- 读实例数据，与 SkillCore 的校验来源保持一致（select_type 优先取实例，缺省回退模板）
    local inst = self:GetSkillInstanceByLevel(nSkillID, nLevel)
    local selectType = (inst and inst.select_type) or tmpl:GetSelectType()
    local nState = inst and inst.target_must_in_special_state
    if nState == nil then
        nState = tmpl:GetTargetMustInSpecialState()
    end

    if selectType == C.SELECT_TYPE.CHARACTER then
        local pObj = self:GetCharacter():GetSpecificObjInSameSceneByID(TargetID)
        if pObj == nil then
            return false
        end
        if not pObj:IsCharacter() then
            return false
        end

        local bMustAlive = (nState == 0 or nState == -1)
        local bMustDead = (nState == 1 or nState == -1)
        local bAlive = pObj:IsAlive()
        if bAlive and bMustAlive then
            return true
        end

        if not bAlive and bMustDead then
            return true
        end

        return false
    end
    return true
end

-- 战斗心跳
function AI_Human:AI_Logic_Combat(uTime)
    Log.fn("AI_Human::AI_Logic_Combat", string.format("uTime=%d", uTime))
    local rMe = self:GetCharacter()
    local position = {m_fX = 0.0, m_fZ = 0.0}

    if rMe:CanUseSkillNow() then
        local nAutoActivedSkill = self.m_paramAI_UseSkill.m_nAutoShotSkill
        local nQueuedSkill = self.m_paramAI_UseSkill.m_nQueueSkill
        local bagIndex = self.m_paramAI_UseItem.m_BagIndex

        if bagIndex ~= C.INVALID_ID then
            Log.msg("使用道具")
            self.m_paramAI_UseItem:CleanUp()
        elseif nQueuedSkill ~= C.INVALID_SKILL_ID then
            Log.msg("使用队列技能")
            if not self:CheckTargetValid(nQueuedSkill, self.m_paramAI_UseSkill.m_nQueueTargetObjID, self.m_paramAI_UseSkill.m_nSkillLevel) then
                self.m_paramAI_UseSkill:CleanUp()
                self:ChangeState(C.ESTATE.IDLE)
                rMe:SetLockedTarget(C.INVALID_ID)
                Log.msg("目标已失效 回空闲")
                Log.back(nil)
                return
            end

            if not rMe:Skill_IsSkillCooldowned(nQueuedSkill) then
                rMe:SendOperateResultMsg(C.OR_COOL_DOWNING)
                self.m_paramAI_UseSkill.m_nQueueSkill = C.INVALID_SKILL_ID
                Log.back(nil)
                return
            end
            if not rMe:Skill_CanUseThisSkillInThisStatus(nQueuedSkill) then
                rMe:SendOperateResultMsg(C.OR_U_CANNT_DO_THIS_RIGHT_NOW)
                self.m_paramAI_UseSkill.m_nQueueSkill = C.INVALID_SKILL_ID
                Log.back(nil)
                return
            end

            self:Obj_UseSkill(
                nQueuedSkill,
                self.m_paramAI_UseSkill.m_nSkillLevel,
                self.m_paramAI_UseSkill.m_nQueueTargetObjID,
                self.m_paramAI_UseSkill.m_QueueTargetPosition.m_fX,
                self.m_paramAI_UseSkill.m_QueueTargetPosition.m_fZ,
                self.m_paramAI_UseSkill.m_fQueueTargetDirection,
                self.m_paramAI_UseSkill.m_guidQueueTarget
            )

            self.m_paramAI_UseSkill.m_nQueueSkill = C.INVALID_SKILL_ID
            rMe:SetLockedTarget(self.m_paramAI_UseSkill.m_nQueueTargetObjID)
        elseif nAutoActivedSkill ~= C.INVALID_SKILL_ID then
            Log.msg(string.format("使用自动释放技能: nAutoActivedSkill=%d", nAutoActivedSkill))
            if not self:CheckTargetValid(nAutoActivedSkill, self.m_paramAI_UseSkill.m_nAutoShotTargetObjID, self.m_paramAI_UseSkill.m_nSkillLevel) then
                self.m_paramAI_UseSkill:CleanUp()
                self:ChangeState(C.ESTATE.IDLE)
                rMe:SetLockedTarget(C.INVALID_ID)
                Log.msg("目标已失效")
                Log.back(nil)
                return
            end
            if not rMe:Skill_IsSkillCooldowned(nAutoActivedSkill) then
                Log.back(nil)
                return
            end

            if not rMe:Skill_CanUseThisSkillInThisStatus(nAutoActivedSkill) then
                Log.back(nil)
                return
            end

            local nRet = self:Obj_UseSkill(
                self.m_paramAI_UseSkill.m_nAutoShotSkill,
                self.m_paramAI_UseSkill.m_nSkillLevel,
                self.m_paramAI_UseSkill.m_nAutoShotTargetObjID,
                position.m_fX,
                position.m_fZ,
                0.0,
                C.INVALID_ID
            )

            local pTarget = rMe:GetScene():GetObjManager():GetObj(self.m_paramAI_UseSkill.m_nAutoShotTargetObjID)
            if pTarget and nRet == C.OR_OK and rMe:IsEnemy(pTarget) then
            else
                self.m_paramAI_UseSkill.m_nAutoShotSkill = C.INVALID_SKILL_ID
                self.m_paramAI_UseSkill.m_nAutoShotTargetObjID = C.INVALID_ID
            end
        else
            self:ChangeState(C.ESTATE.IDLE)
            Log.msg("无待放技能 -> 空闲")
            Log.back(nil)
            return
        end
    end
    Log.back(nil)
end

function AI_Human:_AI_Logic_Idle(uTime)
    Log.fn("AI_Human:AI_Logic_IDLE")
    Log.back(nil)
end

function AI_Human:AI_Logic_Dead(uTime)
    Log.fn("AI_Human:AI_Logic_Dead")
    Log.back(nil)
end

function AI_Human:ForceInterruptSkill()
    self.m_paramAI_UseSkill:CleanUp()
    ActionDelegator.GetInstance():InterruptCurrentAction(self:GetCharacter())
    if self:GetAIState():GetStateID() ~= C.ESTATE.IDLE then
        self:ChangeState(C.ESTATE.IDLE)
    end
end

function AI_Human:PushCommand_Move(nHandleID, wNumTargetPos, paTargetPos, bLine)
    Log.fn("AI_Human::PushCommand_Move", string.format("nodes=%d", wNumTargetPos))

    if not self:GetCharacter():IsActiveObj() then
        Log.back(C.OR_ERROR)
        return C.OR_ERROR, 0
    end

    local oResult, nNumPos = self:Move(nHandleID, wNumTargetPos, paTargetPos, bLine)
    if C.OR_SUCCEEDED(oResult) then
        self:Baby_Go(paTargetPos)
        if nNumPos and nNumPos > 0 then
            self:TeamMemeberToMove(nHandleID, paTargetPos, nNumPos)
        end
    end
    Log.back(oResult)
    return oResult, nNumPos
end

function AI_Human:PushCommand_Idle()
    if not self:GetCharacter():IsActiveObj() then
        return C.OR_ERROR
    end
    return self:Stop()
end

-- 主人开始移动时通知宠物跟随
function AI_Human:Baby_Go(paTargetPos)
    local pHuman = self:GetCharacter()
    if pHuman == nil then return end

    local pPet = pHuman:GetMyPet()
    if pPet then
        local pAIPet = pPet:GetAIObj()
        if pAIPet and pAIPet.Baby_Go then
            pAIPet:Baby_Go(paTargetPos)
        end
    end
end


-- 队长驱动模式
function AI_Human:TeamMemeberToMove(nHandleID, paTargetPos, nNodeCount)
    local pLeader = self:GetCharacter()
    local members = pLeader.followed_members
    if members == nil or #members <= 1 then
        return
    end

    local aNodePos = {}
    for i = 1, nNodeCount do
        aNodePos[i] = { m_fX = paTargetPos[i].m_fX, m_fZ = paTargetPos[i].m_fZ }
    end

    local pHuman = pLeader
    for iMember = 2, #members do
        local pMoveMember = members[iMember]
        if pMoveMember == nil then break end

        local posMember = pMoveMember:getWorldPos()
        local posPrev   = pHuman:getWorldPos()

        local subNodes = pMoveMember:GetScene():GetMap():GetPathFinder():FindPath(
            { m_fX = posMember.m_fX, m_fZ = posMember.m_fZ },
            { m_fX = posPrev.m_fX,   m_fZ = posPrev.m_fZ },
            pMoveMember:GetDriverLevel())

        local aAppend = {}
        if subNodes then
            for i = 1, #subNodes do
                aAppend[#aAppend + 1] = { m_fX = subNodes[i].m_fX, m_fZ = subNodes[i].m_fZ }
            end
        end

        for i = 1, #aNodePos do
            if #aAppend >= C.MAX_CHAR_PATH_NODE_NUMBER then break end
            aAppend[#aAppend + 1] = { m_fX = aNodePos[i].m_fX, m_fZ = aNodePos[i].m_fZ }
        end
        if #aAppend < 2 then break end

        local lastPos   = aAppend[#aAppend]
        local beforePos = aAppend[#aAppend - 1]
        local fDist = Vec.MySqrt(beforePos, lastPos)
        if fDist < 1.0 then
            table.remove(aAppend)
        elseif fDist < 1.5 then
            local k = 1.5 / fDist
            lastPos.m_fX = beforePos.m_fX + (lastPos.m_fX - beforePos.m_fX) * k
            lastPos.m_fZ = beforePos.m_fZ + (lastPos.m_fZ - beforePos.m_fZ) * k
        end
        if #aAppend < 1 then break end

        pMoveMember:Do_Move(nHandleID, #aAppend, aAppend, true)

        aNodePos = aAppend
        pHuman   = pMoveMember
    end
end

-- 空闲时如果有巡逻路线就继续巡逻（战斗结束/丢失目标后自动回到巡逻）
function AI_Human:AI_Logic_Idle(uTime)
    if self:HasPatrolRoute() then
        self:AI_Logic_Patrol(uTime)
        return
    end
    return self:_AI_Logic_Idle(uTime)
end

return AI_Human
