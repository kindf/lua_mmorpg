local Log = require("shared.Log")
local C = require("shared.Constants")
local Protocol = require("network.Protocol")

local CCGCharMoveHandler = {}
CCGCharMoveHandler.ThreadID = 1
-- 对应 CGCharMoveCCGCharMoveHandler::Execute

---@param pPacket CGCharMove
function CCGCharMoveHandler.ExecuteMove(pPacket, pPlayer)
    Log.fn("CGCharMoveCCGCharMoveHandler::Execute")

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
        Log.error(string.format("Obj = %d (pScene == NULL)", pHuman:GetID()))
        Log.back(C.PACKET_EXE_CONTINUE)
        return C.PACKET_EXE_CONTINUE
    end

    -- 先记下服务器认定的当前位置：移动失败要把它拉回来
    local pCur   = pHuman:getWorldPos()
    local posCur = { m_fX = pCur.m_fX, m_fZ = pCur.m_fZ }
    pScene:GetMap():VerifyPos(posCur)

    -- 摆摊中禁止移动
    if pHuman:IsStallOpen() then
        pHuman:SendOperateResultMsg(C.OR_CAN_NOT_MOVE_STALL_OPEN)
        Log.error("摆摊中，禁止移动")
        Log.back(C.PACKET_EXE_CONTINUE)
        return C.PACKET_EXE_CONTINUE
    end

    local nHandleID    = pPacket:getHandleID()
    local wNumPathNode = pPacket:getNumTargetPos()
    local paTarPos     = pPacket:getTargetPos()

    local oResult, nNumPos
    if pPacket:getFindPath() and wNumPathNode > 0 and paTarPos[wNumPathNode] then
        -- findpath=1：客户端只给终点，由服务器 A* 算路径（会自动绕开阻挡）
        oResult, nNumPos = pHuman:GetHumanAI():MoveTo(paTarPos[wNumPathNode])
    else
        -- 客户端给了完整路径：逐段校验，走不到就截断
        oResult, nNumPos = pHuman:GetHumanAI():PushCommand_Move(nHandleID, wNumPathNode, paTarPos, true)
    end

    if C.OR_FAILED(oResult) then
        local msgResult = {
            pid       = Protocol.SMSG.CHAR_MOVE_RESULT,
            objID     = pHuman:GetID(),
            result    = oResult,
            handle_id = nHandleID,
        }

        if oResult == C.OR_CUT_PATHROUTE and nNumPos and nNumPos > 0 then
            -- 路径被截断：把"仍然可走的那几个点"回给客户端，让它自己纠正路线
            msgResult.num = nNumPos
            for w = 1, nNumPos do
                local p = paTarPos[w]
                if p then
                    msgResult["x" .. w] = p.m_fX
                    msgResult["z" .. w] = p.m_fZ
                end
            end
        else
            -- 其它失败（含第一段就走不到）：强制 Idle 并把位置拉回 posCur
            pHuman:GetHumanAI():PushCommand_Idle()
            pHuman:Teleport(posCur)
            msgResult.x = posCur.m_fX
            msgResult.z = posCur.m_fZ
        end

        if pPlayer.SendPacket then pPlayer:SendPacket(msgResult) end
    end

    if wNumPathNode > 0 and paTarPos[wNumPathNode] then
        local last = paTarPos[wNumPathNode]
        Log.msg(string.format("CGCharMoveCCGCharMoveHandler::ObjID=%d 目标(%.2f, %.2f)",
            pHuman:GetID(), last.m_fX, last.m_fZ))
    else
        Log.msg(string.format("CGCharMoveCCGCharMoveHandler::ObjID=%d 没有目标点", pHuman:GetID()))
    end

    Log.back(C.PACKET_EXE_CONTINUE)
    return C.PACKET_EXE_CONTINUE
end

return CCGCharMoveHandler