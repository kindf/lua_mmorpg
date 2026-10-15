local C = require("Define.Constants")
local Class = require("Tool.Class")
--------------------------------------------------------------------------------
-- TargetAndDepletingParams
--------------------------------------------------------------------------------
---@class TargetAndDepletingParams
local TargetAndDepletingParams = Class("TargetAndDepletingParams")
function TargetAndDepletingParams:_init()
    self:CleanUp()
end
function TargetAndDepletingParams:CleanUp()
    self.err_code          = C.OR_OK
    self.err_param         = 0
    self.activated_skill   = C.INVALID_SKILL_ID
    self.skill_level       = 0
    self.target_obj        = C.INVALID_ID
    self.target_position   = { m_fX = 0.0, m_fZ = 0.0 }
    self.target_direction  = -1.0
    self.target_guid       = C.INVALID_GUID
    self.delay_time        = 0            -- 连击/引导会累加
    self.target_count      = 0
    self.ignore_condition_check_flag = false
    self.activated_script  = C.INVALID_ID
    self.bag_index         = C.INVALID_ID
    self.item_index        = C.INVALID_ID
    self.depleted_item_guid= C.INVALID_GUID
end
function TargetAndDepletingParams:SetErrCode(v) self.err_code = v end
function TargetAndDepletingParams:GetErrCode() return self.err_code end
function TargetAndDepletingParams:SetErrParam(v) self.err_param = v end
function TargetAndDepletingParams:SetActivatedSkill(v) self.activated_skill = v end
function TargetAndDepletingParams:GetActivatedSkill() return self.activated_skill end
function TargetAndDepletingParams:SetActivatedScript(v) self.activated_script = v end
function TargetAndDepletingParams:GetActivatedScript() return self.activated_script end
function TargetAndDepletingParams:SetSkillLevel(v) self.skill_level = v end
function TargetAndDepletingParams:GetSkillLevel() return self.skill_level end
function TargetAndDepletingParams:SetTargetObj(v) self.target_obj = v end
function TargetAndDepletingParams:GetTargetObj() return self.target_obj end
function TargetAndDepletingParams:SetTargetPosition(v) self.target_position = v end
function TargetAndDepletingParams:GetTargetPosition() return self.target_position end
function TargetAndDepletingParams:SetTargetDirection(v) self.target_direction = v end
function TargetAndDepletingParams:SetTargetGuid(v) self.target_guid = v end
function TargetAndDepletingParams:SetDelayTime(v) self.delay_time = v end
function TargetAndDepletingParams:GetDelayTime() return self.delay_time end
function TargetAndDepletingParams:SetTargetCount(v) self.target_count = v end
function TargetAndDepletingParams:SetIgnoreConditionCheckFlag(v) self.ignore_condition_check_flag = v end
function TargetAndDepletingParams:GetIgnoreConditionCheckFlag() return self.ignore_condition_check_flag end
function TargetAndDepletingParams:SetBagIndexOfDepletedItem(v) self.bag_index = v end
function TargetAndDepletingParams:GetBagIndexOfDepletedItem() return self.bag_index end

return TargetAndDepletingParams