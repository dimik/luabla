module('YMaps.GeoBounds', package.seeall)

function new(self, leftBottom, rightTop)
    local bounds = {}
    setmetatable(bounds, self)
    self.__index = self
    self._left = leftBottom:getLng()
    self._right = rightTop:getLng()
    self._top = rightTop:getLat()
    self._bottom = leftBottom:getLat()
    return bounds
end

function fromString(self, string)
    local coords = string:split(',')
    local leftBottom = YMaps.GeoPoint:new(coords[1], coords[2])
    local rightTop = YMaps.GeoPoint:new(coords[3], coords[4])
    return self:new(leftBottom, rightTop)
end


function getLeftTop(self)
    return YMaps.GeoPoint:new(self._left, self._top)
end

function getLeftBottom(self)
    return YMaps.GeoPoint:new(self._left, self._bottom)
end

function getRightTop(self)
    return YMaps.GeoPoint:new(self._right, self._top)
end

function getRightBottom(self)
    return YMaps.GeoPoint:new(self._right, self._bottom)
end


function toString(self)
    return self:getLeftBottom():toString() .. ',' .. self:getRightTop():toString()
end


function fromCenterAndSpan(self, center, span)
    local radius = 6378137
    local epsilon = 1e-6
    local span = span:split(',')

    local lc  = math.min(math.max(center:getLat() * math.pi/180, - math.pi/2 + epsilon), math.pi/2 - epsilon)
    local sy = math.max(math.min(span[2], 180), 0)
    local h = sy * math.pi/180
    local yc = radius * math.log(math.tan(lc/2 + math.pi/4))
    local C = math.exp(2 * yc / radius)
    local a = 1
    local b = (C+1) * math.tan(math.min(math.max(h/2, -math.pi/2 + epsilon), math.pi/2 - epsilon))
    local c = -C
    local D = math.max(b * b - 4 * a * c, 0)
    local root = (-b + math.sqrt(D)) / 2 * a
    local lmin = ((math.atan(root) - math.pi/4) * 2) * 180/math.pi
    local halfXSpan = math.min(span[1] / 2, 180 - epsilon)

    return self:new(
        YMaps.GeoPoint:new(center:getLng() - halfXSpan, lmin),
        YMaps.GeoPoint:new(center:getLng() + halfXSpan, lmin + sy)
    )
end

function getCenter(self)
    local tileCenter = YMaps.GeoCoordSystem:fromCoordPoint(self:getLeftBottom()):moveBy(
        YMaps.GeoCoordSystem:fromCoordPoint(self:getRightTop())
    ):scale(0.5)

    local center = YMaps.GeoCoordSystem:toCoordPoint(tileCenter)

    return YMaps.GeoPoint:new(center:getLng(), center:getLat())
end

function getSpan(self)
    return self:_getDirection():apply(math.abs)
end


function contains(self, point)
    local direction = self:_getDirection()
    local diff = self:_getDirection(point)

    return (diff:getLng() >= math.min(0, direction:getLng()) and diff:getLng() <= math.max(0, direction:getLng()) and
            diff:getLat() >= math.min(0, direction:getLat()) and diff:getLat() <= math.max(0, direction:getLat()))
end


function _getDirection(self, point)
    local point = point or self:getRightTop()
    local x = point:getLng() - self._left
    local y = point:getLat() - self._bottom

    return YMaps.GeoPoint:new(x, y)
end
