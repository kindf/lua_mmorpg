-- 所有函数都接收 scene 作为第一个参数，
-- 这样 ch8 不需要反向依赖 ch7_scene，避免 require 循环。
--
-- 核心是"九宫格"：
--   GetRectInRadius(radius, zid) 把"以 zid 为中心扩 radius 圈 Zone"换算成一个矩形，
--   然后在矩形内的所有 Zone 里扫 ObjList / HumanList。
--
--   ScanHuman_Sub(a, b) = a 圈内的玩家 减去 b 圈内的玩家（两个 Zone 集合的差集），
--   AOI 刷新时正是靠它做到"只给新进入视野的人发包"。

local C     = require("Define.Constants")
local Vec   = require("Tool.Vec")

local Scan = {}

--------------------------------------------------------------------------------
-- Zone 坐标换算
--------------------------------------------------------------------------------
-- 注意：除数用的是 Zone 网格边长 m_ZoneGridSize（对应 g_Config.m_ConfigInfo.m_ZoneSize），
--       不是 m_ZoneInfo.m_wZoneSize（那是 Zone 总数）。
function Scan.CalcZoneID(scene, pos)
    if pos == nil or pos.m_fX < 0.0 or pos.m_fZ < 0.0 then
        return C.INVALID_ID
    end
    local zoneSize = scene.m_ZoneGridSize
    local uX = math.floor(pos.m_fX / zoneSize)
    local uZ = math.floor(pos.m_fZ / zoneSize)
    return uX + uZ * scene.m_ZoneInfo.m_wZoneW
end

-- 以 zid 为中心扩 nRadius 圈，得到 Zone 矩阵范围（含边界钳制）
function Scan.GetRectInRadius(scene, nRadius, zid)
    if zid == C.INVALID_ID then return nil end
    if nRadius < 0 then nRadius = 0 end

    local zoneW = scene.m_ZoneInfo.m_wZoneW
    local zoneH = scene.m_ZoneInfo.m_wZoneH

    local nW = zid % zoneW
    local nH = math.floor(zid / zoneW)

    local rc = {}
    rc.nStartx = math.max(nW - nRadius, 0)
    rc.nStartz = math.max(nH - nRadius, 0)
    rc.nEndx   = math.min(nW + nRadius, zoneW - 1)
    rc.nEndz   = math.min(nH + nRadius, zoneH - 1)
    return rc
end

local function forEachZoneHuman(scene, rc, fn)
    for h = rc.nStartz, rc.nEndz do
        for w = rc.nStartx, rc.nEndx do
            local zid = w + h * scene.m_ZoneInfo.m_wZoneW
            local pZone = scene:GetZone(zid)
            if pZone then
                local list = pZone:GetHumanList()
                for i = 1, #list do
                    if fn(list[i]) then return end
                end
            end
        end
    end
end

