local _M = {}

_M.pack = function (...) return {...}, _G.select('#', ...) end
_M.unpack = _G.unpack

local insert = _G.table.insert
_M.insert = function (...) return insert(...) or #... end

local function iter (t, i)
    if i < #t then
        return i + 1, t[i + 1]
    end
end

_M.pairs = _G.pairs
_M.ipairs = function (t)
    return iter, t, 0
end

return _M

