local Class = require("Tool.Class")
local C = require("Define.Constants")
local InstantActionLogic = require("Action.ActionLogic.InstantActionLogic")
local ChargeActionLogic = require("Action.ActionLogic.ChargeActionLogic")
local ChannelActionLogic = require("Action.ActionLogic.ChannelActionLogic")

---@class ActionLogicMgr
local ActionLogicMgr = Class("ActionLogicMgr")

function ActionLogicMgr:_init()
    self.logics = {}
    self.logics[C.ACTION_LOGIC_TYPE.INSTANCE] = InstantActionLogic.new(C.ACTION_LOGIC_TYPE.INSTANCE)
    self.logics[C.ACTION_LOGIC_TYPE.CHANNEL] = ChannelActionLogic.new(C.ACTION_LOGIC_TYPE.CHANNEL)
    self.logics[C.ACTION_LOGIC_TYPE.CHARGE] = ChargeActionLogic.new(C.ACTION_LOGIC_TYPE.CHARGE)
end

---@return InstantActionLogic | ChannelActionLogic | ChargeActionLogic
function ActionLogicMgr:GetLogicById(id)
    return self.logics[id]
end

---@type ActionLogicMgr
local GActionLogicMgr
function ActionLogicMgr.GetInstance()
    if not GActionLogicMgr then
        GActionLogicMgr = ActionLogicMgr.new()
    end
    return GActionLogicMgr
end


return ActionLogicMgr