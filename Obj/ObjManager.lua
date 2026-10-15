
local Class = require("Tool.Class")

---@class ObjMgr
local ObjMgr = Class("ObjMgr")

function ObjMgr:_init()
    self._byID  = {}
    self._order = {}
end

function ObjMgr:CleanUp()
    self._byID  = {}
    self._order = {}
end

function ObjMgr:Add(pObj)
    if pObj == nil then return false end
    local id = pObj:GetID()
    if self._byID[id] == nil then
        self._order[#self._order + 1] = pObj
    end
    self._byID[id] = pObj
    return true
end

function ObjMgr:Remove(id)
    local pObj = self._byID[id]
    if pObj == nil then return false end

    self._byID[id] = nil
    for i = 1, #self._order do
        if self._order[i] == pObj then
            table.remove(self._order, i)
            break
        end
    end
    return true
end

function ObjMgr:RemoveObj(pObj)
    if pObj == nil then return false end
    return self:Remove(pObj:GetID())
end

function ObjMgr:GetObj(id) return self._byID[id] end
function ObjMgr:GetAll() return self._order end
function ObjMgr:GetObjByIndex(i) return self._order[i] end   -- 1 基下标
function ObjMgr:GetCount() return #self._order end

return ObjMgr
