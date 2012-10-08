local xml = {
    ['ELEMENT'] = 1,
    ['ATTRIBUTE'] = 2,
    ['TEXT'] = 3,
    ['CDATA_SECTION'] = 4,
    ['ENTITY_REFERENCE'] = 5,
    ['ENTITY'] = 6,
    ['PROCESSING_INSTRUCTION'] = 7,
    ['COMMENT'] = 8,
    ['DOCUMENT'] = 9,
    ['DOCUMENT_TYPE'] = 10,
    ['DOCUMENT_FRAGMENT'] = 11,
    ['NOTATION'] = 12,
}

local element = {
    __call = function (self, t) return setmetatable(t, self) end,
    __concat = function (a, b) return tostring(a) .. tostring(b) end,
    __index = function (self, key) return xml[key:match('%w+')] end,
    __tostring = function (elem)
        local name, attributes, content = xml.getElemName(elem), xml.getElemAttrs(elem), xml.getElemChildren(elem)

        return ('<%s%s%s>'):format(name,
            #attributes > 0 and (' %s'):format(table.concat(attributes, ' ')) or '',
            #content > 0 and ('>%s</%s'):format(table.concat(content), name) or '/'
        )
    end,
}

local attribute = {
    __tostring = function (attr)
        return ('%s="%s"'):format(attr.name, attr.value)
    end,
    __call = function (self, name, value)
        return setmetatable({name = name, value = value}, self)
    end,
}

local options = {
    elemNS = '',
    elemName = 'param',
    indent = false,
    attrsOrder = false,
    escapedChars = {
        ['>'] = '&gt;',
        ['<'] = '&lt;',
        ['&'] = '&amp;',
        ["'"] = '&apos;',
        ['"'] = '&quot;',
    },
    unescapedChars = {
        ['&gt;'] = '>',
        ['&lt;'] = '<',
        ['&amp;'] = '&',
        ['&apos;'] = "'",
        ['&quot;'] = '"',
    },
}

local function setOptions(self, opt)
    for k, v in pairs(opt) do
        options[k] = v
    end
    return self
end

xml.escape = function (value)
    return (tostring(value):gsub('[<>&\'"]', options.escapedChars))
end

xml.unescape = function (value)
    return (value:gsub('&[%w]+;', options.unescapedChars))
end

xml.getElemNS = function (elem)
    local xmlns = rawget(elem, 'xmlns')
    return xmlns and xmlns[''] or options.elemNS
end

xml.getAttrNS = function (name)
    return name == 'xmlns' and name or name:match('^([^:]+):')
end

xml.getElemName = function (elem)
    local name = rawget(elem, 1)
    return type(name) == 'string' and name or options.elemName
end

xml.getLocalName = function (name)
    return name == 'xmlns' and '' or name:match('[^:]+$')
end

xml.getElemType = function (elem)
    local elemType = 'ELEMENT'

    if type(elem) == 'table' then
        elemType = #elem > 0 and 'ELEMENT' or 'ATTRIBUTE'
    else
        elem = tostring(elem)
        elemType = elem:find('%]%]>%s*$') and 'CDATA_SECTION'
            or elem:find('^%s*<!%-%-') and 'COMMENT'
            or elem:find('^%s*<%?') and 'PROCESSING_INSTRUCTION'
            or elem:find('^%s*</?[_:%a][_:%w%-.]*.-/?>') and 'ELEMENT'
            or 'TEXT'
    end

    return elemType, xml[elemType]
end

