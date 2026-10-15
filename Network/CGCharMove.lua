local Class = require("Tool.Class")
local C = require("Define.Constants")

---@class CGCharMove
local CGCharMove = Class("CGCharMove")

function CGCharMove:_init(t)
    self.m_ObjID         = t.objID
    self.m_nHandleID     = t.handleID or 0
    self.m_posWorld      = t.worldPos or { m_fX = 0.0, m_fZ = 0.0 }
    self.m_bFindPath     = t.findPath and true or false
    self.m_yNumTargetPos = 0
    self.m_aTargetPos    = {}
    for _, p in ipairs(t.targetPos or {}) do
        self:AddTargetPos(p)
    end
end

function CGCharMove:getObjID()         return self.m_ObjID end
function CGCharMove:getHandleID()      return self.m_nHandleID end
function CGCharMove:getWorldPos()      return self.m_posWorld end
function CGCharMove:getNumTargetPos()  return self.m_yNumTargetPos end
function CGCharMove:getTargetPos()     return self.m_aTargetPos end
function CGCharMove:getFindPath()      return self.m_bFindPath end

function CGCharMove:AddTargetPos(pPos)
    if self.m_yNumTargetPos < C.MAX_CHAR_PATH_NODE_NUMBER then
        self.m_yNumTargetPos = self.m_yNumTargetPos + 1
        self.m_aTargetPos[self.m_yNumTargetPos] = { m_fX = pPos.m_fX, m_fZ = pPos.m_fZ }
    end
end

return CGCharMove