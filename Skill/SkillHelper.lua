local CfgSkill = require("Config.CfgSkill")
local Log = require("Tool.Log")

local SkillHelper = {}

function SkillHelper.GetSkillTemplate(skill_id)
    local template = CfgSkill[skill_id]
    if not template then
        Log.error(string.format("技能模板不存在，skill_id=%s", skill_id))
    end
    return template
end

function SkillHelper.GetSkillInstance(skill_id, level)
    local template = SkillHelper.GetSkillTemplate(skill_id)
    if not template then
        return nil
    end
    local instance = template.instances[level]
    if not instance then
        Log.error(string.format("技能实例数据不存在，skill_id=%s, level=%s", skill_id, level))
        return nil
    end
    return instance
end

return SkillHelper