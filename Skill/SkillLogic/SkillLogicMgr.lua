local ImpactsSkillLogic = require("Skill.SkillLogic.ImpactsSkillLogic")
local Class = require("Tool.Class")

---@class SkillLogicMgr
local SkillLogicMgr = Class("SkillLogicMgr")

function SkillLogicMgr:_init()
    self._byID = {}
    self._byID[1] = ImpactsSkillLogic.new()
end

---@return BaseSkillLogic
function SkillLogicMgr:GetLogicById(id)
    return self._byID[id]
end

---@type SkillLogicMgr
local GSkillLogicMgr

function SkillLogicMgr.GetInstance()
    if not GSkillLogicMgr then
        GSkillLogicMgr = SkillLogicMgr.new()
    end
    return GSkillLogicMgr
end

return SkillLogicMgr