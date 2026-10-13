--------------------------------------------------------------------------------
-- 模拟协议：报文定义 + 文本编解码
--
--   线上一帧 = 一行 UTF-8 文本：
--       OP k=v k=v k=v ...
--   例如：
--       CMSG_CHAR_USE_SKILL dir=0 objID=1 skillDataID=100101 targetID=2 x=0 z=0
--       S2C 侧：SMSG_HP_CHANGE delta=-120 hp=1880 id=2 maxHp=2000 src=1
--
--   值不带空格（本项目里人名也不含空格），数字会被自动还原成 number。
--   这样任何报文都能直接打印到控制台 / 写入文件来"模拟协议"。
--------------------------------------------------------------------------------
local Protocol = {}

-- 客户端 -> 服务器
Protocol.CMSG = {
    ENTER_SCENE    = "CMSG_ENTER_SCENE",
    CHAR_USE_SKILL = "CMSG_CHAR_USE_SKILL",
    CHAR_MOVE      = "CMSG_CHAR_MOVE",
    DEBUG_DAMAGE   = "CMSG_DEBUG_DAMAGE",
    SET_PAUSE      = "CMSG_SET_PAUSE",
    SET_SPEED      = "CMSG_SET_SPEED",
    RESET          = "CMSG_RESET",
    PING           = "CMSG_PING",
}

-- 服务器 -> 客户端
Protocol.SMSG = {
    RESET           = "SMSG_RESET",
    CONFIG          = "SMSG_CONFIG",
    ENTER_SCENE_ACK = "SMSG_ENTER_SCENE_ACK",
    SKILL_INFO      = "SMSG_SKILL_INFO",
    OBJ_ENTER       = "SMSG_OBJ_ENTER",
    OBJ_LEAVE       = "SMSG_OBJ_LEAVE",
    OBJ_TELEPORT    = "SMSG_OBJ_TELEPORT",
    CHAR_MOVE       = "SMSG_CHAR_MOVE",
    CHAR_MOVE_RESULT= "SMSG_CHAR_MOVE_RESULT",
    SYNC_TIME       = "SMSG_SYNC_TIME",
    MAP_INFO        = "SMSG_MAP_INFO",
    OPERATE_RESULT  = "SMSG_OPERATE_RESULT",
    SKILL_CAST      = "SMSG_SKILL_CAST",
    ACTION_START    = "SMSG_ACTION_START",
    COOLDOWN        = "SMSG_COOLDOWN",
    IMPACT_SEND     = "SMSG_IMPACT_SEND",
    IMPACT_APPLY    = "SMSG_IMPACT_APPLY",
    HP_CHANGE       = "SMSG_HP_CHANGE",
    MP_CHANGE       = "SMSG_MP_CHANGE",
    SKILL_HIT       = "SMSG_SKILL_HIT",
    SKILL_MISS      = "SMSG_SKILL_MISS",
    CRITICAL        = "SMSG_CRITICAL",
    LOCK_TARGET     = "SMSG_LOCK_TARGET",
    STATE_CHANGE    = "SMSG_STATE_CHANGE",
    CHAR_DEATH      = "SMSG_CHAR_DEATH",
    PONG            = "SMSG_PONG",
}

local function fmt(v)
    if type(v) == "boolean" then return v and "1" or "0" end
    if type(v) == "number" then
        if v == math.floor(v) and math.abs(v) < 1e15 then
            return string.format("%d", v)
        end
        return string.format("%.3f", v)
    end
    return tostring(v)
end

--- 编码：op + 字段表 -> 一行文本
function Protocol.Encode(op, fields)
    local parts = { op }
    if fields then
        local keys = {}
        for k in pairs(fields) do keys[#keys + 1] = k end
        table.sort(keys)                       -- 固定顺序，便于对比抓包
        for _, k in ipairs(keys) do
            parts[#parts + 1] = tostring(k) .. "=" .. fmt(fields[k])
        end
    end
    return table.concat(parts, " ")
end

--- 解码：一行文本 -> op, 字段表
function Protocol.Decode(frame)
    local op, rest = frame:match("^(%S+)%s*(.*)$")
    if op == nil then return nil, nil end
    local fields = {}
    for k, v in rest:gmatch("(%S+)=(%S+)") do
        local n = tonumber(v)
        fields[k] = (n ~= nil) and n or v
    end
    return op, fields
end

return Protocol
