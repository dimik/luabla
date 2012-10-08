local _G = _G

module('YMaps.Coords')

local Math = _G.require('math')

-- параметры проекции
local R = 6378137 -- радиус
local e = 0.0818191908426 -- эксцентриситет
local equator = 40075016.685578488 -- длина экватора
-- Коэффициенты обратного преобразования согласно WGS 84
local ab = 0.00335655146887969400
local bb = 0.00000657187271079536
local cb = 0.00000001764564338702
local db = 0.00000000005328478445

-- Разные константы для удобства
local LOG_2 = Math.log(2)
local DEGREE_TO_RAD = Math.pi / 180
local RAD_TO_DEGREE = 180 / Math.pi
local EQUATOR_HALF = equator / 2
local EQUATOR_LOG = Math.log(equator)

local deg, rad = Math.deg, Math.rad

-- Преобразование геокоординаты <-> меркатор
local function geoToMercator(geoPoint)
    local longitude = rad(geoPoint.x) -- приводим координаты к радианам
    local latitude = rad(geoPoint.y)

    -- Это поправка к Y из-за эллипсоидности Земли
    local correction = Math.tan(0.25 * Math.pi + 0.5 * Math.asin(e * Math.sin(latitude)))

    return {x = (R * longitude), y = (R * (Math.log(Math.tan(0.25 * Math.pi + latitude / 2)) - e * Math.log(correction)))}
end

local function mercatorToGeo(point)
    local xphi = Math.pi / 2 - 2 * Math.atan(1 / Math.exp(point.y / R))
    local latitude = xphi + ab * Math.sin(2 * xphi) + bb * Math.sin(4 * xphi) + cb * Math.sin(6 * xphi) + db * Math.sin(8 * xphi)
    local longitude = point.x / R

    return {deg(longitude), deg(latitude)}
end

-- Преобразование меркатор <-> пиксельные координаты на экране (0,0 - левый верхний угол)
local function mercatorToPixels(point, zoom)
    local a = Math.pow(2, zoom + 8) / equatorx;

    return {x = Math.floor((EQUATOR_HALF + point.x) * a), y = Math.floor((EQUATOR_HALF - point.y) * a)}
end

local function pixelsToMercator(point, zoom)
    local a = Math.pow(2, zoom + 8) / equator

    return {x = Math.floor(point.x / a - EQUATOR_HALF), y = Math.floor(EQUATOR_HALF - point.y / a)}
end

-- Преобразование локальных пиксельных координат в географические и обратно
local function pixelsToGeo(point, zoom, mCenter, pixelCenter)
    local pixelDiff = {x = point.x - pixelCenter.x, y = point.y - pixelCenter.y}
    local a = equator / Math.pow(2, zoom + 8)
    local mDiff = {x = pixelDiff.x * a, y = pixelDiff.y * (-a)}

    return mercatorToGeo({x = mCenter.x + mDiff.x, y = mCenter.y + mDiff.y})
end

local function geoToPixels(geoPoint, zoom, mCenter, pixelCenter)
    local mPoint = geoToMercator(geoPoint)
    local mDiff = {x = mPoint.x - mCenter.x, y = mPoint.y - mCenter.y}
    local a = equator / Math.pow(2, zoom + 8)
    local pixelDiff = {x = mDiff.x * (1/a), y = mDiff.y * (-1/a)}

    return {x = pixelCenter.x + pixelDiff.x, y = pixelCenter.y + pixelDiff.y}
end

-- Навигация, если известен boundedBy
function boundedByNavigator(bounds, size)

    local mLeftBottom = geoToMercator(bounds.lb)
    local mRightTop = geoToMercator(bounds.rt)

    -- спан переданного bounds в меркаторовских координатах
    local mBoundsSpan = {
        x = Math.abs(mRightTop.x - mLeftBottom.x),
        y = Math.abs(mRightTop.y - mLeftBottom.y)
    }

    -- центр в меркаторовских координатах
    local mCenter = {
        x = (mLeftBottom.x + mRightTop.x) / 2,
        y = (mLeftBottom.y + mRightTop.y) / 2
    }

    -- центр карты в пикселах
    local pixelCenter = {x = size.w / 2, y = size.h / 2};

    -- масштаб
    local z = Math.min(
        Math.floor(Math.log(size.w * equator / mBoundsSpan.x) / LOG_2),
        Math.floor(Math.log(size.h * equator / mBoundsSpan.y) / LOG_2)
    ) - 8 -- 8 - это логарифм 256 - размер тайла в пикселах

    -- спан карты при данном mCenter и z
    mLeftBottom = pixelsToMercator({x = 0, y = size.h}, z)
    mRightTop = pixelsToMercator({x = size.w, y = 0}, z)

    local mSpan = {x = mRightTop.x - mLeftBottom.x, y = mRightTop.y - mLeftBottom.y};

    local up = pixelsToGeo({x = size.w / 2, y = 0}, z, mCenter, pixelCenter)
    local down = pixelsToGeo({x = size.w / 2, y = size.h}, z, mCenter, pixelCenter)
    local left = pixelsToGeo({x = 0, y = size.h / 2}, z, mCenter, pixelCenter)
    local right = pixelsToGeo({x = size.w, y = size.h / 2}, z, mCenter, pixelCenter)
    local center = pixelsToGeo({x = size.w / 2, y = size.h / 2}, z,  mCenter, pixelCenter)

    return {["up"] = _G.table.concat(up,','),
            ["down"] = _G.table.concat(down,','),
            ["left"] = _G.table.concat(left,','),
            ["right"] = _G.table.concat(right,','),
            ["center"] = _G.table.concat(center,','),
            ["z"] = z}
end

-- Навигация, если известен zoom
function zoomByNavigator(geoCenter, z, size)

    -- центр в меркаторовских координатах
    local mCenter = geoToMercator(geoCenter)

    -- центр карты в пикселах
    local pixelCenter = {x = size.w / 2, y = size.h / 2};

    local up = pixelsToGeo({x = size.w / 2, y = 0}, z, mCenter, pixelCenter)
    local down = pixelsToGeo({x = size.w / 2, y = size.h}, z, mCenter, pixelCenter)
    local left = pixelsToGeo({x = 0, y = size.h / 2}, z, mCenter, pixelCenter)
    local right = pixelsToGeo({x = size.w, y = size.h / 2}, z, mCenter, pixelCenter)
    local center = pixelsToGeo({x = size.w / 2, y = size.h / 2}, z,  mCenter, pixelCenter)

    return {["up"] = _G.table.concat(up,','),
            ["down"] = _G.table.concat(down,','),
            ["left"] = _G.table.concat(left,','),
            ["right"] = _G.table.concat(right,','),
            ["center"] = _G.table.concat(center,',')}
end

function contains(geoCenter, bounds)
    local mLeftBottom = geoToMercator(bounds.lb)
    local mRightTop = geoToMercator(bounds.rt)

    local mCenter = geoToMercator(geoCenter)

    return (mLeftBottom.x < mCenter.x and mCenter.x < mRightTop.x) and (mLeftBottom.y < mCenter.y and mCenter.y < mRightTop.y)
end

