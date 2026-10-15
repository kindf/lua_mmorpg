local C     = require("Define.Constants")
local Vec   = require("Tool.Vec")
local Class = require("Tool.Class")

local MAX_ROUTES = 2048
local OFFSETZ    = 128      -- =A* 的 z 搜索带宽

-- 八方向
local DIRS = {
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
    { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 },
}

---@class PathFinder
local PathFinder = Class("PathFinder")

function PathFinder:_init(cfg)
    self.mGridSize    = cfg.grid_size or 0.5
    self.mInvGridSize = 1.0 / self.mGridSize
    self.mLeftTopx    = cfg.left_top_x or 0.0
    self.mLeftTopz    = cfg.left_top_z or 0.0
    self.mWidth       = math.floor((cfg.cx - self.mLeftTopx) * self.mInvGridSize) + 1
    self.mHeight      = math.floor((cfg.cz - self.mLeftTopz) * self.mInvGridSize) + 1

    self.mWorld      = {}    -- 静态导航图：mWorld[zx] = state(0~15)
    self.mWorkState  = {}    -- A* 工作区：mWorkState[zx] = PATH_OPEN / PATH_CLOSED
    self.mWorkGen    = {}    -- 惰性清理用的代际戳（避免每次寻路全图清零）
    self.mG          = {}
    self.mF          = {}
    self.mParent     = {}
    self.mGen        = 0

    self.mHeap       = {}
    self.mHeapSize   = 0

    self.mFirstCanGoPos = Vec.new(0.0, 0.0)
    self.mDistance      = 0
    self.mEndGx         = 0
    self.mEndGz         = 0

    for i = 1, self.mWidth * self.mHeight do
        self.mWorld[i] = 0
    end
end

--------------------------------------------------------------------------------
-- 坐标 <-> 格子
--------------------------------------------------------------------------------
function PathFinder:_gridX(x) return math.floor((x - self.mLeftTopx) * self.mInvGridSize) end
function PathFinder:_gridZ(z) return math.floor((z - self.mLeftTopz) * self.mInvGridSize) end
function PathFinder:_inGrid(gx, gz)
    return gx >= 0 and gx < self.mWidth and gz >= 0 and gz < self.mHeight
end
-- zx 采用 1 基下标：zx = gz * width + gx + 1
function PathFinder:_idx(gx, gz)  return gz * self.mWidth + gx + 1 end
function PathFinder:_gxOf(zx)     return (zx - 1) % self.mWidth end
function PathFinder:_gzOf(zx)     return math.floor((zx - 1) / self.mWidth) end

--------------------------------------------------------------------------------
-- 导航图写入（建图期使用）
--------------------------------------------------------------------------------
function PathFinder:SetGridState(gx, gz, state)
    if self:_inGrid(gx, gz) then
        self.mWorld[self:_idx(gx, gz)] = state
    end
end

-- 世界坐标矩形 [x1,x2) x [z1,z2) 统一设置 state
function PathFinder:SetRectState(x1, z1, x2, z2, state)
    local gx1 = self:_gridX(x1)
    local gz1 = self:_gridZ(z1)
    local gx2 = self:_gridX(x2 - 1e-6)
    local gz2 = self:_gridZ(z2 - 1e-6)
    for gz = gz1, gz2 do
        for gx = gx1, gx2 do
            self:SetGridState(gx, gz, state)
        end
    end
end

--------------------------------------------------------------------------------
-- 通行判定（对应 PathFinder::IsCanGo）
--------------------------------------------------------------------------------
function PathFinder:IsCanGoState(state, nDriverLevel)
    return nDriverLevel >= state
end

function PathFinder:IsCanGo(pos, nLevel)
    local gx, gz = self:_gridX(pos.m_fX), self:_gridZ(pos.m_fZ)
    if self:_inGrid(gx, gz) then
        return self:IsCanGoState(self.mWorld[self:_idx(gx, gz)], nLevel)
    end
    return false
end

function PathFinder:_f(zx) return self.mF[zx] or 1e12 end

function PathFinder:_heapPush(zx)
    local h = self.mHeap
    local n = self.mHeapSize + 1
    self.mHeapSize = n
    h[n] = zx
    while n > 1 do
        local p = math.floor(n / 2)
        if self:_f(h[p]) <= self:_f(h[n]) then break end
        h[p], h[n] = h[n], h[p]
        n = p
    end
end

--------------------------------------------------------------------------------
-- A* 用的二叉堆(最大堆)
--------------------------------------------------------------------------------
function PathFinder:_f(zx) return self.mF[zx] or 1e12 end

function PathFinder:_heapPush(zx)
    local h = self.mHeap
    local n = self.mHeapSize + 1
    self.mHeapSize = n
    h[n] = zx
    while n > 1 do
        local p = math.floor(n / 2)
        if self:_f(h[p]) <= self:_f(h[n]) then break end
        h[p], h[n] = h[n], h[p]
        n = p
    end
