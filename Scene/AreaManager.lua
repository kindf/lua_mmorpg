local Class = require("Tool.Class")
local C = require("Define.Constants")

--矩形的世界坐标
---@class FRect
local FRect = Class("FRect")

function FRect:_init(t)
    self.m_fLeft   = t.left   or 0.0
    self.m_fTop    = t.top    or 0.0
    self.m_fRight  = t.right  or 0.0
    self.m_fBottom = t.bottom or 0.0
end

function FRect:IsContain(x, y)
    return (x >= self.m_fLeft) and (x < self.m_fRight)
       and (y >= self.m_fTop)  and (y < self.m_fBottom)
end

---@class Area
local Area = Class("Area")

function Area:_init(t)
    self.m_uAreaID   = t.area_id   or C.INVALID_ID
    self.m_uScriptID = t.script_id or C.INVALID_ID
    self.m_rcArea    = FRect.new(t)
end
function Area:IsContain(x, y) return self.m_rcArea:IsContain(x, y) end
function Area:GetAreaID()     return self.m_uAreaID end
function Area:GetScriptID()   return self.m_uScriptID end


---@class AreaManager
local AreaManager = Class("AreaManager")

function AreaManager:_init(pScene)
    self.m_pScene    = pScene
    self.m_uAreaCount= 0
    self.m_paArea    = {}
end

function AreaManager:SetScene(pScene) self.m_pScene = pScene end

function AreaManager:Init(areaList)
    -- 相同配置只装载一次（C++ 用 SceneManager 缓存 AREA_FILE，这里按场景缓存即可）
    if self.m_uAreaCount == 0 and areaList then
        for _, t in ipairs(areaList) do
            local pArea = Area.new(t)
            self.m_uAreaCount = self.m_uAreaCount + 1
            self.m_paArea[self.m_uAreaCount] = pArea
        end
    end

    -- 注册到场景（-> 挂到覆盖的每个 Zone 上）
    for i = 1, self.m_uAreaCount do
        local pArea = self.m_paArea[i]
        self.m_pScene:RegisterArea(pArea)
    end
    return true
end

function AreaManager:Term()
    self.m_uAreaCount = 0
    self.m_paArea = {}
end

-- 返回包含 (x,z) 的 Area 序号，找不到返回 INVALID_ID
function AreaManager:GetZoneID(x, z)
    for i = 1, self.m_uAreaCount do
        local pArea = self.m_paArea[i]
        if pArea:IsContain(x, z) then
            return i
        end
    end
    return C.INVALID_ID
end

return AreaManager