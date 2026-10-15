local Class = require("Tool.Class")
local C = require("Define.Constants")
local ActionDelegator = require("Action.ActionDelegator")
local Log = require("Tool.Log")
local SkillCore = require("Skill.SkillCore")
local Combat = require("Skill.CombatCore")
local Vec = require("Tool.Vec")
local AOI = require("Scene.AOI")
local TargetAndDepletingParams = require("Obj.ObjParam.TargetAndDepletingParam")
local MoveParam = require("Obj.ObjParam.MoveParam")
local SkillParam = require("Obj.ObjParam.SkillParam")
local SkillHelper = require("Skill.SkillHelper")
local Protocol = require("Network.Protocol")
local SS = Protocol.SMSG

---@class ObjCharacter
local ObjCharacter = Class("ObjCharacter")

function ObjCharacter:_init(cfg)
    self.id = cfg.id
    self.name = cfg.name
    self.obj_type = cfg.obj_type or C.OBJ_TYPE.HUMAN
    self.camp_id = cfg.camp_id or 1
    self.level = cfg.level or 1
    self.scene = cfg.scene

    self.alive = true
    -- 默认未激活，由 Scene:ObjectEnterScene -> SetActiveFlag(true) 激活并注册进 Zone。
    -- 注意：不能默认 true —— AoI.Obj_SetActiveFlag 开头是 "if is_active == bNew then return"，
    --       默认 true 会让首次 SetActiveFlag(true) 直接跳过，对象永远进不了 Zone，AOI 全废。
    self.is_active = false
    self.hp = cfg.hp or 1000
    self.max_hp = cfg.hp or 1000
    self.mp = cfg.mp or 1000
    self.rage = cfg.rage or 0
    self.weapon = cfg.weapon or false
    self.known_skills = cfg.known_skills or {}
    self.attack_range = cfg.attack_range or 8.0

    self.position = cfg.position or {m_fX = 0.0, m_fZ = 0.0}
    self.direction = cfg.direction or 0.0
    self.pet = nil
    self.ai = nil

    self.locked_target = C.INVALID_ID
    self.action_end_time = 0
    self.character_logic = C.CHARACTER_LOGIC.IDLE
    self.logic_stopped = false
    self.logic_count = 0

    self.cooldowns = {}
    self.auto_repeat_ready = 0

    self.skill_info = SkillParam.new()
    self.params = TargetAndDepletingParams.new()

    ----------------------------------------------------------------------------
    -- 以下为移动 / 空间 / AOI 相关字段
    ----------------------------------------------------------------------------
    self.driver_level = cfg.driver_level or 0    -- 决定能过哪些格子: IsCanGo = (level >= state)
    self.move_speed   = cfg.move_speed   or 6.0  -- 米/秒
    self.can_move     = true
    self.stall_open   = false                    -- 摆摊中禁止移动

    self.zone_id      = C.INVALID_ID
    self.now_time     = 0
    self.last_time    = 0
    self.create_time  = 0
    self._time_inited = false                    -- 首帧标记（不能用 now_time==0，仿真时间从 0 起）

    self.param_move = MoveParam.new()

    self.team_follow      = nil
    self.followed_members = nil

    self.area_id             = C.INVALID_ID
    self.area_script         = C.INVALID_ID
    self.area_check_interval = cfg.area_check_interval or 500
    self.area_next_check     = 0
end

function ObjCharacter:GetID() return self.id end
function ObjCharacter:GetName() return self.name end
function ObjCharacter:GetObjType() return self.obj_type end
function ObjCharacter:GetLevel() return self.level end
function ObjCharacter:GetScene() return self.scene end
function ObjCharacter:setScene(s) self.scene = s end
function ObjCharacter:setZoneID(z) self.zone_id = z end
function ObjCharacter:getZoneID()  return self.zone_id end
function ObjCharacter:setDir(d)    self.direction = d end
function ObjCharacter:getDir()     return self.direction end
function ObjCharacter:setWorldPos(p) self.position = { m_fX = p.m_fX, m_fZ = p.m_fZ } end
function ObjCharacter:GetDriverLevel()  return self.driver_level end
function ObjCharacter:SetDriverLevel(l) self.driver_level = l end
function ObjCharacter:GetPlayer()  return self.player end
function ObjCharacter:getWorldPos() return self.position end
function ObjCharacter:IsCharacter() return true end
function ObjCharacter:IsAlive() return self.alive end
function ObjCharacter:IsDie() return not self.alive end
function ObjCharacter:IsActiveObj() return self.is_active end
function ObjCharacter:GetCampID() return self.camp_id end
function ObjCharacter:GetCampData() return {m_nCampID = self.camp_id} end