end

function PathFinder:_heapPop()
    local h = self.mHeap
    local n = self.mHeapSize
    if n == 0 then return nil end

    local top = h[1]
    h[1] = h[n]
    h[n] = nil
    self.mHeapSize = n - 1

    local i = 1
    while true do
        local l, r, m = i * 2, i * 2 + 1, i
        if l <= self.mHeapSize and self:_f(h[l]) < self:_f(h[m]) then m = l end
        if r <= self.mHeapSize and self:_f(h[r]) < self:_f(h[m]) then m = r end
        if m == i then break end
        h[i], h[m] = h[m], h[i]
        i = m
    end
    return top
end

-- 惰性清理：进入新一代时把该节点的旧数据视为不存在
function PathFinder:_touch(zx)
    if self.mWorkGen[zx] ~= self.mGen then
        self.mWorkGen[zx]   = self.mGen
        self.mWorkState[zx] = nil
        self.mG[zx]         = nil
        self.mF[zx]         = nil
        self.mParent[zx]    = nil
    end
end

-- octile 启发式：直走代价 10，斜走代价 14
-- octile：通过计算多边形顶点坐标，找到一个点，使其到多边形所有顶点的距离之和最小
function PathFinder:_H(gx, gz)
    local dx = math.abs(gx - self.mEndGx)
    local dz = math.abs(gz - self.mEndGz)
    local mn = math.min(dx, dz)
    local mx = math.max(dx, dz)
    return mx * 10 + mn * 4
end

--------------------------------------------------------------------------------
-- 直线可达判定
--   沿线段按格子分辨率采样；遇到不可走就停下，并把
--   mFirstCanGoPos 记成"直线方向上能走到的最远点"。
--------------------------------------------------------------------------------
function PathFinder:IsStraightLine(x1, z1, x2, z2, nLevel)
    local dx, dz = x2 - x1, z2 - z1
    local len = math.sqrt(dx * dx + dz * dz)
    local steps = math.max(1, math.ceil(len * self.mInvGridSize))

    local lastOk = Vec.new(x1, z1)
    for i = 1, steps do
        local t = i / steps
        local p = Vec.new(x1 + dx * t, z1 + dz * t)
        if not self:IsCanGo(p, nLevel) then
            self.mFirstCanGoPos = lastOk
            return false
        end
        lastOk = p
    end
    return true
end

--------------------------------------------------------------------------------
-- 路径打包：格子路径 -> 世界坐标 + 抽稀
--  返回：nodes, numNode；无法打包时返回 nil, 0
--------------------------------------------------------------------------------
function PathFinder:_PackRoute(szx, ezx, endPt, nLevel)
    -- 1) 由终点回溯到起点
    local rev, zx, guard = {}, ezx, 0
    while zx ~= nil and zx ~= -1 and guard < 200000 do
        rev[#rev + 1] = zx
        if zx == szx then break end
        zx = self.mParent[zx]
        guard = guard + 1
    end

    -- 2) 反转为 起点 -> 终点，并转成格心世界坐标
    local pts = {}
    for i = #rev, 1, -1 do
        local cell = rev[i]
        local gx, gz = self:_gxOf(cell), self:_gzOf(cell)
        pts[#pts + 1] = Vec.new(
            self.mLeftTopx + gx * self.mGridSize + self.mGridSize * 0.5,
            self.mLeftTopz + gz * self.mGridSize + self.mGridSize * 0.5)
    end
    if #pts == 0 then
        return nil, 0
    end

    -- 3) 贪心抽稀：从当前点尽量"直线直达"最远的后续点
    local out = {}
    local i = 1
    while i <= #pts do
        out[#out + 1] = pts[i]
        if i == #pts then break end

        local last = i
        local jmax = math.min(#pts, i + 64)   -- 限制单次前探距离，避免 O(n^2) 直线判定
        for j = i + 1, jmax do
            if self:IsStraightLine(pts[i].m_fX, pts[i].m_fZ, pts[j].m_fX, pts[j].m_fZ, nLevel) then
                last = j
            else
                break
            end
        end
        if last == i then i = i + 1 else i = last end
    end

    -- 4) 最后一个点强制等于请求的精确终点
    out[#out] = Vec.copy(endPt)

    -- 5) 裁剪到 MAX_CHAR_PATH_NODE_NUMBER：保留前段，末点仍然是精确终点
    if #out > C.MAX_CHAR_PATH_NODE_NUMBER then
        local trimmed = {}
        for k = 1, C.MAX_CHAR_PATH_NODE_NUMBER - 1 do trimmed[k] = out[k] end
        trimmed[C.MAX_CHAR_PATH_NODE_NUMBER] = Vec.copy(endPt)
        out = trimmed
    end

    -- 6) 累计距离
    local dist = 0
    for k = 2, #out do
        dist = dist + Vec.MySqrt(out[k - 1], out[k])
    end
    self.mDistance = dist

    return out, #out
