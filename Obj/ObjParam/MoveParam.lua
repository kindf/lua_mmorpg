--------------------------------------------------------------------------------
--   一次移动的路径点队列。注意下标：数组 1 基，m_wCurNode 仍从 0 计数，
--   所以"当前点" = m_aTargetPos[m_wCurNode + 1]。
--------------------------------------------------------------------------------\
local Class = require("Tool.Class")
local C = require("Define.Constants")

---@class MoveParam
local MoveParam = Class("MoveParam")
function MoveParam:_init() self:Reset() end
function MoveParam:Reset()
    self.m_wNumNode   = 0
    self.m_wCurNode   = 0
    self.m_aTargetPos = {}
end
function MoveParam:IsEmpty()
    return (self.m_wNumNode == 0) or (self.m_wNumNode == self.m_wCurNode)
end
function MoveParam:AddTargetPos(pTargetPos)
    if self.m_wNumNode < C.MAX_CHAR_PATH_NODE_NUMBER then
        self.m_wNumNode = self.m_wNumNode + 1
        self.m_aTargetPos[self.m_wNumNode] = { m_fX = pTargetPos.m_fX, m_fZ = pTargetPos.m_fZ }
    end
end
function MoveParam:GetCurTargetPos() return self.m_aTargetPos[self.m_wCurNode + 1] end
function MoveParam:GetFinalTarPos()  return self.m_aTargetPos[self.m_wNumNode] end
function MoveParam:NextTargetPos()
    if self.m_wCurNode < self.m_wNumNode then
        self.m_wCurNode = self.m_wCurNode + 1
    end
    return self.m_wCurNode < self.m_wNumNode
end

return MoveParam