xml.attributes = function (elem)
    return coroutine.wrap(function ()
        for name, value in next, elem, #elem ~= 0 and #elem or nil do
            if xml.getElemType(value) == 'ATTRIBUTE' then
                for n, v in next, value, #value ~= 0 and #value or nil do
                    coroutine.yield(xml.escape(#n > 0 and ('%s:%s'):format(name, n) or name), xml.escape(v))
                end
            else
                coroutine.yield(xml.escape(name), xml.escape(value))
            end
        end
    end)
end

local function attrSortOrder(order)
    return type(order) == 'function' and order or function (a, b)
        local priority

        if order == 'desc' then
            priority = a > b
        else
            priority = a < b
        end

        if a:find('^xmlns=') or b:find('^xmlns=') then
            return a:find('^xmlns=') and true
        elseif a:find('^xmlns:') then
            return not b:find('^xmlns:') and true or priority
        elseif b:find('^xmlns:') then
            return false
        else
            return priority
        end
    end
end

xml.getElemAttrs = function (elem)
    local attrs = {}

    for attr, val in xml.attributes(elem) do
        attrs[#attrs + 1] = tostring(xml.attribute(attr, val))
    end

    if options.attrsOrder then
        table.sort(attrs, attrSortOrder(options.attrsOrder))
    end

    return attrs
end

xml.children = function (elem)
    return coroutine.wrap(function ()
        for i = 2, #elem do
            local child = elem[i]
            local elemType, elemTypeNum = xml.getElemType(child)

            if elemType == 'ELEMENT' then
                --[[
                if not child.xmlns and #xml.getElemNS(elem) > 0 then
                    child.xmlns = {[''] = xml.escape(xml.getElemNS(elem))}
                end
                ]]
                child = xml.element(child)
            else
                child = elemTypeNum > 3 and child or xml.escape(child)
            end
            coroutine.yield(child)
        end
    end)
end

xml.getElemChildren = function (elem)
    local children = {}

    for child in xml.children(elem) do
        table.insert(children, tostring(child))
    end

    return children
end

local function tidy(s)
    local level = 0

    return (tostring(s):gsub('%b<>', function (elem)
        local emptyElemTag = elem:find('/>$')
        local endElemTag = elem:find('^</')
        local elemType, elemTypeNum  = xml.getElemType(elem)
        local indent = '\n' .. (' '):rep((endElemTag and level - 1 or level) * 4)

        if elemType == 'CDATA_SECTION' or elemType == 'COMMENT' then
            return elem
        elseif elemType == 'ELEMENT' then
            if not emptyElemTag then
                level = level + (endElemTag and -1 or 1)
            end
            -- print(elemType, elem, level, emptyElemTag)
            return (elemTypeNum < 3 or endElemTag) and indent .. elem or elem
        end
    end))
end

local function stringify(t)
    if type(t) == 'table' then
        if type(t[1]) == 'string' then
            return options.indent and tidy(xml.element(t)) or tostring(xml.element(t))
        else
            local children = {}
            for name, value in pairs(t) do
                table.insert(children, tostring(xml.element({name, value})))
            end
            return table.concat(children)
        end
    end
end

-- @see http://www.w3.org/TR/xml/#NT-AttValue
local function elemAttrsToLuaTableString(elem)
    local mt = {}
    mt.__concat = function (a, b) return tostring(a) .. tostring(b) end
    mt.__tostring = function (t)
        local attrs = {}
        for k, v in pairs(t) do
            attrs[#attrs + 1] = ('["%s"]=%s'):format(k, xml.getElemType(v) == 'ATTRIBUTE' and
                ('{%s}'):format(tostring(setmetatable(v, mt))) or ('[[%s]]'):format(xml.unescape(v)))
        end
        return table.concat(attrs, ',')
    end

    local attrs = setmetatable({}, mt)

    for name, value in elem:gmatch('([_:%a][_:%w%-.]*)%s?=%s?[\'"]([^\'"]*)[\'"]') do
        local attrNS = xml.getAttrNS(name)
        if attrNS then
            attrs[attrNS] = attrs[attrNS] or {}
            attrs[attrNS][xml.getLocalName(name)] = value
        else
            attrs[name] = value
        end
    end

    return next(attrs) and ',' .. attrs or ''
end

-- @see http://www.w3.org/TR/xml/#NT-Name
local function elemTagToLuaTableString(s)
    return (s:gsub('</.->', '},') -- process closed tags
        :gsub('<([_:%a][_:%w%-.]*)(.-)(/?>)', function (elemName, attrs, empty) -- process xml element tag
            return ('{"%s"%s%s'):format(elemName,
                elemAttrsToLuaTableString(attrs), -- process element attributes
                (empty:gsub('[/>]+', {
                    ['/>'] = '},', -- close table for empty element
                    ['>'] = ',' -- comma for separate content
                }))
            )
        end))
end

local function elemContentToLuaTableString(s)
    return s:find('^%s*$') and '' or ('[[%s]],'):format(xml.unescape(s))
end

local function parse(s)
    local status, result = pcall(load(coroutine.wrap(function ()
        coroutine.yield('return ')
        for elem, content in s:gmatch('(%b<>)(.-%f[<])') do
            local elemType = xml.getElemType(elem)

            if elemType == 'CDATA_SECTION' or elemType == 'COMMENT' then
                coroutine.yield(('[=[%s]=],'):format(elem))
            elseif elemType == 'PROCESSING_INSTRUCTION' then
                -- coroutine.yield(('{[[%s]],[[%s]]},'):format(elem:match('<%?([_:%a][_:%w%-.]*)%s*(.*)%s*%?>')))
            elseif elemType == 'ELEMENT' then
                coroutine.yield(elemTagToLuaTableString(elem) .. elemContentToLuaTableString(content))
            end
        end
        coroutine.yield('}')
    end)))

    return status and xml.element(result) or result
end

xml.__call = setOptions
xml.__index = {nodeset = stringify}

xml.element = setmetatable(element, element)
xml.attribute = setmetatable(attribute, attribute)

xml.stringify = stringify
xml.parse = parse

return setmetatable(xml, xml)