end

function PathFinder:FindPath(startPt, endPt, nLevel, bLine, maxRoute)
    maxRoute = maxRoute or MAX_ROUTES

    local sgx, sgz = self:_gridX(startPt.m_fX), self:_gridZ(startPt.m_fZ)
    local egx, egz = self:_gridX(endPt.m_fX),   self:_gridZ(endPt.m_fZ)

    self.mDistance      = 0
    self.mFirstCanGoPos = Vec.new(startPt.m_fX, startPt.m_fZ)
    self.mEndGx, self.mEndGz = egx, egz

    local nodes = {}

    -- 起点必须可走
    if not self:IsCanGo(startPt, nLevel) then
        return nil, 0
    end

    -- bLine：优先走直线（玩家路径用这个分支）
    if bLine then
        if self:IsStraightLine(startPt.m_fX, startPt.m_fZ, endPt.m_fX, endPt.m_fZ, nLevel) then
            nodes[1] = Vec.copy(endPt)
            self.mDistance = Vec.MySqrt(startPt, endPt)
            return nodes, 1
        end
        nodes[1] = Vec.copy(self.mFirstCanGoPos)
        self.mDistance = Vec.MySqrt(startPt, self.mFirstCanGoPos)
        return nodes, 1
    end

    -- 终点也必须可走
    if not self:IsCanGo(endPt, nLevel) then
        return nil, 0
    end

    -- 太远（与 C++ 一致：先判距离，再判直线）
    if (math.abs(egx - sgx) + math.abs(egz - sgz)) > maxRoute then
        return nil, 0
    end

    if self:IsStraightLine(startPt.m_fX, startPt.m_fZ, endPt.m_fX, endPt.m_fZ, nLevel) then
        nodes[1] = Vec.copy(endPt)
        self.mDistance = Vec.MySqrt(startPt, endPt)
        return nodes, 1
    end

    -- A* 搜索
    self.mGen = self.mGen + 1
    self.mHeap, self.mHeapSize = {}, 0

    local minz = math.max(math.min(sgz, egz) - OFFSETZ, 0)
    local maxz = math.min(math.max(sgz, egz) + OFFSETZ, self.mHeight - 1)

    local szx = self:_idx(sgx, sgz)
    local ezx = self:_idx(egx, egz)

    self:_touch(szx)
    self.mG[szx] = 0
    self.mF[szx] = self:_H(sgx, sgz)
    self.mParent[szx] = -1
    self.mWorkState[szx] = C.PATH_OPEN
    self:_heapPush(szx)

    local reached = false
    local iter, maxIter = 0, maxRoute * 8

    while self.mHeapSize > 0 and iter < maxIter do
        iter = iter + 1
        local zx = self:_heapPop()

        if self.mWorkState[zx] ~= C.PATH_CLOSED then
            if zx == ezx then
                reached = true
                break
            end
            self.mWorkState[zx] = C.PATH_CLOSED

            local gx, gz = self:_gxOf(zx), self:_gzOf(zx)
            local g = self.mG[zx]

            for d = 1, #DIRS do
                local dx, dz = DIRS[d][1], DIRS[d][2]
                local nx, nz = gx + dx, gz + dz

                if nx >= 0 and nx < self.mWidth and nz >= minz and nz <= maxz then
                    local nzx = self:_idx(nx, nz)
                    if self:IsCanGoState(self.mWorld[nzx], nLevel) then
                        -- 斜向不允许"穿墙角"
                        local ok = true
                        if dx ~= 0 and dz ~= 0 then
                            ok = self:IsCanGoState(self.mWorld[self:_idx(nx, gz)], nLevel)
                             and self:IsCanGoState(self.mWorld[self:_idx(gx, nz)], nLevel)
                        end
                        if ok then
                            self:_touch(nzx)
                            if self.mWorkState[nzx] ~= C.PATH_CLOSED then
                                local cost = (dx ~= 0 and dz ~= 0) and 14 or 10
                                local ng = g + cost
                                if ng < (self.mG[nzx] or 1e12) then
                                    self.mG[nzx]         = ng
                                    self.mF[nzx]         = ng + self:_H(nx, nz)
                                    self.mParent[nzx]    = zx
                                    self.mWorkState[nzx] = C.PATH_OPEN
                                    self:_heapPush(nzx)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if not reached then
        return nil, 0
    end
    return self:_PackRoute(szx, ezx, endPt, nLevel)
end

function PathFinder:GetDistance() return self.mDistance end

return PathFinder