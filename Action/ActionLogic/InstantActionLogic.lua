local Class = require("Tool.Class")

---@class InstantActionLogic
local InstantActionLogic = Class("InstantActionLogic")

function InstantActionLogic:_init(id)
    self.__base:_init(self, id)
end

return InstantActionLogic