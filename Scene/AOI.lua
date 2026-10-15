-- AOI = Area Of Interest。做法是"九宫格 + 差集"：
--   对象跨格时，用 ScanHuman_Sub / ScanObj_Sub 求两个 Zone 集合的差集，
--   只给"新进入视野"的人发 CreateNewObjPacket，只给"离开视野"的人发 CreateDeleteObjPacket，
--   而不是整屏重刷。
--
-- 本模块是纯函数（第一个参数传 scene / obj），这样 ch9 不需要反向依赖 ch7_scene，
-- 避免 require 循环；Scene 与 Obj 只做转发。

local C    = require("Define.Constants")
local Log  = require("Tool.Log")
local Scan = require("Scene.Scan")

local AOI = {}

local RADIUS = C.MAX_REFESH_OBJ_ZONE_RADIUS

local function filterVisible(pObj, list)
    local out = {}
    for i = 1, #list do
        local pOther = list[i]
        if pObj:IsCanViewMe(pOther) then
            out[#out + 1] = pOther
        end
    end
    return out
end

--------------------------------------------------------------------------------
-- Scene::ObjZone_Register：对象第一次进入网格
--------------------------------------------------------------------------------
function AOI.ObjZone_Register(scene, pObj, idZone)
    if pObj == nil then return false end
    if idZone < 0 or idZone >= scene.m_ZoneInfo.m_wZoneSize then
        Log.error(string.format("ObjZone_Register: 非法 zone %d", idZone))
        return false
    end

    -- 1) 把"我出现了"发给 idZone 周围已经存在的玩家
    local pPacket = pObj:CreateNewObjPacket()
    if pPacket == nil then
        Log.error("ObjZone_Register: CreateNewObjPacket 返回 nil")
        return false
    end
    local listHuman = Scan.ScanHuman(scene, idZone, RADIUS)
    listHuman = filterVisible(pObj, listHuman)
    if #listHuman > 0 then
        Scan.SendPacket(scene, pPacket, listHuman)
    end

    -- 2) 如果我是玩家，把该区域里已有的对象补发给我
    if pObj:GetObjType() == C.OBJ_TYPE.HUMAN then
        local listObj = Scan.ScanObj(scene, idZone, RADIUS)
        for i = 1, #listObj do
            local pFindObj = listObj[i]
            if pFindObj:IsCanViewMe(pObj) then
                local pkt = pFindObj:CreateNewObjPacket()
                if pkt then
                    scene:SendPacketToHuman(pkt, pObj)
                end
            end
        end
    end

    -- 3) 最后才真正挂进 Zone
    scene:GetZone(idZone):OnObjectEnter(pObj)
    Log.msg(string.format("AOI 进入: %s 进入 zone %d", pObj:GetName(), idZone))
    return true
end

--------------------------------------------------------------------------------
-- Scene::ObjZone_Unregister：对象离开网格（失活/离开场景）
--------------------------------------------------------------------------------
function AOI.ObjZone_Unregister(scene, pObj, idZone)
    if pObj == nil then return false end
    if idZone < 0 or idZone >= scene.m_ZoneInfo.m_wZoneSize then
        Log.err(string.format("ObjZone_Unregister: 非法 zone %d", idZone))
        return false
    end

    -- 1) 先从 Zone 摘掉
    scene:GetZone(idZone):OnObjectLeave(pObj)

    -- 2) 把"我消失了"发给原区域周围的玩家
    local pPacket = pObj:CreateDeleteObjPacket()
    if pPacket == nil then
        Log.error("ObjZone_Unregister: CreateDeleteObjPacket 返回 nil")
        return false
    end
    local listHuman = Scan.ScanHuman(scene, idZone, RADIUS)
    listHuman = filterVisible(pObj, listHuman)
    if #listHuman > 0 then
        Scan.SendPacket(scene, pPacket, listHuman)
    end

    -- 3) 如果我是玩家，把原区域里的对象从我客户端删掉
    if pObj:GetObjType() == C.OBJ_TYPE.HUMAN then
        local listObj = Scan.ScanObj(scene, idZone, RADIUS)
        for i = 1, #listObj do
            local pFindObj = listObj[i]
            if pFindObj:IsCanViewMe(pObj) then
                local pkt = pFindObj:CreateDeleteObjPacket()
                if pkt then
                    scene:SendPacketToHuman(pkt, pObj)
                end
            end
        end
    end

    Log.msg(string.format("AOI 离开: %s 离开 zone %d", pObj:GetName(), idZone))
    return true
end

