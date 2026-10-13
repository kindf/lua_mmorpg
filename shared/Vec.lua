
local Class = require("Class")

---@class Vec
local Vec = Class("Vec")

local PI = math.pi

function Vec._init(x, z)
    self.m_fX = x or 0.0
    self.m_fZ = z or 0.0
end

function Vec.copy(p)
    return { m_fX = p.m_fX, m_fZ = p.m_fZ }
end

function Vec.MySqrt(pCur, pTar)
    local dx = pCur.m_fX - pTar.m_fX
    local dz = pCur.m_fZ - pTar.m_fZ
    return math.sqrt(dx * dx + dz * dz)
end

function Vec.MyLengthSq(pCur, pTar)
    local dx = pCur.m_fX - pTar.m_fX
    local dz = pCur.m_fZ - pTar.m_fZ
    return dx * dx + dz * dz
end

function Vec.MyAngle(pCur, pTar)
    local d = Vec.MySqrt(pCur, pTar)
    if d <= 0.0 then return 0.0 end

    local fACos = (pTar.m_fZ - pCur.m_fZ) / d
    if fACos >  1.0 then fACos = 0.0 end
    if fACos < -1.0 then fACos = PI  end
    fACos = math.acos(fACos)

    if pTar.m_fX >= pCur.m_fX then
        return fACos
    else
        return 2 * PI - fACos
    end
end

function Vec.MyPosEqual(pA, pB)
    return pA.m_fX == pB.m_fX and pA.m_fZ == pB.m_fZ
end

function Vec.VerifyPos(pos, cx, cz)
    if pos.m_fX < 0 then pos.m_fX = 0 end
    if pos.m_fZ < 0 then pos.m_fZ = 0 end
    if pos.m_fX > cx then pos.m_fX = cx - 0.1 end
    if pos.m_fZ > cz then pos.m_fZ = cz - 0.1 end
end

return Vec
