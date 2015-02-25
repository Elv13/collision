local math      = math
local color     = require( "gears.color" )
local beautiful = require( "beautiful"   )
local glib      = require("lgi").GLib
local cairo        = require( "lgi"            ).cairo

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

function module.arrow_path(cr, width, sidesize)
  cr:rel_move_to( 0                   , -width/2 )
  cr:rel_line_to( width/2             , width/2  )
  cr:rel_line_to( -sidesize           , 0        )
  cr:rel_line_to( 0                   , width/2  )
  cr:rel_line_to( (-width)+2*sidesize , 0        )
  cr:rel_line_to( 0                   , -width/2 )
  cr:rel_line_to( -sidesize           , 0        )
  cr:rel_line_to( width/2             , -width/2 )
  cr:close_path()
end

function module.arrow(width, sidesize, margin, bg_color, fg_color)
  local img = cairo.ImageSurface(cairo.Format.ARGB32, width+2*margin, width+2*margin)
  local cr = cairo.Context(img)
  cr:set_source(color(bg_color))
  cr:paint()
  cr:set_source(color(fg_color))
  cr:set_antialias(cairo.Antialias.NONE)
  cr:move_to(margin+width/2, margin+width/2)
  module.arrow_path(cr, width, sidesize)
  cr:fill()
  return cairo.Pattern.create_for_surface(img)
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

local function refresh_dt(last_sec,last_usec,callback,delay)
  local tv = glib.TimeVal()
  glib.get_current_time(tv)
  local dt = (tv.tv_sec*1000000+tv.tv_usec)-(last_sec*1000000+last_usec)
  if dt < delay then
    callback()
  end
  return tv.tv_sec,tv.tv_usec
end

function module.double_click(callback,delay)
  delay = delay or 250000
  local ds,du = 0,0
  return function()
    ds,du = refresh_dt(ds,du,callback,delay)
  end
end

return module
-- kate: space-indent on; indent-width 2; replace-tabs on;