local math      = math
local color     = require( "gears.color" )
local beautiful = require( "beautiful"   )

local module = {settings={}}


local rr,rg,rb
function module.get_rgb()
  if not rr then
    local pat = color(beautiful.fg_normal)
    local s,r,g,b,a = pat:get_rgba()
    rr,rg,rb = r,g,b
  end
  return rr,rg,rb
end

function module.draw_round_rect(cr,x,y,w,h,radius)
  cr:save()
  cr:translate(x,y)
  cr:move_to(0,radius)
  cr:arc(radius,radius,radius,math.pi,3*(math.pi/2))
  cr:arc(w-radius,radius,radius,3*(math.pi/2),math.pi*2)
  cr:arc(w-radius,h-radius,radius,math.pi*2,math.pi/2)
  cr:arc(radius,h-radius,radius,math.pi/2,math.pi)
  cr:close_path()
  cr:restore()
end
return module
-- kate: space-indent on; indent-width 2; replace-tabs on;