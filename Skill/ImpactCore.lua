--------------------------------------------------------------------------------
-- ImpactCore：延迟生效的效果
--------------------------------------------------------------------------------
local CfgImpacts = require("Config.CfgImpacts")
local Log = require("Tool.Log")
local Class = require("Tool.Class")

---@class ImpactCore
local ImpactCore = Class("ImpactCore")

function ImpactCore:_init()
    self.pending = {}
    self._seq = 0
end

-- 对应 Obj_Character::Impact_SendSpecificImpactToUnit / LuaFnSendSpecificImpactToUnit
function ImpactCore:SendSpecificImpactToUnit(caster, target, impact_id, delay_time, uTime)
    local def = CfgImpacts[impact_id]
    self._seq = self._seq + 1
    table.insert(self.pending, {
        seq = self._seq, caster = caster, target = target,
        impact_id = impact_id, def = def,
        due = (uTime or 0) + (delay_time or 0), applied = false,
    })
    Log.msg(string.format("注册 Impact %d(%s) -> %s  delay=%dms",
        impact_id, def and def.name or "?", target:GetName(), delay_time or 0))
end

-- 心跳：到期的 Impact 才真正起作用
function ImpactCore:Tick(uTime)
    for _, imp in ipairs(self.pending) do
        if (not imp.applied) and uTime >= imp.due then
            imp.applied = true
            local def = imp.def
            if def then
                if def.kind == "damage" then
                    imp.target:OnDamage(def.amount, imp.caster)
                elseif def.kind == "heal" then
                    imp.target:OnHeal(def.amount, imp.caster)
                end
            end
        end
    end
end

function ImpactCore:CleanUp() 
    self.pending = {} 
end

---@type ImpactCore
local GImpactCore

function ImpactCore.GetInstance()
    if not GImpactCore then
        GImpactCore = ImpactCore.new()
    end
    return GImpactCore
end

return ImpactCore