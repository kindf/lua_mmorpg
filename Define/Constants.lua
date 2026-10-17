local C = {}

-- 无效值
C.INVALID_ID        = -1
C.INVALID_SKILL_ID  = -1
C.INVALID_GUID      = -1

-- OPERATE_RESULT
C.OR_OK                           = 0    -- 成功
C.OR_ERROR                        = -1   -- 未知错误
C.OR_DIE                          = -2   -- 你已死亡
C.OR_INVALID_SKILL                = -3   -- 无效技能
C.OR_TARGET_DIE                   = -4   -- 目标已死亡
C.OR_LACK_MANA                    = -5   -- MANA 不足
C.OR_COOL_DOWNING                 = -6   -- 冷却未到
C.OR_NO_TARGET                    = -7   -- 没有目标
C.OR_INVALID_TARGET               = -8   -- 无效目标
C.OR_OUT_RANGE                    = -9   -- 超出范围
C.OR_BUSY                         = -17  -- 正在做其它事情
C.OR_NO_SCRIPT                    = -23
C.OR_NOT_ENOUGH_RAGE              = -25
C.OR_NOT_ENOUGH_ITEM              = -27
C.OR_LIMIT_MOVE                   = -36     -- 无法移动
C.OR_LIMIT_USE_SKILL              = -37  -- 无法使用技能
C.OR_NEED_A_WEAPON                = -40  -- 需要一把武器
C.OR_NEED_HIGH_LEVEL_XINFA        = -41  -- 等级不够
C.OR_U_CANNT_DO_THIS_RIGHT_NOW    = -44  -- 你现在无法这样做
C.OR_NEED_HIGH_LEVEL              = -47
C.OR_CAN_NOT_MOVE_STALL_OPEN      = -61     -- 无法在摆摊中移动
C.OR_IMPASSABLE_ZONE              = -70     -- 不能到达该区域
C.OR_CUT_PATHROUTE                = -1000   -- 不是错误，只是截断了路径

C.OR_SUCCEEDED = function(x) return x >= 0 end
C.OR_FAILED    = function(x) return x < 0 end

-- ENUM_SKILL_TYPE
C.SKILL_TYPE = { INVALID = -1, GATHER = 0, LEAD = 1, LAUNCH = 2, PASSIVE = 3, NUMBERS = 4 }
C.SKILL_NEED_CHARGING     = 0   -- SKILL_TYPE_GATHER
C.SKILL_NEED_CHANNELING   = 1   -- SKILL_TYPE_LEAD
C.SKILL_INSTANT_LAUNCHING = 2   -- SKILL_TYPE_LAUNCH
C.SKILL_PASSIVE           = 3

-- ENUM_SELECT_TYPE
C.SELECT_TYPE = { INVALID = -1, NONE = 0, CHARACTER = 1, POS = 2, DIR = 3, SELF = 4, HUMAN_GUID = 5, NUMBERS = 6 }

-- ENUM_TARGET_LOGIC
C.TARGET_LOGIC = {
    INVALID = -1,
    SELF = 0,              -- 只对自己有效
    MY_PET = 1,            -- 只对自己的宠物有效
    MY_SHADOW_GUARD = 2,
    MY_MASTER = 3,
    AE_AROUND_SELF = 4,    -- 以自己为中心，范围有效
    SPECIFIC_UNIT = 5,     -- 瞄准的对象有效
    AE_AROUND_UNIT = 6,    -- 以瞄准对象为中心，范围有效
    AE_AROUND_POSITION = 7,-- 以瞄准位置为中心，范围有效
    NUMBERS = 8,
}

-- ENUM_STATE  注意顺序：IDLE=0, DEAD=1, ... COMBAT=6
C.ESTATE = {
    IDLE = 0, DEAD = 1, TERROR = 2,
    APPROACH = 3, SERVICE = 4, GOHOME = 5,
    COMBAT = 6, PATROL = 7, FLEE = 8,
    SIT = 9, TEAMFOLLOW = 10, STALL = 11,
}

-- ObjType
C.OBJ_TYPE = {
    INVALID = 0,
    HUMAN = 1,
    MONSTER = 2,
    PET = 3,
    ITEM_BOX = 4,
    PLATFORM = 5,
    SPECIAL = 6
}

-- ENUM_CHARACTER_LOGIC
C.CHARACTER_LOGIC = { INVALID = -1, IDLE = 0, MOVE = 1, USE_SKILL = 2, USE_ABILITY = 3 }

-- 包处理返回值
C.PACKET_EXE_CONTINUE = 0
C.PACKET_EXE_ERROR    = 1

-- 行为类型
C.BEHAVIOR_TYPE = { HOSTILITY = -1, NEUTRALITY = 0, AMITY = 1 }

-- 其它
C.CONDITION_AND_DEPLETE_TERM_NUMBER = 3
C.MAX_CHAR_SKILL_LEVEL              = 150
C.MELEE_ATTACK                      = -100 -- 普攻特殊 ID（宏）

-- A_SKILL_FOR_PLAYER == 0（技能按使用者分类：0 玩家 / 1 怪物 / 2 宠物 / 3 物品）
C.CLASS_BY_USER_PLAYER = 0

--------------------------------------------------------------------------------
-- ENUM SCENE_STATUS
--------------------------------------------------------------------------------
C.SCENE_STATUS = {
    SLEEP   = 0,   -- 未启用/未装载
    SELECT  = 1,   -- 正在装载
    LOAD    = 2,   -- 读取场景资源
    INIT    = 3,   -- 初始化场景数据
    RUNNING = 4,   -- 运行中
}

-- ENUM SCENE_TYPE
C.SCENE_TYPE = {
    INVALID     = -1,
    GAMELOGIC   = 0,   -- 普通游戏逻辑场景
    COPY        = 1,   -- 副本
    BATTLEFIELD = 2,   -- 战场
    ARENA       = 3,   -- 擂台
    CIT         = 4,   -- 城市（动态场景）
    HOME        = 5,   -- 庭院
    HOUSE       = 6,   -- 房屋
}

--------------------------------------------------------------------------------
-- 容量与尺寸
--------------------------------------------------------------------------------
C.MAX_SCENE                  = 1024
C.ZONE_SIZE                  = 10     -- 一个 Zone 网格的世界边长（米），对应 m_ConfigInfo.m_ZoneSize
C.MAX_RADIUS                 = 2      -- 广播/扫描默认扩圈数
C.MAX_REFESH_OBJ_ZONE_RADIUS = 2      -- AOI 刷新扩圈数
C.MAX_AREA_IN_ZONE           = 10     -- 单个 Zone 上最多挂多少个 Area
C.MAX_HUMAN_LIST_SIZE        = 128    -- 玩家扫描列表上限
C.MAX_CHAR_PATH_NODE_NUMBER  = 16     -- 一次移动最多携带的路径点
C.MAX_OBJ_LIST_SIZE          = 255    -- 场景对象上限

--------------------------------------------------------------------------------
-- A* 内部节点标记
--------------------------------------------------------------------------------
C.PATH_IMPASSABLE = 1
C.PATH_OPEN       = 20
C.PATH_CLOSED     = 30

C.ACTION_LOGIC_TYPE = {
    INVALID = 0,
    INSTANCE = 1, -- 瞬发
    CHANNEL = 2, -- 持续施法
    CHARGE = 3, -- 蓄力
}

C.MIN_ACTION_TIME = 500

return C

