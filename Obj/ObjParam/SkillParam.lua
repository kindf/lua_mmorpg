local Class = require("Tool.Class")
local C = require("Define.Constants")

---@class SkillParam
local SkillParam = Class("SkillParam")
function SkillParam:_init()
    self:Init()
end
function SkillParam:Init()
    self.skill_id                    = C.INVALID_SKILL_ID
    self.logic_id                    = C.INVALID_ID
    self.skill_type                  = C.SKILL_TYPE.INVALID
    self.delay_time                  = 0
    self.cooldown_id                 = 0
    self.cooldown_time               = 0
    self.play_action_time            = 0
    self.charge_time                 = 0
    self.channel_time                = 0
    self.targeting_logic             = C.TARGET_LOGIC.INVALID
    self.select_type                 = C.SELECT_TYPE.INVALID
    self.target_check_by_obj_type    = -1
    self.target_must_in_special_state= -1
    self.accuracy                    = 0
    self.critical_rate               = 0
    self.must_use_weapon_flag        = false
    self.charges_or_interval         = 0
    self.ae_radius                   = 0.0
    self.impact_id                   = C.INVALID_ID
    self.tick_impact_id              = C.INVALID_ID  -- 引导每跳用的 Impact
    self.auto_shot                   = false
    self.stand_flag                  = 0
    self.target_logic_by_stand       = C.INVALID_ID  -- <=> GetTargetLogicByStand()
    self.study_level                 = 0
    self.condep_terms                = {}
end

function SkillParam:CopyFrom(inst, tmpl)
    self.skill_id                     = inst.skill_id or tmpl.id
    self.logic_id                     = inst.logic_id
    self.skill_type                   = inst.skill_type
    self.delay_time                   = inst.delay_time or 0
    self.cooldown_id                  = inst.cooldown_id or 0
    self.cooldown_time                = inst.cooldown_time or 0
    self.play_action_time             = inst.play_action_time or 0
    self.charge_time                  = inst.charge_time or 0
    self.channel_time                 = inst.channel_time or 0
    self.targeting_logic              = inst.targeting_logic
    self.select_type                  = inst.select_type or tmpl.select_type
    self.target_check_by_obj_type     = inst.target_check_by_obj_type or -1
    self.target_must_in_special_state = inst.target_must_in_special_state
    self.accuracy                     = inst.accuracy or 0
    self.critical_rate                = inst.critical_rate or 0
    self.must_use_weapon_flag         = inst.must_use_weapon_flag or tmpl.must_use_weapon or false
    self.charges_or_interval          = inst.charges_or_interval or 0
    self.ae_radius                    = inst.ae_radius or 0.0
    self.impact_id                    = inst.impact_id or C.INVALID_ID
    self.tick_impact_id               = inst.tick_impact_id or C.INVALID_ID
    self.auto_shot                    = tmpl.is_auto_shot_skill or false
    self.stand_flag                   = tmpl.stand_flag or 0
    -- GetTargetLogicByStand(): 0=要求友方, 1=要求敌方, -1=无要求
    if self.stand_flag < 0 then
        self.target_logic_by_stand = 1
    elseif self.stand_flag > 0 then
        self.target_logic_by_stand = 0
    else
        self.target_logic_by_stand = -1
    end
    self.study_level                  = inst.study_level or 0
    self.condep_terms                 = inst.condep_terms or {}
end

return SkillParam