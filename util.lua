local color        = require( "gears.color"      )
local beautiful    = require( "beautiful"        )

local module = {}


local rr,rg,rb
function module.get_rgb()
  if not rr then
    local pat = color(beautiful.fg_normal)
    local s,r,g,b,a = pat:get_rgba()
    rr,rg,rb = r,g,b
  end
  return rr,rg,rb
end

return module
-- kate: space-indent on; indent-width 2; replace-tabs on;