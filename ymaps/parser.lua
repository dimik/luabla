module('YMaps.Parser', package.seeall)

-- Максимально возможная широта
local MAX_LAT = 90

-- Шаблоны значений
local DEG = '[°%s]*'
local MIN = "['′%s]*"
local SEC = '["″%s]*'
local PARTS_EN = '[%sNEWS]+'
local PARTS_ALL = '[%sNEWS.СсЮюВвЗзШшДд]*'
local LNG_EN = '[EW]'
local LAT_EN = '[NS]'
local LNG_ALL = '[EWВвЗзДд]'
local LAT_ALL = '[NSСсЮюШш]'
local COORD = '[%d.]'
local COORD_COMMA = '[%d.,]'
local DELIM = '[%s,]+'
local SIGN = '[-+]'

-- Тип парсера
local PARSER = {
    NMEA = '%d?%d%d%d%d%.%d+' .. DELIM .. PARTS_EN,
    DMS = '^%s*(' .. PARTS_ALL .. ')(' .. SIGN .. '?)(' .. COORD .. '+)' .. DEG .. '(' .. COORD_COMMA .. '*)' .. MIN .. '(' .. COORD .. '*)' .. SEC .. '(' .. PARTS_ALL .. ')' .. DELIM .. '(' .. PARTS_ALL .. ')(' .. SIGN .. '?)(' .. COORD .. '+)' .. DEG .. '(' .. COORD_COMMA .. '*)' .. MIN .. '(' .. COORD .. '*)' .. SEC .. '(' .. PARTS_ALL .. ')$'
}

function parseDMS(coords)
    local SIGNS = {
        ['+'] = {'\208[\146\161\178]', '\209\129', '[EN]'},
        ['-'] = {'\208[\151\174\183]', '\209\142', '[WS]'}
    }

    local sign, part, deg, min, sec = {}, {}, {}, {}, {}
    local spart1, spart2, epart1, epart2, lngIndex, latIndex

    local function getSign(sign, part)
        sign = sign == '-' and '-' or '+'
        if part and #part > 0 then
            for i = 1, #SIGNS['-'] do
                sign = (part:find(SIGNS['-'][i]) and '-') or (part:find(SIGNS['+'][i]) and '+') or sign
            end
        end
        return sign
    end

    local function isLng(part)
        local LNG = {'\208[\146\178\151\183]', LNG_EN}
        local result = false

        for _, re in ipairs(LNG) do
            if part:find(re) then
                result = true
                break
            end
        end

        return result
    end

    local function getCoordByIndex(index)
        return {
            sign = getSign(sign[index], part[index]),
            deg = tonumber(deg[index]),
            min = tonumber(min[index] and min[index]:gsub(',', '.')) or 0,
            sec = tonumber(sec[index]) or 0,
        }
    end

    local function convertDMStoDd(DMS)
        local Dd = DMS.deg and tonumber(DMS.sign .. DMS.deg + DMS.min / 60 + DMS.sec / 3600)
        return Dd and tonumber(('%.6f'):format(Dd))
    end

    spart1, sign[1], deg[1], min[1], sec[1], epart1, spart2, sign[2], deg[2], min[2], sec[2], epart2 = coords:match(PARSER.DMS)
    part[1], part[2] = spart1 .. epart1, spart2 .. epart2

    lngIndex = isLng(part[2]) and 2 or 1
    latIndex = lngIndex == 2 and 1 or 2

    local lng = convertDMStoDd(getCoordByIndex(lngIndex))
    local lat = convertDMStoDd(getCoordByIndex(latIndex))

    return lng, lat
end

function parseNMEA(coords)
    local LNG_COORD = '%d%d%d%d%d.%d+'
    local LAT_COORD = '%d%d%d%d.%d+'
    local SIGNS = {E = '+', N = '+', W = '-', S = '-'}

    local function getDMm(coord)
        local DMm = type(coord) == 'string' and {
            sign = coord:match('^' .. SIGN),
            deg = tonumber(coord:match('^' .. SIGN .. '(%d+)%.'):sub(1,-3)) or 0,
            min = tonumber(coord:match('^.-(%d%d%.%d+)')) or 0
        }
        return DMm
    end

    local function getSign(part)
        return SIGNS[part] and SIGNS[part] or '+'
    end

    local function getLng(coords)
        local coord, part = coords:match('(' .. LNG_COORD .. '),(' .. LNG_EN .. ')')
        return coord and getSign(part) .. coord
    end

    local function getLat(coords)
        local coord, part = coords:match('(' .. LAT_COORD .. '),(' .. LAT_EN .. ')')
        return coord and getSign(part) .. coord
    end

    local function convertDMmtoDd(DMm)
        local Dd = type(DMm) == 'table' and tonumber(DMm.sign .. DMm.deg + DMm.min / 60)
        return Dd and tonumber(('%.5f'):format(Dd))
    end

    local lng = convertDMmtoDd(getDMm(getLng(coords)))
    local lat = convertDMmtoDd(getDMm(getLat(coords)))

    return lng, lat
end

function parse(coords)
    local lng, lat

    if type(coords) == 'string' and #coords > 0 then
        for name, re in pairs(PARSER) do
            if coords:find(re) then
                lng, lat = _M['parse' .. name](coords)
                break
            end
        end
    end

    -- Если Широта по модулю > 90°, значит это Долгота!
    if lat and math.abs(lat) > MAX_LAT then
        lng, lat = lat, lng
    end

    return lng, lat
end