function ObjCharacter:IsEnemy(tar)
    if tar == nil then
        return false
    end
    return self:GetCampID() ~= tar:GetCampID()
end

function ObjCharacter:IsFriend(tar)
    return not self:IsEnemy(tar)
end

function ObjCharacter:GetHP() return self.hp end
function ObjCharacter:GetMaxHP() return self.max_hp end
function ObjCharacter:GetMP() return self.mp end
function ObjCharacter:GetRage() return self.rage end
function ObjCharacter:GetMyPet() return self.pet end
function ObjCharacter:GetMyMaster() return nil end
function ObjCharacter:GetAIObj() return self.ai end
function ObjCharacter:GetHumanAI() return self.ai end
function ObjCharacter:GetPetAI() return self.ai end
function ObjCharacter:GetLockedTarget() return self.locked_target end
function ObjCharacter:HasWeapon() return self.weapon end

function ObjCharacter:SetMP(v) self.mp = v end
function ObjCharacter:SetRage(v) self.rage = v end
function ObjCharacter:SetLockedTarget(id) self.locked_target = id end

function ObjCharacter:GetSpecificObjInSameSceneByID(id)
    if id == nil or id == C.INVALID_ID then
        return nil
    end
    return self.scene:GetObjManager():GetObj(id)
end

function ObjCharacter:GetSkillInfo()
    return self.skill_info
end

function ObjCharacter:GetTargetAndDepletingParams()
    return self.params
end

-- 装备/属性修正数值
function ObjCharacter:RefixSkill(si)
end

function ObjCharacter:Skill_HaveSkill(skillID, level)
    return self.known_skills[skillID] == true
end

function ObjCharacter:Skill_CanUseThisSkillInThisStatus(skillID)
    return true
end

function ObjCharacter:Skill_IsSkillCooldowned(skillID)
    local tmpl = SkillHelper.GetSkillTemplate(skillID)
    if tmpl == nil then
        return true
    end

    if tmpl.is_auto_shot_skill then
        return ActionDelegator.GetInstance():Now() > self.auto_repeat_ready
    end
    local inst = SkillHelper.GetSkillInstance(skillID, 1)
    if inst == nil then
        return true
    end
    local cid = inst.cooldown_id
    if cid == nil or cid == 0 then
        return true
    end
    return ActionDelegator.GetInstance():Now() >= (self.cooldowns[cid] or 0)
end

function ObjCharacter:SetCooldown(cooldownID, ms)
    self.cooldowns[cooldownID] = ActionDelegator.GetInstance():Now() + ms
end

function ObjCharacter:SetAutoRepeatCooldown(ms)
    self.auto_repeat_ready = ActionDelegator.GetInstance():Now() + ms
end

local function dist2(a, b)
    local dx, dz = a.m_fX - b.m_fX, a.m_fZ - b.m_fZ
    return dx * dx + dz * dz
end

function ObjCharacter:IsOutOfRange(tar)
    return dist2(self.position, tar:getWorldPos()) > self.attack_range * self.attack_range
end

function ObjCharacter:IsOutOfRangePos(pos)
    return dist2(self.position, pos) > (12.0 * 12.0)
end

function ObjCharacter:GetCharacterLogic() return self.character_logic end
function ObjCharacter:SetCharacterLogic(l)
    self.character_logic = l
    self.logic_stopped = false
end

function ObjCharacter:IsCharacterLogicStopped() return self.logic_stopped end
function ObjCharacter:StopCharacterLogic(bAbortive)
    self.logic_stopped = true
end

function ObjCharacter:AddLogicCount()
    self.logic_count = self.logic_count + 1
end

function ObjCharacter:GetLogicCount()
    return self.logic_count
end

function ObjCharacter:SetActionTime(t)
    self.action_end_time = ActionDelegator.GetInstance():Now() + t
end

function ObjCharacter:GetActionTime()
    return math.max(0, self.action_end_time - ActionDelegator.GetInstance():Now())
end

