-- Map 只做三件事：
--   1) 记录世界尺寸 CX/CZ
--   2) 持有 PathFinder（导航图 + A*）
--   3) 提供边界/可达性校验：VerifyPos / IsCanGo / FindEmptyPos / IsPosLogicValid
--
-- 注意：Map 不关心"谁在哪"，那是 Zone 的事。

local Class = require("Tool.Class")
local PathFinder = require("Scene.PathFinder")
local Vec = require("Tool.Vec")

local VALID_SIZE = 10 

---@class Map
local Map = Class("Map")

function Map:_init(cfg)
    self.m_CX = cfg.cx
    self.m_CZ = cfg.cz

    -- 建导航图：先全 0（谁都能走），再把障碍矩形刷进去
    local pfCfg = {
        cx         = cfg.cx,
        cz         = cfg.cz,
        grid_size  = cfg.grid_size or 0.5,
        left_top_x = 0.0,
        left_top_z = 0.0,
    }
    self.m_pPathFinder = PathFinder.new(pfCfg)
    for _, ob in ipairs(cfg.obstacles or {}) do
        self.m_pPathFinder:SetRectState(ob[1], ob[2], ob[3], ob[4], ob[5])
    end
end
function Map:CX() return self.m_CX end

function Map:CZ() return self.m_CZ end

function Map:GetPathFinder() return self.m_pPathFinder end

-- 把坐标钳制进 [0, CX-0.1] x [0, CZ-0.1]
function Map:VerifyPos(pos)
    Vec.VerifyPos(pos, self.m_CX, self.m_CZ)
end

function Map:IsCanGo(pos, nLevel)
    return self.m_pPathFinder:IsCanGo(pos, nLevel)
end

-- 从 pos 开始向外螺旋，找一个可走的点
function Map:FindEmptyPos(pos, nLevel)
    if self:IsCanGo(pos, nLevel) then return true end

    local MAX_FIND_SIZE = 64
    for i = 1, MAX_FIND_SIZE do
        local offsets = {
            {  i,  0 }, { 0,  i }, { -i,  0 }, { 0, -i },
            {  i,  i }, { -i, -i }, {  i, -i }, { -i,  i },
        }
        for _, off in ipairs(offsets) do
            local test = Vec.new(pos.m_fX + off[1], pos.m_fZ + off[2])
            self:VerifyPos(test)
            if self:IsCanGo(test, nLevel) then
                pos.m_fX, pos.m_fZ = test.m_fX, test.m_fZ
                return true
            end
        end
    end
    return false
end

-- 判断点是否离地图边缘至少 VALID_SIZE 米
function Map:IsPosLogicValid(pos)
    if pos.m_fX < VALID_SIZE or (pos.m_fX + VALID_SIZE) > self.m_CX then return false end
    if pos.m_fZ < VALID_SIZE or (pos.m_fZ + VALID_SIZE) > self.m_CZ then return false end
    return true
end

-- 导出导航图（供客户端表现地图阻挡）
--   返回 { gw, gh, cell, states }；states 按行优先、1 基下标，
--   值 = 通过该格所需的 driverLevel（0 = 谁都能走）
function Map:GetGridInfo()
    local pf = self.m_pPathFinder
    local n  = pf.mWidth * pf.mHeight
    local states = {}
    for i = 1, n do
        states[i] = pf.mWorld[i] or 0
    end
    return { gw = pf.mWidth, gh = pf.mHeight, cell = pf.mGridSize, states = states }
end

return Map