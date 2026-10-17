--------------------------------------------------------------------------------
-- 程序入口 / 主循环
--
--   运行：lua main.lua
--
-- 固定步长推进仿真时间，每帧顺序：
--   1) ActionDelegator:UpdateTime   —— 推进动作系统时间（冷却 / GetActionTime）
--   2) Scene:Tick                   —— 场景内所有对象心跳（AI / 移动 / 技能）
--   3) ImpactCore:Tick              —— 结算到期的 Impact
--------------------------------------------------------------------------------
local C               = require("Define.Constants")
local Log             = require("Tool.Log")
local Scene           = require("Scene.Scene")
local ObjCharacter    = require("Obj.ObjCharacter")
local AI_Human        = require("AI.AIHuman")
local ActionDelegator = require("Action.ActionDelegator")
local ImpactCore      = require("Skill.ImpactCore")

local STEP_MS     = 100      -- 每帧步长（毫秒）
local TOTAL_TICKS = 100      -- 总帧数（10 秒）

-- 全局仿真时间（毫秒）
local g_uTime = 0

--------------------------------------------------------------------------------
-- 推进一帧
--------------------------------------------------------------------------------
local function Tick(scene)
    g_uTime = g_uTime + STEP_MS

    -- 1) 推进时间：技能冷却 / 动作剩余时间都基于这个绝对时间
    ActionDelegator.GetInstance():UpdateTime(g_uTime)

    -- 2) 驱动场景（内部遍历对象 HeartBeat -> AI / 移动 / 技能）
    scene:Tick(g_uTime)

    -- 3) 结算到期的 Impact（延迟伤害 / 治疗）
    ImpactCore.GetInstance():Tick(g_uTime)
end

--------------------------------------------------------------------------------
-- 创建角色并放入场景
--------------------------------------------------------------------------------
local function CreateCharacter(scene, cfg)
    cfg.scene = scene
    local obj = ObjCharacter.new(cfg)
    obj.ai = AI_Human.new(obj)
    scene:ObjectEnterScene(obj)
    return obj
end

--------------------------------------------------------------------------------
-- main
--------------------------------------------------------------------------------
local function main()
    Log.section("lua_mmorpg 主循环开始")

    local scene = Scene.new(1, {
        type = C.SCENE_TYPE.GAMELOGIC,
        map  = { cx = 64, cz = 64, grid_size = 0.5, obstacles = {} },
    })
    -- 带 cfg 构造时初始状态是 SLEEP，必须显式置为 RUNNING，否则 Scene:Tick 不推进
    scene:SetSceneStatus(C.SCENE_STATUS.RUNNING)

    local player = CreateCharacter(scene, {
        id = 1, name = "Player",
        obj_type = C.OBJ_TYPE.HUMAN, camp_id = 1, level = 1,
        hp = 1000, mp = 1000,
        known_skills = { [1001] = true, [1004] = true },
        position = { m_fX = 5.0, m_fZ = 5.0 },
        attack_range = 12.0, move_speed = 6.0,
    })

    local monster = CreateCharacter(scene, {
        id = 2, name = "Monster",
        obj_type = C.OBJ_TYPE.MONSTER, camp_id = 2, level = 1,
        hp = 2000, mp = 1000,
        position = { m_fX = 10.0, m_fZ = 5.0 },
        move_speed = 0.0,
    })

    for tick = 1, TOTAL_TICKS do
        -- 演示脚本：先走近，再放技能
        if tick == 1 then
            player:GetHumanAI():PushCommand_Move(-1, 1, { { m_fX = 9.0, m_fZ = 5.0 } }, true)

        elseif tick == 30 then
            local r = player:GetHumanAI():PushCommand_UseSkill(
                1001, 1, monster:GetID(), 0.0, 0.0, 0.0, C.INVALID_GUID)
            Log.msg(string.format("[main] PushCommand_UseSkill -> %s", tostring(r)))
        end

        Tick(scene)

        -- 每 10 帧打印一次状态
        if tick % 10 == 0 then
            local p = player:getWorldPos()
            Log.msg(string.format("[main] t=%dms player=(%.2f, %.2f) hp=%d | monster hp=%d",
                g_uTime, p.m_fX, p.m_fZ, player:GetHP(), monster:GetHP()))
        end
    end

    Log.section(string.format("lua_mmorpg 主循环结束 (t=%dms)", g_uTime))
end

main()
