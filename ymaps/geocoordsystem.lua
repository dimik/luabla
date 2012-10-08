module('YMaps.GeoCoordSystem', package.seeall)

function new(self)
    local coordSystem = {}
    setmetatable(coordSystem, self)
    self.__index = self

    self._radius = 6378137 -- экваториальный радиус земли
    self._epsilon = 1e-10
    self._e = 0.0818191908426 -- эксцентриситет
    self._maxZoom = 23
    self._worldSize = math.pow(2, self._maxZoom + 8)
    self._equator = 40075016.685578488 -- длина экватора
    self._a = self._worldSize / self._equator
    self._b = self._equator / 2
    self._degree_to_rad = math.pi / 180
    self._rad_to_degree = 180 / math.pi

    return coordSystem
end

local coordSystem = YMaps.GeoCoordSystem:new()

function boundaryRestrict(self, value, min, max)
    return math.max(math.min(value, max), min);
end

function fromCoordPoint(self, geoPoint)
    return self:_mercatorToPixels(self:_geoToMercator(geoPoint));
end

function toCoordPoint(self, geoPoint)
    return self:_mercatorToGeo(self:_pixelsToMercator(geoPoint));
end

function _geoToMercator(self, point)
    local longitude = point:getLng() * coordSystem._degree_to_rad
    local latitude = self:boundaryRestrict(point:getLat(), -90, 90) * coordSystem._degree_to_rad

    local Rn = coordSystem._radius
    local e = coordSystem._e
    local esinLat = e * math.sin(latitude)

    local tan_temp = math.tan(math.pi / 4.0 + latitude / 2.0) or coordSystem._epsilon
    local pow_temp = math.pow(math.tan(math.pi / 4.0 + math.asin(esinLat) / 2), e)
    local U = tan_temp / pow_temp

    return YMaps.GeoPoint:new(Rn * longitude, Rn * math.log(U))
end

function _mercatorToGeo(self, point)
    local R = coordSystem._radius
    -- Коэффициенты обратного преобразования согласно WGS 84
    local ab = 0.00335655146887969400
    local bb = 0.00000657187271079536
    local cb = 0.00000001764564338702
    local db = 0.00000000005328478445
    local xphi = math.pi / 2 - 2 * math.atan(1 / math.exp(point:getLat() / R))
    local longitude = point:getLng() / R;
    local latitude = xphi + ab * math.sin(2 * xphi) + bb * math.sin(4 * xphi) + cb * math.sin(6 * xphi) + db * math.sin(8 * xphi);

    return YMaps.GeoPoint:new(longitude * coordSystem._rad_to_degree, latitude * coordSystem._rad_to_degree);
end

function _mercatorToPixels(self, point)
    return YMaps.GeoPoint:new(
        tonumber(('%.0f'):format((coordSystem._b + point:getLng()) * coordSystem._a)),
        tonumber(('%.0f'):format((coordSystem._b - point:getLat()) * coordSystem._a))
    )
end

function _pixelsToMercator(self, point)
    return YMaps.GeoPoint:new(
        point:getLng() / coordSystem._a - coordSystem._b,
        coordSystem._b - point:getLat() / coordSystem._a
    )
end

