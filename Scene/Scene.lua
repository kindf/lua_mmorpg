local Class = require("Tool.Class")
local C = require("Define.Constants")
local AreaManager = require("Scene.AreaManager")
local ObjMgr = require("Obj.ObjManager")
local Map = require("Scene.Map")
local Zone = require("Scene.Zone")
local Log = require("Tool.Log")
local Scan = require("Scene.Scan")
local AOI = require("Scene.AOI")

---@class Scene
local Scene = Class("Scene")

function Scene:_init(sceneID, cfg)
    self.m_SceneID     = sceneID
    self.id            = sceneID                -- 便捷别名
    self.m_ThreadID    = 1                      -- 单线程占位
    self.m_nSceneStatus= C.SCENE_STATUS.SLEEP
    self.m_SceneType   = C.SCENE_TYPE.GAMELOGIC
    self.m_szMapName   = "-"
    self.m_NoUserCloseTime = 0
    self._closeTimer   = nil

    self._objmgr       = ObjMgr.new()
    self._event_core   = {}
    self._areaManager  = AreaManager.new(self)
    self._monsterInitList = {}
    self.obj_factory   = nil                    -- 由演示层注入，避免 ch7 反向依赖 ch3
    self._plyTimer     = {}                     -- 玩家区域检测计时（对应 m_CheckZoneTimer）

    self:_Load(cfg)

    if cfg == nil then
        -- 无配置构造（兼容 Data.Scene.new(1)）：直接给一个可运行的默认场景
        self.m_nSceneStatus = C.SCENE_STATUS.RUNNING
    end
end

--------------------------------------------------------------------------------
-- 装载
--------------------------------------------------------------------------------

-- 默认地图
local DEFAULT_MAP = { cx = 64, cz = 64, grid_size = 0.5, obstacles = {} }

function Scene:_Load(cfg)
    local mapCfg = (cfg and cfg.map) or DEFAULT_MAP
    self.m_pMap  = Map.new(mapCfg)
    self.m_szMapName = mapCfg.name or "default"

    -- 把地图按 ZONE_SIZE 切成网格
    -- 注意两个"格子尺寸"不要混：
    --   m_ZoneGridSize            —— Zone 网格边长（米），来自 Config 的 m_ZoneSize，用于 CalcZoneID
    --   m_ZoneInfo.m_wZoneSize    —— Zone 总数（W*H），用于 AOI 的 zone 越界判断
    local zoneSize = (cfg and cfg.zone_size) or C.ZONE_SIZE
    local zoneW = math.ceil(self.m_pMap:CX() / zoneSize)
    local zoneH = math.ceil(self.m_pMap:CZ() / zoneSize)
    self.m_ZoneGridSize = zoneSize
    self.m_ZoneInfo = { m_wZoneW = zoneW, m_wZoneH = zoneH, m_wZoneSize = zoneW * zoneH }

    self.m_pZone = {}
    for i = 0, zoneW * zoneH - 1 do
        self.m_pZone[i] = Zone.new(i)
    end

    if cfg then
        self.m_SceneType = cfg.type or C.SCENE_TYPE.GAMELOGIC
        self.m_NoUserCloseTime = cfg.no_user_close_time or 0

        -- 事件区域（area.ini）
        self._areaManager = AreaManager.new(self)
        self._areaManager:Init(cfg.areas)

        -- 刷怪点（monster.ini）：真正创建对象要用到工厂，延迟到 ExecuteMonsterIni
        self._monsterInitList = cfg.monsters or {}
    end
end

-- 按刷怪点批量生成怪物
-- 这里不直接 new Obj_Character，而是调用注入的 obj_factory，避免章节循环依赖
function Scene:SetObjFactory(fn) self.obj_factory = fn end

function Scene:ExecuteMonsterIni()
    if self.obj_factory == nil then
        Log.warn(string.format("场景 %d 未注入 obj_factory，跳过刷怪", self.m_SceneID))
        return false
    end
    for _, m in ipairs(self._monsterInitList) do
        local pMonster = self.obj_factory(self, m)
        if pMonster then
            self:ObjectEnterScene(pMonster)
        end
    end
    return true
end

--------------------------------------------------------------------------------
-- 基础 getter
--------------------------------------------------------------------------------
function Scene:SceneID()        return self.m_SceneID end
function Scene:GetObjManager()  return self._objmgr end
function Scene:GetEventCore()   return self._event_core end
function Scene:GetMap()         return self.m_pMap end
function Scene:GetZoneInfo()    return self.m_ZoneInfo end
function Scene:GetAreaManager() return self._areaManager end
function Scene:GetMapName()     return self.m_szMapName end

