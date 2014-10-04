-- This helper module help retro-generate the clients layout from awful
-- this is a giant hack and doesn't even always work and require upstream
-- patches

local setmetatable = setmetatable
local ipairs,math  = ipairs,math
local awful        = require("awful")
local beautiful    = require("beautiful")
local color        = require( "gears.color")
local util         = require( "collision.util"   )
local capi         = { screen = screen, client=client }

local module = {}
local margin = 2
local radius = 4

-- Emulate a client using meta table magic
local function gen_cls(c,results)
  local ret = setmetatable({},{__index = function(t,i)
    local ret2 = c[i]
    if type(ret2) == "function" then
      if i == "geometry" then
        return function(self,...)
          if #{...} > 0 then
            local geom = ({...})[1]
            -- Make a copy as the original will be changed
            results[c] = awful.util.table.join(({...})[1],{})
            return geom
          end
          return c:geometry()
        end
      else
        return function(self,...) return ret2(c,...) end
      end
    end
    return ret2
  end})
  return ret
end

function module.get_geometry(tag)
  local cls,results = {},setmetatable({},{__mode="k"})
  local s = awful.tag.getscreen(tag)
  local focus,focus_wrap = capi.client.focus,nil
  for k,v in ipairs (tag:clients()) do
    cls[#cls+1] = gen_cls(v,results)
    if v == focus then
      focus_wrap = cls[#cls]
    end
  end

  -- The magnifier layout require a focussed client
  -- there wont be any as that layout is not selected
  -- take one at random or (TODO) use stack data
  if not focus_wrap then
    focus_wrap = cls[1]
  end

  local param =  {
    tag = tag,
    screen = 1,
    clients = cls,
    focus = focus_wrap,
    workarea = capi.screen[s or 1].workarea
  }

  local l = awful.tag.getproperty(tag,"layout")
  l.arrange(param)

  return results
end

local function draw_round_rect(cr,x,y,w,h)
  cr:save()
  cr:translate(x,y)
  cr:new_path()
--   cr:move_to(0,radius+1)
--   cr:line_to(0,radius)
  cr:arc(radius,radius,radius,math.pi,3*(math.pi/2))
  cr:move_to(radius,0)
  cr:line_to(w-2*radius,0)
  cr:arc(w-radius,radius,radius,3*(math.pi/2),math.pi*2)
  cr:move_to(w,radius)
  cr:line_to(w,h-radius)
  cr:arc(w-radius,h-radius,radius,math.pi*2,math.pi/2)
  cr:move_to(w-radius,h)
  cr:line_to(radius,h)
  cr:arc(radius,h-radius,radius,math.pi/2,math.pi)
  cr:move_to(0,h-radius)
  cr:line_to(0,radius)
  cr:move_to(0,radius)
  cr:close_path()
  cr:stroke_preserve()
--   cr:set_source_rgba(1,0,0,1)
--   cr:fill() --BUG
  cr:restore()
end

function module.draw(tag,cr,width,height)
  local worked = false
  local l = module.get_geometry(tag)
  local s = awful.tag.getscreen(tag)
  local scr_geo = capi.screen[s or 1].workarea
  local ratio = height/scr_geo.height
  local w_stretch = width/(scr_geo.width*ratio)
  local r,g,b = util.get_rgb()
  cr:set_source_rgba(r,g,b,0.7)
  cr:set_line_width(3)
  for c,geom in pairs(l) do
    draw_round_rect(cr,geom.x*ratio*w_stretch+margin,geom.y*ratio+margin,geom.width*ratio*w_stretch-margin*2,geom.height*ratio-margin*2)
    worked = true
  end
  --TODO floating clients
  return worked
end

return module
-- kate: space-indent on; indent-width 2; replace-tabs on;