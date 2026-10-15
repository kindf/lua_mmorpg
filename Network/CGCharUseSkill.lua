local C = require("Tool.Constants")
local Log = require("Tool.Log")
local Data = require("Config.GameData")
local Protocol = require("Network.Protocol")
local Class = require("Tool.Class")

---@class CGCharUseSkill
local CGCharUseSkill = Class("CGCharUseSkill")

function CGCharUseSkill:_init(t)
    self.m_ObjID = t.objID
    self.m_SkillDataID = t.skillDataID -- skillID*100 + skillLevel
    self.m_guidTarget = t.m_guidTarget or C.INVALID_GUID
    self.m_TargetID = t.targetID
    self.m_posTarget = t.posTarget or {m_fX = 0.0, m_fZ = 0.0}
    self.m_fDir = t.fDir or 0.0
end

function CGCharUseSkill:GetObjID()
    return self.m_ObjID
end

function CGCharUseSkill:GetSkillDataID()
    return self.m_SkillDataID
end

function CGCharUseSkill:GetTargetID()
    return self.m_TargetID
end

function CGCharUseSkill:GetTargetGUID()
    return self.m_guidTarget
end

function CGCharUseSkill:GetDir()
    return self.m_fDir
end

function CGCharUseSkill:GetTargetPos()
    return self.m_posTarget
end

return CGCharUseSkill