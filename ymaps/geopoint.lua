module('YMaps.GeoPoint', package.seeall)

function new(self, lng, lat)
    local point = {}
    setmetatable(point, self)
    self.__index = self
    point:setLng(lng):setLat(lat)
    return point
end

function fromString(self, coords)
    local lng, lat = unpack(coords:split(','))
    lng, lat = tonumber(lng), tonumber(lat)
    return lng and lat and self:new(lng, lat)
end

function parse(self, coords)
    local lng, lat = YMaps.Parser.parse(coords)
    return lng and lat and self:new(lng, lat)
end

function setLng(self, lng)
    self._lng = tonumber(lng)
    return self
end

function getLng(self)
    return self._lng;
end

function setLat(self, lat)
    self._lat = tonumber(lat)
    return self
end

function getLat(self)
    return self._lat;
end


function toString(self)
    return ('%f,%f'):format(self:getLng(), self:getLat())
end

function moveBy(self, point)
    self:setLng(self:getLng() + point:getLng())
    self:setLat(self:getLat() + point:getLat())

    return self
end

function scale(self, scale)
    self:setLng(self:getLng() * scale)
    self:setLat(self:getLat() * scale)

    return self
end

function apply(self, func)
    self:setLng(func(self:getLng()))
    self:setLat(func(self:getLat()))
    return self
end


function rulerDistance(self, point)
    local long1 = self:getLng()
    local lat1 = self:getLat()
    local long2 = point:getLng()
    local lat2 = point:getLat()
    local dist = 0

    local radius = 6378137
    local epsilon = 1e-6

    if (not(math.abs(lat2 - lat1) < epsilon and math.abs(long1 - long2) < epsilon)) then
        local latAV = (lat1 + (lat2 - lat1) / 2) * math.pi / 180
        local pathAngle = math.atan(((long2 * 60 - long1 * 60)/ ( lat2 * 60 - lat1 * 60)) * math.cos(latAV))
        local distPerDegree = 2 * math.pi * radius / 360;

        dist = math.abs(lat2 - lat1) < epsilon
                and math.abs(((long2 - long1) / math.sin(pathAngle)) * math.cos(latAV) * distPerDegree)
                or math.abs(distPerDegree * (lat2 - lat1) / math.cos(pathAngle));
    end

    return dist
end
