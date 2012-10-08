-- Experimental. Don't use it
local strMeta = getmetatable("")
strMeta.__index = function(str, i)
    return tonumber(i) and string.sub(str, i, i) or function(...) return string[i](...) end
end
strMeta.__mul = string.rep
strMeta.__mod = function(str, tbl) return string.format(str, unpack(tbl)) end
strMeta.__call = string.format
strMeta.__add = function(str1, str2) return str1 .. str2 end

debug.setmetatable(1, {__len = math.abs, __index = math})

debug.setmetatable(nil, {__index = function() end, __concat = function(a, b) return a or b end})
