local Class = require("Tool.Class")
local Vec = require("Tool.Vec")
local StateMgr = require("AI.State.StateMgr")
local C = require("Define.Constants")
local Log = require("Tool.Log")

--TODO: 改成 AICharacter
---@class AI_Character
local AI_Character = Class("AI_Character")

function AI_Character:_init(pCharacter)
    self.m_pCharacter = pCharacter
    ---@type State
    self.m_state = StateMgr.GetInstance():InstanceState(C.ESTATE.IDLE)
end

function  AI_Character:GetCharacter()
    return self.m_pCharacter
end

function AI_Character:GetAIState()
    return self.m_state
end

function AI_Character:ChangeState(eState)
    if eState == self.m_state:GetStateID() then
        return
    end
    local s = StateMgr.GetInstance():InstanceState(eState)
    if s then
        self.m_state = s
    end
end

function AI_Character:UseSkill(idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
    return self.m_state:UseSkill(self, idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
end

function AI_Character:Obj_UseSkill(idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
    return self.m_state:Obj_UseSkill(self, idSkill, nLevel, idTarget, fTargetX, fTargetZ, fDir, guidTarget)
end

function AI_Character:CanUseSkill()
    return self.m_state:CanUseSkill(self)
end

-- 对应 AI_Character::Move(nHandleID, wNumTargetPos, paTargetPos, bLine)
--   返回 oResult, nNumPos（nNumPos 是"真正可走的路径点数"，可能被截断）
function AI_Character:Move(nHandleID, wNumTargetPos, paTargetPos, bLine)
    local pCharacter = self:GetCharacter()
    if pCharacter == nil then return C.OR_ERROR, 0 end
    if pCharacter:IsLimitMove() then return C.OR_LIMIT_MOVE, 0 end
    if wNumTargetPos == nil or wNumTargetPos <= 0 or paTargetPos == nil then
        return C.OR_ERROR, 0
    end

    local nNumPos = wNumTargetPos
    local pMap    = pCharacter:GetScene():GetMap()
    local pf      = pMap:GetPathFinder()
    local nLevel  = pCharacter:GetDriverLevel()

    local pCur   = pCharacter:getWorldPos()
    local posCur = { m_fX = pCur.m_fX, m_fZ = pCur.m_fZ }

    if pMap:IsCanGo(posCur, nLevel) then
        local w = 0
        for i = 1, wNumTargetPos do
            local nodes, numNode = pf:FindPath(posCur, paTargetPos[i], nLevel, bLine)
            if (not nodes) or numNode <= 0 then
                break
            end
            if not Vec.MyPosEqual(nodes[numNode], paTargetPos[i]) then
                break
            end
            posCur = { m_fX = paTargetPos[i].m_fX, m_fZ = paTargetPos[i].m_fZ }
            w = i
        end

        if w == 0 then
            return C.OR_ERROR, 0
        end
        nNumPos = w
    end

    local oResult = self.m_state:Move(self, nHandleID, nNumPos, paTargetPos)
    if C.OR_SUCCEEDED(oResult) and nNumPos ~= wNumTargetPos then
        return C.OR_CUT_PATHROUTE, nNumPos
    end
    return oResult, nNumPos
end

-- 对应 AI_Character::Move(const WORLD_POS* pTar)：服务器自己算 A* 路径
function AI_Character:MoveTo(pTar)
    local pCharacter = self:GetCharacter()
    if pCharacter == nil then return C.OR_ERROR, 0 end
    if pCharacter:IsLimitMove() then return C.OR_LIMIT_MOVE, 0 end
    if pTar == nil then return C.OR_ERROR, 0 end

    local pMap   = pCharacter:GetScene():GetMap()
    local nLevel = pCharacter:GetDriverLevel()
    local pCur   = pCharacter:getWorldPos()
    local posCur = { m_fX = pCur.m_fX, m_fZ = pCur.m_fZ }

    local target = { m_fX = pTar.m_fX, m_fZ = pTar.m_fZ }
    pMap:VerifyPos(target)

    if not pMap:IsCanGo(target, nLevel) then
        return C.OR_IMPASSABLE_ZONE, 0
    end

    local nodes, numNode = pMap:GetPathFinder():FindPath(posCur, target, nLevel)
    if (not nodes) or numNode <= 0 then
        return C.OR_ERROR, 0
    end

    return self:Move(-1, numNode, nodes, false)
end

--------------------------------------------------------------------------------
-- 固定巡逻（对应 C++ AI 的 PATROL 状态 + patrol.ini 里的路线）
--   路线 = 一串世界坐标点；到点后停留 dwell 毫秒再走向下一个，走完一圈从头循环。
--   移动复用服务器自己的 A*（MoveTo），所以会自动绕开地图阻挡。
--------------------------------------------------------------------------------
local PATROL_ARRIVE_EPS = 0.6      -- 判定"到达"的距离（米）

-- route: { {m_fX=.., m_fZ=..}, ... }；dwell: 每个点的停留毫秒
function AI_Character:SetPatrolRoute(route, dwell)
    if route == nil or #route < 2 then
        self.m_patrol = nil
        return
    end
    self.m_patrol = {
        route     = route,
        idx       = 1,
        dwell     = dwell or 1000,
        next_time = 0,
    }
end

function AI_Character:HasPatrolRoute()
    return self.m_patrol ~= nil and #self.m_patrol.route >= 2
end

-- PATROL 状态每帧调用一次
function AI_Character:AI_Logic_Patrol(uTime)
    local pt = self.m_patrol
    if (pt == nil) or (#pt.route < 2) then return false end

    local pChar = self:GetCharacter()
    if pChar == nil or pChar:IsDie() then return false end

    -- 正在走：交给 Obj_Logic_Move 推进，走完才轮到我们
    if (not pChar:IsCharacterLogicStopped())
       and pChar:GetCharacterLogic() == C.CHARACTER_LOGIC.MOVE then
        return true
    end

    -- 到点后的停留
    if uTime < pt.next_time then return true end

    local wp   = pt.route[pt.idx]
    local pos  = pChar:getWorldPos()
    local dist = Vec.MySqrt({ m_fX = pos.m_fX, m_fZ = pos.m_fZ }, wp)

    if dist <= PATROL_ARRIVE_EPS then
        -- 已到达：停留一会儿，再把目标换成下一个点
        pChar:SetCharacterLogic(C.CHARACTER_LOGIC.IDLE)
        pt.next_time = uTime + pt.dwell
        pt.idx = (pt.idx % #pt.route) + 1
        return true
    end

    -- 还没到：让服务器 A* 走一步（会自动绕开阻挡）
    local oResult = self:MoveTo(wp)
    if C.OR_FAILED(oResult) then
        -- 这个点走不到（被墙挡住 / 通行等级不够）：跳过它
        Log.msg(string.format("[巡逻] %s 路点 %d 不可达，跳过", pChar:GetName(), pt.idx))
        pt.next_time = uTime + pt.dwell
        pt.idx = (pt.idx % #pt.route) + 1
    end
    return true
end

function AI_Character:Stop()
    return self.m_state:Stop(self)
end

function AI_Character:Logic(uTime)
    return self.m_state:Logic(self, uTime)
end

return AI_Character