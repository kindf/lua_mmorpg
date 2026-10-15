local C = require("Define.Constants")

return {
    -- 1001 烈焰弹：瞬发单体，带消耗与冷却
    [1001] = {
        id = 1001,
        name = "烈焰弹",
        menpai = 0,
        skill_class = 1,
        class_by_user = 0,
        passive_flag = 0,
        select_type = C.SELECT_TYPE.CHARACTER,
        stand_flag = -1,
        is_auto_shot_skill = false,
        can_interrupt_auto_shot = 1,
        must_use_weapon = false,
        target_must_in_special_state = 0,
        instances = {
            {
                level = 1,
                logic_id = 1,
                skill_type = C.SKILL_INSTANT_LAUNCHING,
                delay_time = 100,
                cooldown_id = 101,
                cooldown_time = 1500,
                play_action_time = 800,
                targeting_logic = C.TARGET_LOGIC.SPECIFIC_UNIT,
                select_type = C.SELECT_TYPE.CHARACTER,
                target_check_by_obj_type = -1,
                target_must_in_special_state = 0,
                accuracy = 100,
                critical_rate = 20,
                charges_or_interval = 1,
                impact_id = 5001,
                condep_terms = {
                    {
                        kind = "mp",
                        value = 30
                    }
                }
            }
        }
    },
    -- 1002 三连斩：charges_or_interval = 3，演示 ActivateOnce 循环
    [1002] = {
        id = 1002,
        name = "三连斩",
        menpai = 0,
        skill_class = 1,
        class_by_user = 0,
        passive_flag = 0,
        select_type = C.SELECT_TYPE.CHARACTER,
        stand_flag = -1,
        is_auto_shot_skill = false,
        can_interrupt_auto_shot = 1,
        must_use_weapon = false,
        target_must_in_special_state = 0,
        instances = {
            {
                level = 1,
                logic_id = 1,
                skill_type = C.SKILL_INSTANT_LAUNCHING,
                delay_time = 80,
                cooldown_id = 102,
                cooldown_time = 2000,
                play_action_time = 600,
                targeting_logic = C.TARGET_LOGIC.SPECIFIC_UNIT,
                select_type = C.SELECT_TYPE.CHARACTER,
                target_check_by_obj_type = -1,
                target_must_in_special_state = 0,
                accuracy = 95,
                critical_rate = 15,
                charges_or_interval = 3,
                impact_id = 5001,
                condep_terms = {
                    {
                        kind = "mp",
                        value = 15
                    }
                }
            }
        }
    },
    -- 1003 聚气术：GATHER，演示 StartCharging 注册充能动作
    [1003] = {
        id = 1003,
        name = "聚气术",
        menpai = 0,
        skill_class = 1,
        class_by_user = 0,
        passive_flag = 0,
        select_type = C.SELECT_TYPE.SELF,
        stand_flag = -1,
        is_auto_shot_skill = false,
        can_interrupt_auto_shot = 1,
        must_use_weapon = false,
        target_must_in_special_state = -1,
        instances = {
            {
                level = 1,
                logic_id = 1,
                skill_type = C.SKILL_NEED_CHARGING,
                charge_time = 2000,
                cooldown_id = 103,
                cooldown_time = 3000,
                play_action_time = 500,
                targeting_logic = C.TARGET_LOGIC.AE_AROUND_SELF,
                ae_radius = 5.0,
                select_type = C.SELECT_TYPE.SELF,
                target_check_by_obj_type = -1,
                target_must_in_special_state = -1,
                accuracy = 100,
                critical_rate = 0,
                charges_or_interval = 1,
                impact_id = 5002,
                condep_terms = { { kind = "mp", value = 50 } }
            }
        }
    },

    -- 1004 引导箭：LEAD，演示 StartChanneling + 心跳
    [1004] = {
        id = 1004,
        name = "引导箭",
        menpai = 0,
        skill_class = 1,
        class_by_user = 0,
        passive_flag = 0,
        select_type = C.SELECT_TYPE.CHARACTER,
        stand_flag = -1,
        is_auto_shot_skill = false,
        can_interrupt_auto_shot = 1,
        must_use_weapon = false,
        target_must_in_special_state = 0,
        instances = {
            {
                level = 1,
                logic_id = 1,
                skill_type = C.SKILL_NEED_CHANNELING,
                channel_time = 3000,
                cooldown_id = 104,
                cooldown_time = 1000,
                play_action_time = 400,
                targeting_logic = C.TARGET_LOGIC.SPECIFIC_UNIT,
                select_type = C.SELECT_TYPE.CHARACTER,
                target_check_by_obj_type = -1,
                target_must_in_special_state = 0,
                accuracy = 100,
                critical_rate = 10,
                charges_or_interval = 1000,
                impact_id = 5003,
                tick_impact_id = 5003,
                condep_terms = { { kind = "mp", value = 20 } }
            }
        }
    },
    -- 1005 火雨：AE，演示 TARGET_AE_AROUND_POSITION
    [1005] = {
        id = 1005,
        name = "火雨",
        menpai = 0,
        skill_class = 1,
        class_by_user = 0,
        passive_flag = 0,
        select_type = C.SELECT_TYPE.POS,
        stand_flag = -1,
        is_auto_shot_skill = false,
        can_interrupt_auto_shot = 1,
        must_use_weapon = false,
        target_must_in_special_state = -1,
        instances = {
            {
                level = 1,
                logic_id = 1,
                skill_type = C.SKILL_INSTANT_LAUNCHING,
                delay_time = 200,
                cooldown_id = 105,
                cooldown_time = 4000,
                play_action_time = 1000,
                targeting_logic = C.TARGET_LOGIC.AE_AROUND_POSITION,
                ae_radius = 6.0,
                select_type = C.SELECT_TYPE.POS,
                target_check_by_obj_type = -1,
                target_must_in_special_state = -1,
                accuracy = 100,
                critical_rate = 5,
                charges_or_interval = 1,
                impact_id = 5002,
                condep_terms = { { kind = "mp", value = 80 } }
            }
        }
    },

    -- 1006 连射：自动连发技能，走 m_nAutoShotSkill 通道
    [1006] = {
        id = 1006,
        name = "连射",
        menpai = 0,
        skill_class = 1,
        class_by_user = 0,
        passive_flag = 0,
        select_type = C.SELECT_TYPE.CHARACTER,
        stand_flag = -1,
        is_auto_shot_skill = true,
        can_interrupt_auto_shot = 1,
        must_use_weapon = false,
        target_must_in_special_state = 0,
        instances = {
            {
                level = 1,
                logic_id = 1,
                skill_type = C.SKILL_INSTANT_LAUNCHING,
                delay_time = 50,
                cooldown_id = 106,
                cooldown_time = 500,
                play_action_time = 300,
                targeting_logic = C.TARGET_LOGIC.SPECIFIC_UNIT,
                select_type = C.SELECT_TYPE.CHARACTER,
                target_check_by_obj_type = -1,
                target_must_in_special_state = 0,
                accuracy = 100,
                critical_rate = 10,
                charges_or_interval = 1,
                impact_id = 5001,
                condep_terms = { { kind = "mp", value = 5 } }
            }
        }
    },

    -- 1007 治疗术：stand_flag = 1（正面技能，需同阵营）
    [1007] = {
        id = 1007,
        name = "治疗术",
        menpai = 0,
        skill_class = 1,
        class_by_user = 0,
        passive_flag = 0,
        select_type = C.SELECT_TYPE.CHARACTER,
        stand_flag = 1,
        is_auto_shot_skill = false,
        can_interrupt_auto_shot = 1,
        must_use_weapon = false,
        target_must_in_special_state = 0,
        instances = {
            {
                level = 1,
                logic_id = 1,
                skill_type = C.SKILL_INSTANT_LAUNCHING,
                delay_time = 0,
                cooldown_id = 107,
                cooldown_time = 2000,
                play_action_time = 700,
                targeting_logic = C.TARGET_LOGIC.SPECIFIC_UNIT,
                select_type = C.SELECT_TYPE.CHARACTER,
                target_check_by_obj_type = -1,
                target_must_in_special_state = 0,
                accuracy = 100,
                critical_rate = 0,
                charges_or_interval = 1,
                impact_id = 5004,
                condep_terms = { { kind = "mp", value = 40 } }
            }
        }
    }
}