function ObjCharacter:CanUseSkillNow()
    if self:GetActionTime() > 0 then
        return false
    end
    return ActionDelegator.GetInstance():CanDoNextAction(self)
end

function ObjCharacter:Do_UseSkill(idSkill, nLevel, idTarget, pTargetPos, fDir, guidTarget)
    Log.fn("ObjCharacter::Do_UseSkill", string.format("%s skill=%s lv=%s", self.name, idSkill, nLevel))

    -- 施法打断移动（对应 C++：Do_UseSkill 会先停掉移动逻辑，避免"边走边放技能"）
    if self:GetCharacterLogic() == C.CHARACTER_LOGIC.MOVE then
        self.param_move:Reset()
        self:SetCharacterLogic(C.CHARACTER_LOGIC.IDLE)
    end

    if not self:IsCharacterLogicStopped() then
        self:StopCharacterLogic(true)
    end
    self:AddLogicCount()

    local pos = {m_fX = 0.0, m_fZ = 0.0}
    if pTargetPos then
        pos.m_fX = pTargetPos.m_fX
        pos.m_fZ = pTargetPos.m_fZ
    end

    if not SkillCore.GetInstance():ProcessSkillRequest(self, idSkill, nLevel, idTarget, pos, fDir, guidTarget) then
        local r = self:GetTargetAndDepletingParams():GetErrCode()
        Log.back(r)
        return r
    end

    if self:GetCharacterLogic() ~= C.CHARACTER_LOGIC.USE_SKILL or self:IsCharacterLogicStopped() then
        self:SetCharacterLogic(C.CHARACTER_LOGIC.USE_SKILL)
    end

    if ActionDelegator.GetInstance():CanDoNextAction(self) then
        if self:GetCharacterLogic() == C.CHARACTER_LOGIC.USE_SKILL or (not self:IsCharacterLogicStopped()) then
            self:StopCharacterLogic(false)
        end
    end
    Log.back(C.OR_OK)
    return C.OR_OK
end

function ObjCharacter:OnUseSkillSuccessfully(si)
    Log.msg("ObjCharacter::OnUseSkillSuccessfully")
    Combat.Impact_OnUseSkillSuccessfully(self, si)
end

function ObjCharacter:OnCriticalHitTarget(skillID, tar)
    Log.msg(string.format("[会心] %s 对 %s 触发会心 (skill %s)", self.name, tar:GetName(), skillID))
end

function ObjCharacter:OnDamage(dmg, attacker)
    self.hp = self.hp - dmg
    Log.msg(string.format("%s 受到 %s 伤害", self.name, dmg))
    if self.hp <= 0 then
        self.hp = 0
        self.alive = false
        Log.msg(string.format("%s 死亡", self.name))
    end
end

function ObjCharacter:OnHeal(amount, caster)
    self.hp = math.min(self.hp + amount, self.max_hp)
    Log.msg(string.format("%s 恢复 %s 生命", self.name, amount))
end

function ObjCharacter:SendOperateResultMsg(code)
    Log.error(string.format("%s 发送操作结果 %s", self.name, code))
end

function ObjCharacter:BroadCastMessage(pPacket, bSendMe)
    return false
end

function ObjCharacter:UpdateTime(uTime)
    if not self._time_inited then
        self._time_inited = true
        self.create_time  = uTime
        self.last_time    = uTime
    else
        self.last_time = self.now_time
    end
    self.now_time = uTime
end

function ObjCharacter:GetLogicTime() return self.now_time - self.last_time end

function ObjCharacter:GetMoveSpeed()
    if self.team_follow and not self.team_follow.is_leader then
        return self.team_follow.follow_speed or self.move_speed
    end
    return self.move_speed
end

function ObjCharacter:CanMove()          return self.can_move ~= false end
function ObjCharacter:MarkCanMoveFlag()  self.can_move = true end
function ObjCharacter:ClearCanMoveFlag() self.can_move = false end
function ObjCharacter:IsLimitMove()      return not self:CanMove() end
function ObjCharacter:IsStallOpen()      return self.stall_open == true end

function ObjCharacter:SetLogicCount(n) self.logic_count = n end

