local _M = {}
local superstring = require('superstring')

_M.encoding = 'utf-8'
_M.encode = xscript and xscript.urlencode
_M.decode = xscript and xscript.urldecode

local addParam = function (query, key, value, replacer)
    if type(replacer) == 'function' then
        value = replacer(key, value)
    elseif type(replacer) == 'table' and #replacer > 0 then
        local allowed
        for _, allow in ipairs(replacer) do
            allowed = key == allow
            if allowed then break end
        end
        value = allowed and value
    end
    if value then
        key = _M.encode(tostring(key), _M.encoding)
        value = _M.encode(tostring(value), _M.encoding)
        table.insert(query, key .. '=' .. value)
    end
end

_M.stringify = function (params, replacer)
    local query = {}
    for key, value in pairs(params) do
        if type(key) == 'number' and type(value) == 'table' then
            key, value = unpack(value)
        end
        if type(value) == 'table' then
            for i, value in ipairs(value) do
                addParam(query, key, value, replacer)
            end
        else
            addParam(query, key, value, replacer)
        end
    end
    return table.concat(query, '&')
end

_M.parse = function (query, reviver)
    local params = {}
    for i, param in ipairs(superstring.split(query, '&')) do
        local key, value = unpack(superstring.split(param, '='))
        key = _M.decode(key, _M.encoding)
        value = _M.decode(value or '', _M.encoding)
        if type(reviver) == 'function' then
            value = reviver(key, value)
        end
        params[key] = value
    end
    return params
end

return _M