function Scene:GetSceneStatus() return self.m_nSceneStatus end
function Scene:SetSceneStatus(s) self.m_nSceneStatus = s end
function Scene:GetSceneType()   return self.m_SceneType end
function Scene:SetSceneType(t)  self.m_SceneType = t end

function Scene:GetZone(zid)
    if zid == nil or zid == C.INVALID_ID then return nil end
    local z = self.m_pZone[zid]
    if z == nil then
        Log.error(string.format("Scene::GetZone 越界 zone=%s", tostring(zid)))
    end
    return z
end

--------------------------------------------------------------------------------
-- 空间查询转发
--------------------------------------------------------------------------------
function Scene:CalcZoneID(pos)                  return Scan.CalcZoneID(self, pos) end
function Scene:GetRectInRadius(nRadius, zid)    return Scan.GetRectInRadius(self, nRadius, zid) end
function Scene:ScanHuman(zid, nRadius)          return Scan.ScanHuman(self, zid, nRadius) end
function Scene:ScanHumanByPos(pos, fRange)      return Scan.ScanHumanByPos(self, pos, fRange) end
function Scene:ScanObj(zid, nRadius)            return Scan.ScanObj(self, zid, nRadius) end
function Scene:BroadCast(pPacket, pOwn, bSendMe) return Scan.BroadCast(self, pPacket, pOwn, bSendMe) end
function Scene:BroadCastByZone(pPacket, zid)    return Scan.BroadCastByZone(self, pPacket, zid) end
function Scene:BroadCast_Scene(pPacket)         return Scan.BroadCast_Scene(self, pPacket) end

function Scene:SendPacketToHuman(pPacket, pHuman)
    if pHuman == nil or pPacket == nil then return end

    local pPlayer = nil
    if pHuman.GetPlayer then pPlayer = pHuman:GetPlayer() end
    if pPlayer and pPlayer.SendPacket then
        pPlayer:SendPacket(pPacket)
    else
        Log.msg(string.format("[SendPacket] %s -> %s(#%d)",
            pPacket.pid or "PKT", pHuman:GetName(), pHuman:GetID()))
    end
end

--------------------------------------------------------------------------------
-- 事件区域
--------------------------------------------------------------------------------
function Scene:RegisterArea(pArea)
    if pArea == nil then return false end

    local rc = pArea.m_rcArea
    local zoneSize  = self.m_ZoneGridSize
    local zoneWidth = self.m_ZoneInfo.m_wZoneW

    local uX = math.floor(rc.m_fLeft / zoneSize)
    local uZ = math.floor(rc.m_fTop  / zoneSize)

    local zPos, i = uZ * zoneSize, 0
    while zPos < rc.m_fBottom do
        local xPos, j = uX * zoneSize, 0
        while xPos < rc.m_fRight do
            local zoneid = (uX + j) + (uZ + i) * zoneWidth
            local pZone = self:GetZone(zoneid)
            if pZone then pZone:AddArea(pArea) end
            j = j + 1
            xPos = xPos + zoneSize
        end
        i = i + 1
        zPos = zPos + zoneSize
    end
    return true
end

-- 返回玩家当前所在的事件区域（没有则 nil）
function Scene:CheckArea(pHuman)
    if pHuman == nil then return nil end
    local pZone = self:GetZone(pHuman:getZoneID())
    if pZone == nil or pZone:GetAreaCount() < 1 then return nil end
    return pZone:GetCurrentArea(pHuman:getWorldPos())
end

--------------------------------------------------------------------------------
-- 对象进出场景
--------------------------------------------------------------------------------
function Scene:ObjectEnterScene(pObj)
    if pObj == nil then return false end

    if not self._objmgr:Add(pObj) then
        return false
    end

    pObj:setScene(self)
    pObj:UpdateZone()             -- 先算出所属网格（此时还没激活，仅记录）
    pObj:SetActiveFlag(true)      -- 再注册进网格，触发 AOI 首次刷新
    pObj:OnEnterScene()
    return true
end