--------------------------------------------------------------------------------
-- Scene::ObjZone_Changed：对象跨格
--------------------------------------------------------------------------------
function AOI.ObjZone_Changed(scene, pObj, idNew, idOld)
    if pObj == nil then return false end

    local zoneSize = scene.m_ZoneInfo.m_wZoneSize

    ----------------------------------------------------------------
    -- 旧格：离开
    ----------------------------------------------------------------
    if idOld < 0 or idOld >= zoneSize then
        Log.error(string.format("ObjZone_Changed: 非法旧 zone %d", idOld))
    else
        scene:GetZone(idOld):OnObjectLeave(pObj)

        local pPacket = pObj:CreateDeleteObjPacket()
        if pPacket == nil then
            Log.err("ObjZone_Changed: CreateDeleteObjPacket 返回 nil")
            return false
        end

        -- 只通知"在旧格但不在新格"的玩家
        local listHuman
        if idNew ~= C.INVALID_ID then
            listHuman = Scan.ScanHuman_Sub(scene, idOld, idNew, RADIUS)
        else
            listHuman = Scan.ScanHuman(scene, idOld, RADIUS)
        end
        listHuman = filterVisible(pObj, listHuman)
        if #listHuman > 0 then
            Scan.SendPacket(scene, pPacket, listHuman)
        end

        -- 玩家自己也要把旧格里的对象删掉
        if pObj:GetObjType() == C.OBJ_TYPE.HUMAN then
            local listObj
            if idNew ~= C.INVALID_ID then
                listObj = Scan.ScanObj_Sub(scene, idOld, idNew, RADIUS)
            else
                listObj = Scan.ScanObj(scene, idOld, RADIUS)
            end
            for i = 1, #listObj do
                local pFindObj = listObj[i]
                if pFindObj:IsCanViewMe(pObj) then
                    local pkt = pFindObj:CreateDeleteObjPacket()
                    if pkt then
                        scene:SendPacketToHuman(pkt, pObj)
                    end
                end
            end
        end
    end
        ----------------------------------------------------------------
    -- 新格：进入
    ----------------------------------------------------------------
    if idNew < 0 or idNew >= zoneSize then
        Log.err(string.format("ObjZone_Changed: 非法新 zone %d", idNew))
    else
        local pPacket = pObj:CreateNewObjPacket()
        if pPacket == nil then
            Log.err("ObjZone_Changed: CreateNewObjPacket 返回 nil")
            return false
        end

        local listHuman
        if idOld ~= C.INVALID_ID then
            listHuman = Scan.ScanHuman_Sub(scene, idNew, idOld, RADIUS)
        else
            listHuman = Scan.ScanHuman(scene, idNew, RADIUS)
        end
        listHuman = filterVisible(pObj, listHuman)
        if #listHuman > 0 then
            Scan.SendPacket(scene, pPacket, listHuman)
        end

        if pObj:GetObjType() == C.OBJ_TYPE.HUMAN then
            local listObj
            if idOld ~= C.INVALID_ID then
                listObj = Scan.ScanObj_Sub(scene, idNew, idOld, RADIUS)
            else
                listObj = Scan.ScanObj(scene, idNew, RADIUS)
            end
            for i = 1, #listObj do
                local pFindObj = listObj[i]
                if pFindObj:IsCanViewMe(pObj) then
                    local pkt = pFindObj:CreateNewObjPacket()
                    if pkt then
                        scene:SendPacketToHuman(pkt, pObj)
                    end
                end
            end
        end

        scene:GetZone(idNew):OnObjectEnter(pObj)
        Log.msg(string.format("AOI 跨格: %s  zone %d -> %d", pObj:GetName(), idOld, idNew))
    end

    return true
end

--------------------------------------------------------------------------------
-- Obj::UpdateZone：每帧算一次所在网格，变了就走 AOI
--------------------------------------------------------------------------------
function AOI.Obj_UpdateZone(pObj)
    local scene = pObj:getScene()
    if scene == nil then return false end

    local idNew = scene:CalcZoneID(pObj:getWorldPos())
    local idOld = pObj:getZoneID()

    if idNew ~= idOld then
        pObj:setZoneID(idNew)
        if pObj:IsActiveObj() and idNew ~= C.INVALID_ID then
            if idOld ~= C.INVALID_ID then
                scene:ObjZone_Changed(pObj, idNew, idOld)
            else
                scene:ObjZone_Register(pObj, idNew)
            end
        end
    end
    return true
end

--------------------------------------------------------------------------------
-- Obj::SetActiveFlag：激活/失活时注册/注销到当前网格
--------------------------------------------------------------------------------
function AOI.Obj_SetActiveFlag(pObj, bFlag)
    local bNew = bFlag and true or false
    if pObj.is_active == bNew then return end

    pObj.is_active = bNew
    local zid = pObj:getZoneID()
    local scene = pObj:getScene()

    if scene and zid ~= C.INVALID_ID then
        if bNew then
            scene:ObjZone_Register(pObj, zid)
        else
            scene:ObjZone_Unregister(pObj, zid)
            pObj:setZoneID(C.INVALID_ID)
        end
    end
end

--------------------------------------------------------------------------------
-- Obj::Teleport：瞬移（先校验落点，再改坐标 + 刷新 AOI + 广播）
--------------------------------------------------------------------------------
function AOI.Obj_Teleport(pObj, pos)
    local scene = pObj:getScene()
    if scene then
        if not scene:GetMap():IsCanGo(pos, 0) then
            -- 对应 C++：落点不可走则直接返回，不改坐标
            Log.warn(string.format("Teleport 失败: %s 落点不可达 (%.2f, %.2f)",
                pObj:GetName(), pos.m_fX, pos.m_fZ))
            return false
        end
    end

    pObj:setWorldPos(pos)
    pObj:UpdateZone()

    -- 同步一条 Teleport 消息给周围玩家
    local msg = { pid = "GCObjTeleport", obj_id = pObj:GetID(),
                  world_pos = { m_fX = pos.m_fX, m_fZ = pos.m_fZ } }
    for _, pHuman in ipairs(Scan.ScanHuman(scene, pObj:getZoneID(), RADIUS)) do
        if pObj:IsCanViewMe(pHuman) then
            scene:SendPacketToHuman(msg, pHuman)
        end
    end
    return true
end

return AOI