function ObjCharacter:CheckArea()
    if self.zone_id == C.INVALID_ID or self.scene == nil then return end

    local pArea   = self.scene:CheckArea(self)
    local uAreaID = C.INVALID_ID
    if pArea then uAreaID = pArea:GetAreaID() end

    if uAreaID ~= self.area_id then
        if self.area_id ~= C.INVALID_ID then
            Log.msg(string.format("[区域] %s 离开 area %d (script %d)",
                self.name, self.area_id, self.area_script))
        end
        self.area_id = uAreaID
        if pArea then
            self.area_script = pArea:GetScriptID()
            Log.msg(string.format("[区域] %s 进入 area %d (script %d)",
                self.name, self.area_id, self.area_script))
        else
            self.area_script = C.INVALID_ID
        end
    end
end

function ObjCharacter:OnEnterScene() end
function ObjCharacter:OnLeaveScene() end

-- AOI 转发（实现全在 ch5_aoi）
function ObjCharacter:UpdateZone()         return AOI.Obj_UpdateZone(self) end
function ObjCharacter:SetActiveFlag(bFlag) return AOI.Obj_SetActiveFlag(self, bFlag) end
function ObjCharacter:Teleport(pos)        return AOI.Obj_Teleport(self, pos) end

-- 对应 Obj::CreateNewObjPacket / CreateDeleteObjPacket（AOI 下发的"出现/消失"包）
function ObjCharacter:CreateNewObjPacket()
    return {
        pid   = SS.OBJ_ENTER,
        id    = self.id,
        name  = self.name,
        type  = self.obj_type,
        camp  = self.camp_id,
        hp    = self.hp,
        maxHp = self.max_hp,
        x     = self.position.m_fX,
        z     = self.position.m_fZ,
        alive = self.alive and 1 or 0,
    }
end
function ObjCharacter:CreateDeleteObjPacket()
    return { pid = SS.OBJ_LEAVE, id = self.id }
end
-- 对应 Obj::IsCanViewMe：真实服务器还有隐身/阵营/等级条件，这里默认互相可见（不含自己）
function ObjCharacter:IsCanViewMe(pOther) return pOther ~= nil and pOther ~= self end

function ObjCharacter:Do_Move(nHandleID, wNumTargetPos, paTargetPos, bFlag)
    Log.fn("ObjCharacter::Do_Move", string.format("%s nodes=%s", self.name, tostring(wNumTargetPos)))

    if wNumTargetPos == nil or wNumTargetPos <= 0 or paTargetPos == nil then
        Log.back(C.OR_ERROR)
        return C.OR_ERROR
    end

    local bStopMove       = false
    local nStopLogicCount = self:GetLogicCount()

    if not self:IsCharacterLogicStopped() then
        if self:GetCharacterLogic() ~= C.CHARACTER_LOGIC.MOVE then
            self:StopCharacterLogic(true)
        else
            -- 已经在移动：这是"改/续路径"，要告诉客户端先停掉旧路径
            bStopMove = true
            self:StopCharacterLogic(false)
        end
    end

    if self:IsDie() then
        Log.back(C.OR_DIE)
        return C.OR_DIE
    end

    if self:IsLimitMove() then
        Log.back(C.OR_LIMIT_MOVE)
        return C.OR_LIMIT_MOVE
    end

    -- 移动打断施法：清空技能队列
    if self.ai and self.ai.m_paramAI_UseSkill then
        self.ai.m_paramAI_UseSkill:CleanUp()
    end

    if nHandleID ~= -1 then
        self:SetLogicCount(nHandleID)      -- 客户端序号，用于服务端/客户端移动对账
    else
        self:AddLogicCount()
    end

    local mp = self.param_move
    mp:Reset()
    for i = 1, wNumTargetPos do
        if paTargetPos[i] then mp:AddTargetPos(paTargetPos[i]) end
    end

    local pTargetPos = mp:GetCurTargetPos()
    if pTargetPos == nil then
        Log.back(C.OR_ERROR)
        return C.OR_ERROR
    end

    self:setDir(Vec.MyAngle(self.position, pTargetPos))
    self:SetCharacterLogic(C.CHARACTER_LOGIC.MOVE)

    -- 广播 SMSG_CHAR_MOVE（bStopMove 时附带"停旧路径"信息）
    local msg = {
        pid    = SS.CHAR_MOVE,
        id     = self.id,
        start  = self.now_time,
        handle = self:GetLogicCount(),
        speed  = self:GetMoveSpeed(),   -- 客户端据此做补间（关键帧同步）
        x      = pTargetPos.m_fX,
        z      = pTargetPos.m_fZ,
    }
    if bStopMove then
        msg.stop_handle = nStopLogicCount
        msg.stop_x      = self.position.m_fX
        msg.stop_z      = self.position.m_fZ
    end
    if self.scene then self.scene:BroadCast(msg, self, true) end

    Log.back(C.OR_OK)
    return C.OR_OK
