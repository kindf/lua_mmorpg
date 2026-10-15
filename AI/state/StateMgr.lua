local Class = require("Tool.Class")
local C = require("Tool.Constants")
local IdleState = require("AI.State.IdleState")
local CombatState = require("AI.State.CombatState")
local DeadState = require("AI.State.DeadState")
local PatrolState = require("AI.State.PatrolState")

---@type StateMgr
local GStateMgr

---@class StateMgr
local StateMgr = Class("StateMgr")

function StateMgr:_init()
    self._byID = {}
    self._byID[C.ESTATE.IDLE] = IdleState.new(C.ESTATE.IDLE)
    self._byID[C.ESTATE.COMBAT] = CombatState.new(C.ESTATE.COMBAT)
    self._byID[C.ESTATE.DEAD] = DeadState.new(C.ESTATE.DEAD)
    self._byID[C.ESTATE.PATROL] = PatrolState.new(C.ESTATE.PATROL)
end

---@return State
function StateMgr:InstanceState(id)
    return self._byID[id]
end

function StateMgr.GetInstance()
    if not GStateMgr then
        GStateMgr = StateMgr.new()
    end
    return GStateMgr
end

return StateMgr