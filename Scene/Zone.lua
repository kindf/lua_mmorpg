-- Zone 是"地图切成的网格单元"：
--   * m_ObjList   —— 该格里所有对象（怪物/玩家/宠物/道具箱/平台/机关）
--   * m_HumanList —— 该格里只有玩家（广播/扫描玩家时更省）
--   * m_apArea    —— 覆盖该格的 Area 列表（事件区域）
--
-- AOI 的"九宫格"就是"以某个 Zone 为中心，扩 N 圈 Zone"，
-- 见 scan.lua 的 GetRectInRadius。

local C     = require("Define.Constants")
local Log   = require("Tool.Log")
local Class = require("Tool.Class")

---@class Zone
local Zone = Class("Zone")

function Zone:_init(id)
    self.m_ZoneID   = id
    self.m_ObjList  = {}     -- 数组，元素为 Obj
    self.m_HumanList= {}     -- 数组，元素为 Obj_Human
    self.m_AreaCount= 0
    self.m_apArea   = {}
end

function Zone:GetZoneID()   return self.m_ZoneID end
function Zone:GetObjList()  return self.m_ObjList end
function Zone:GetHumanList()return self.m_HumanList end
function Zone:GetAreaCount()return self.m_AreaCount end

local function listAdd(list, obj)
    for i = 1, #list do
        if list[i] == obj then return end   -- 幂等，避免重复注册
    end
    list[#list + 1] = obj
end

local function listDel(list, obj)
    for i = 1, #list do
        if list[i] == obj then
            table.remove(list, i)
            return
        end
    end
end

function Zone:OnObjectEnter(pObj)
    local eType = pObj:GetObjType()
    if eType == C.OBJ_TYPE.HUMAN then
        listAdd(self.m_HumanList, pObj)
        listAdd(self.m_ObjList, pObj)
    elseif eType == C.OBJ_TYPE.MONSTER
        or eType == C.OBJ_TYPE.PET
        or eType == C.OBJ_TYPE.ITEM_BOX
        or eType == C.OBJ_TYPE.PLATFORM
        or eType == C.OBJ_TYPE.SPECIAL then
        listAdd(self.m_ObjList, pObj)
    else
        Log.error(string.format("Zone::OnObjectEnter 未知 obj type = %s", tostring(eType)))
    end
end

function Zone:OnObjectLeave(pObj)
    local eType = pObj:GetObjType()
    if eType == C.OBJ_TYPE.HUMAN then
        listDel(self.m_HumanList, pObj)
        listDel(self.m_ObjList, pObj)
    elseif eType == C.OBJ_TYPE.MONSTER
        or eType == C.OBJ_TYPE.PET
        or eType == C.OBJ_TYPE.ITEM_BOX
        or eType == C.OBJ_TYPE.PLATFORM
        or eType == C.OBJ_TYPE.SPECIAL then
        listDel(self.m_ObjList, pObj)
    else
        Log.error(string.format("Zone::OnObjectLeave 未知 obj type = %s", tostring(eType)))
    end
end

function Zone:AddArea(pArea)
    if self.m_AreaCount >= C.MAX_AREA_IN_ZONE then
        Log.error(string.format("Zone %d 上的 Area 太多了（上限 %d）", self.m_ZoneID, C.MAX_AREA_IN_ZONE))
        return
    end
    self.m_AreaCount = self.m_AreaCount + 1
    self.m_apArea[self.m_AreaCount] = pArea
end

-- 返回包含该世界坐标的第一个 Area
function Zone:GetCurrentArea(pWorldPos)
    for i = 1, self.m_AreaCount do
        local pArea = self.m_apArea[i]
        if pArea and pArea:IsContain(pWorldPos.m_fX, pWorldPos.m_fZ) then
            return pArea
        end
    end
    return nil
end

return Zone