function Scene:ObjectLeaveScene(pObj)
    if pObj == nil then return end

    pObj:OnLeaveScene()

    -- 玩家离开要广播一条 GCLeaveScene
    if pObj:GetObjType() == C.OBJ_TYPE.HUMAN then
        local zid = self:CalcZoneID(pObj:getWorldPos())
        self:BroadCast({ pid = "GCLeaveScene", obj_id = pObj:GetID(), leave_code = 0 }, zid)
    end

    pObj:SetActiveFlag(false)     -- 从网格注销，触发 AOI 删除包
    pObj:setScene(nil)
    self._objmgr:RemoveObj(pObj)
end

function Scene:GetSpecificObjByID(id) return self._objmgr:GetObj(id) end

--------------------------------------------------------------------------------
-- 网格注册/注销/跨格转发
--------------------------------------------------------------------------------
function Scene:ObjZone_Register(pObj, idZone)        return AOI.ObjZone_Register(self, pObj, idZone) end
function Scene:ObjZone_Unregister(pObj, idZone)      return AOI.ObjZone_Unregister(self, pObj, idZone) end
function Scene:ObjZone_Changed(pObj, idNew, idOld)   return AOI.ObjZone_Changed(self, pObj, idNew, idOld) end

--------------------------------------------------------------------------------
-- 进入条件
--------------------------------------------------------------------------------
function Scene:IsCanEnter()
    if self:GetSceneStatus() ~= C.SCENE_STATUS.RUNNING then
        Log.err(string.format("场景 %d 尚未就绪，不能进入", self.m_SceneID))
        return false
    end
    return true
end

function Scene:IsFull()
    return self._objmgr:GetCount() >= C.MAX_OBJ_LIST_SIZE
end

-- 0: 不能进入 / 1: 可以进入 / -1: 无权限
function Scene:CheckEnter(teamID)
    if self.m_SceneType == C.SCENE_TYPE.COPY then
        if self:GetSceneStatus() ~= C.SCENE_STATUS.RUNNING then
            return -1
        end
        if self.m_CopyTeamID ~= nil and self.m_CopyTeamID ~= teamID then
            Log.err(string.format("CheckEnter: 队伍 %s 无权进入副本 %d", tostring(teamID), self.m_SceneID))
            return -1
        end
    end
    if self.m_SceneType == C.SCENE_TYPE.CIT then
        if self:GetSceneStatus() ~= C.SCENE_STATUS.RUNNING then
            return -1
        end
    end
    return 1
end

--------------------------------------------------------------------------------
-- 生命周期
--------------------------------------------------------------------------------
function Scene:StatusLogic()
    local st = self.m_nSceneStatus
    if st == C.SCENE_STATUS.RUNNING then
        return true
    end
    if st == C.SCENE_STATUS.INIT then
        self:SetSceneStatus(C.SCENE_STATUS.RUNNING)
        self:OnSceneInit()
        return false
    end
    
    return false
end


function Scene:Tick(uTime)
    if not self:StatusLogic() then
        return true
    end
    self:HeartBeat(uTime)
    return true
end

function Scene:HeartBeat(uTime)
    -- 副本"无人自动关闭"
    if self.m_SceneType == C.SCENE_TYPE.COPY and self.m_NoUserCloseTime > 0 then
        if self._objmgr:GetCount() > 0 then
            self._closeTimer = nil
        else
            if self._closeTimer == nil then
                self._closeTimer = uTime + self.m_NoUserCloseTime
                Log.msg(string.format("场景 %d 无人，%d ms 后自动关闭",
                    self.m_SceneID, self.m_NoUserCloseTime))
            elseif uTime >= self._closeTimer then
                self:CloseScene()
                return true
            end
        end
    end

    -- 各 Manager 心跳 -> 这里简化为遍历对象（玩家/怪物/宠物/道具箱/平台/机关）
    local all = self._objmgr:GetAll()
    local i = 1
    while i <= #all do
        local pObj = all[i]
        if pObj ~= nil then
            pObj:HeartBeat(uTime)
        end
        i = i + 1
    end
    return true
end

function Scene:OnSceneInit()
    Log.section(string.format("场景 %d 初始化完成 (map=%s, zones=%dx%d)",
        self.m_SceneID, self.m_szMapName,
        self.m_ZoneInfo.m_wZoneW, self.m_ZoneInfo.m_wZoneH))
end

function Scene:CloseScene()
    Log.msg(string.format("场景 %d 关闭", self.m_SceneID))
    self:SetSceneStatus(C.SCENE_STATUS.SLEEP)
    self._closeTimer = nil

    -- 把所有对象踢出场景
    local all = self._objmgr:GetAll()
    for i = #all, 1, -1 do
        self:ObjectLeaveScene(all[i])
    end
    return true
end

return Scene