end

function ObjCharacter:Do_Stop()
    if not self:IsCharacterLogicStopped() then
        self:StopCharacterLogic(true)
    end
    self:SetCharacterLogic(C.CHARACTER_LOGIC.IDLE)
    return C.OR_OK
end

function ObjCharacter:Obj_Logic_Move(uTime)
    if self:IsDie() then return false end
    if self:IsLimitMove() then return false end

    local mp = self.param_move
    if mp:IsEmpty() then return false end

    local fSpeed     = self:GetMoveSpeed()
    local uLogicTime = self:GetLogicTime()
    local fMoveDist  = (fSpeed * uLogicTime) / 1000.0
    if fMoveDist <= 0.01 then
        return true
    end

    local pCurPos       = self.position
    local pTargetPos    = mp:GetCurTargetPos()
    local fDistToTarget = Vec.MySqrt(pCurPos, pTargetPos)

    while true do
        if fMoveDist > fDistToTarget then
            if not mp:NextTargetPos() then
                -- 没有下一段路：抵达终点
                local posMustTo = { m_fX = pTargetPos.m_fX, m_fZ = pTargetPos.m_fZ }
                if self.scene then
                    self.scene:GetMap():VerifyPos(posMustTo)
                end
                self:setDir(Vec.MyAngle(self.position, posMustTo))
                self:setWorldPos(posMustTo)
                self:StopCharacterLogic(false)
                break
            else
                -- 本帧还能走，继续消耗位移到下一段
                fMoveDist     = fMoveDist - fDistToTarget
                pCurPos       = pTargetPos
                pTargetPos    = mp:GetCurTargetPos()
                fDistToTarget = Vec.MySqrt(pCurPos, pTargetPos)

                self:AddLogicCount()
                if self.scene then
                    self.scene:BroadCast({
                        pid    = SS.CHAR_MOVE,
                        id     = self.id,
                        start  = self.now_time,
                        handle = self:GetLogicCount(),
                        speed  = self:GetMoveSpeed(),
                        x      = pTargetPos.m_fX,
                        z      = pTargetPos.m_fZ,
                    }, self, true)
                end
            end
        else
            local cur = { m_fX = 0.0, m_fZ = 0.0 }
            if fDistToTarget > 0.0 then
                cur.m_fX = pCurPos.m_fX + (fMoveDist * (pTargetPos.m_fX - pCurPos.m_fX)) / fDistToTarget
                cur.m_fZ = pCurPos.m_fZ + (fMoveDist * (pTargetPos.m_fZ - pCurPos.m_fZ)) / fDistToTarget
            else
                cur.m_fX = pTargetPos.m_fX
                cur.m_fZ = pTargetPos.m_fZ
            end

            self:setDir(Vec.MyAngle(pCurPos, pTargetPos))
            if self.scene then
                self.scene:GetMap():VerifyPos(cur)
            end
            self:setWorldPos(cur)
            break
        end
    end
    return true
end

function ObjCharacter:Obj_Logic_Idle(uTime) return true end

function ObjCharacter:HeartBeat(uTime)
    self:UpdateTime(uTime)
    self:UpdateZone()

    if uTime >= self.area_next_check then
        self.area_next_check = uTime + self.area_check_interval
        if self.obj_type == C.OBJ_TYPE.HUMAN and self.scene then
            self:CheckArea()
        end
    end

    if not self:IsCharacterLogicStopped() then
        local logic = self:GetCharacterLogic()
        local ok = true
        if logic == C.CHARACTER_LOGIC.IDLE then
            self:Obj_Logic_Idle(uTime)
        elseif logic == C.CHARACTER_LOGIC.MOVE then
            ok = self:Obj_Logic_Move(uTime)
        end
        if not ok then
            self:StopCharacterLogic(true)
        end
    end

    if self.ai then
        self.ai:Logic(uTime)
    end
    return true
end

function ObjCharacter:getScene() return self.scene end


return ObjCharacter