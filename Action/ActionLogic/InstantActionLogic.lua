local Class = require("Tool.Class")
local ActionLogic = require("Action.ActionLogic.ActionLogic")

---@class InstantActionLogic
local InstantActionLogic = Class("InstantActionLogic", ActionLogic)

function InstantActionLogic:_init(id)
    self.__base._init(self, id)
end

return InstantActionLogic