local _M = {}

_M.default = function (string, default)
    return #string > 0 and string or default
end

_M.split = function (string, sep, complex)
    local i, j, tokens = 0, 0, {}
    if not sep or sep == '' then sep = ' ' end
    repeat
        local k = j + 1
        i, j = string:find(sep, k, not complex)
        table.insert(tokens, string:sub(k, (i or 0) - 1))
    until not i
    return tokens
end

_M.replace = function (string, search, replace)
    return table.concat(_M.split(string, search), replace)
end

return _M