local function forEachZoneObj(scene, rc, fn)
    for h = rc.nStartz, rc.nEndz do
        for w = rc.nStartx, rc.nEndx do
            local zid = w + h * scene.m_ZoneInfo.m_wZoneW
            local pZone = scene:GetZone(zid)
            if pZone then
                local list = pZone:GetObjList()
                for i = 1, #list do
                    if fn(list[i]) then return end
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- 扫描
--------------------------------------------------------------------------------
-- 按 Zone 矩形收集玩家（不精算距离）
function Scan.ScanHuman(scene, zid, nRadius)
    local out = {}
    local rc = Scan.GetRectInRadius(scene, nRadius, zid)
    if rc == nil then return out end

    forEachZoneHuman(scene, rc, function(pHuman)
        if #out >= C.MAX_HUMAN_LIST_SIZE then return true end
        out[#out + 1] = pHuman
        return false
    end)
    return out
end

-- 收集后再按真实距离过滤
function Scan.ScanHumanByPos(scene, pos, fRange)
    local out = {}
    local zid = Scan.CalcZoneID(scene, pos)
    if zid == C.INVALID_ID then return out end

    local rc = Scan.GetRectInRadius(scene, C.MAX_RADIUS, zid)
    if rc == nil then return out end

    forEachZoneHuman(scene, rc, function(pHuman)
        if #out >= C.MAX_HUMAN_LIST_SIZE then return true end
        if Vec.MySqrt(pos, pHuman:getWorldPos()) <= fRange then
            out[#out + 1] = pHuman
        end
        return false
    end)
    return out
end


function Scan.ScanObj(scene, zid, nRadius)
    local out = {}
    local rc = Scan.GetRectInRadius(scene, nRadius, zid)
    if rc == nil then return out end

    forEachZoneObj(scene, rc, function(pObj)
        out[#out + 1] = pObj
        return false
    end)
    return out
end

-- 差集：ScanXxx_Sub(idZoneA, idZoneB) = A 圈内 - B 圈内
local function zoneRectContains(scene, rc, zid)
    local zoneW = scene.m_ZoneInfo.m_wZoneW
    local w = zid % zoneW
    local h = math.floor(zid / zoneW)
    if rc == nil then return false end
    return w >= rc.nStartx and w <= rc.nEndx and h >= rc.nStartz and h <= rc.nEndz
end

function Scan.ScanHuman_Sub(scene, idZoneA, idZoneB, nRadius)
    local out = {}
    local rcB = Scan.GetRectInRadius(scene, nRadius, idZoneB)
    local rcA = Scan.GetRectInRadius(scene, nRadius, idZoneA)
    if rcA == nil then return out end

    forEachZoneHuman(scene, rcA, function(pHuman)
        if not zoneRectContains(scene, rcB, pHuman:getZoneID()) then
            out[#out + 1] = pHuman
        end
        return false
    end)
    return out
end

function Scan.ScanObj_Sub(scene, idZoneA, idZoneB, nRadius)
    local out = {}
    local rcB = Scan.GetRectInRadius(scene, nRadius, idZoneB)
    local rcA = Scan.GetRectInRadius(scene, nRadius, idZoneA)
    if rcA == nil then return out end

    forEachZoneObj(scene, rcA, function(pObj)
        if not zoneRectContains(scene, rcB, pObj:getZoneID()) then
            out[#out + 1] = pObj
        end
        return false
    end)
    return out
end

--------------------------------------------------------------------------------
-- 发送 / 广播
--------------------------------------------------------------------------------
-- 逐个玩家下发
function Scan.SendPacket(scene, pPacket, humanList)
    for i = 1, #humanList do
        scene:SendPacketToHuman(pPacket, humanList[i])
    end
end

--   以 pOwnCharacter 所在 Zone 为中心，扩 MAX_RADIUS 圈广播
function Scan.BroadCast(scene, pPacket, pOwnCharacter, bSendMe)
    if pOwnCharacter == nil then
        return Scan.BroadCast_Scene(scene, pPacket)
    end

    local zid = pOwnCharacter:getZoneID()
    if zid == C.INVALID_ID then return end

    local list = Scan.ScanHuman(scene, zid, C.MAX_RADIUS)
    for i = 1, #list do
        local pHuman = list[i]
        if bSendMe or pHuman ~= pOwnCharacter then
            scene:SendPacketToHuman(pPacket, pHuman)
        end
    end
end


function Scan.BroadCastByZone(scene, pPacket, zoneID)
    if zoneID == C.INVALID_ID then
        return Scan.BroadCast_Scene(scene, pPacket)
    end
    local list = Scan.ScanHuman(scene, zoneID, C.MAX_RADIUS)
    Scan.SendPacket(scene, pPacket, list)
end

-- 给场景内所有玩家广播
function Scan.BroadCast_Scene(scene, pPacket)
    local all = scene:GetObjManager():GetAll()
    for i = 1, #all do
        local pObj = all[i]
        if pObj:GetObjType() == C.OBJ_TYPE.HUMAN then
            scene:SendPacketToHuman(pPacket, pObj)
        end
    end
end

return Scan