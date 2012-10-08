module('YMaps', package.seeall)

local function loader (name) return package.loaders[2](name:lower())() end

package.preload['YMaps.Parser'] = loader
package.preload['YMaps.GeoPoint'] = loader
package.preload['YMaps.GeoBounds'] = loader
package.preload['YMaps.GeoCoordSystem'] = loader
package.preload['Ymaps.Coords'] = loader

require('YMaps.Parser')
require('YMaps.GeoPoint')
require('YMaps.GeoBounds')
require('YMaps.GeoCoordSystem')
require('Ymaps.Coords')

return _M
