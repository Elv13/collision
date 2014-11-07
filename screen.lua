local capi = {screen=screen,client=client,mouse=mouse}
local math,table = math,table
local wibox        = require( "wibox"         )
local awful        = require( "awful"         )
local cairo        = require( "lgi"           ).cairo
local color        = require( "gears.color"   )
local beautiful    = require( "beautiful"     )
local surface      = require( "gears.surface" )
local pango        = require( "lgi"           ).Pango
local pangocairo   = require( "lgi"           ).PangoCairo

local module = {}

local wiboxes = {}
local size  = 100
local shape = nil
local pss   = 1

-- Screen order is not always geometrical, sort them
-- local function get_first_screen()
--   local ret = {}
--   for i=1,capi.screen.count() do
--     local geom = capi.screen[i].geometry
--     if #ret == 0 then
--       ret[1] = i
--     elseif geom.x < capi.screen[ret[1]].geometry.x then
--       table.insert(ret,1,i)
--     else
--       for j=1,#ret do
--         if geom.x > capi.screen[ret[j]].geometry.x then
--           table.insert(ret,j,i)
--           break
--         end
--       end
--     end
--   end
--   return ret
-- end
local function get_first_screen()
  local ret = {}
  for i=1,capi.screen.count() do
    ret[i] = i
  end
  return ret
end
local screens = get_first_screen()

local function create_text(text)
  local img = cairo.ImageSurface(cairo.Format.ARGB32, size, size)
  local cr = cairo.Context(img)
  cr:set_source(color(text == pss and beautiful.bg_urgent or beautiful.bg_alternate or beautiful.bg_normal))
  cr:paint()
  cr:set_source(color(beautiful.fg_normal))
  cr:set_line_width(6)
  cr:arc(size/2,size/2,size/2,0,2*math.pi)
  cr:stroke()
  local pango_crx = pangocairo.font_map_get_default():create_context()
  local pango_l = pango.Layout.new(pango_crx)
  local desc = pango.FontDescription()
  desc:set_family("Verdana")
  desc:set_weight(pango.Weight.BOLD)
  desc:set_size(60 * pango.SCALE)
  pango_l:set_font_description(desc)
  pango_l.text = text
  local geo = pango_l:get_pixel_extents()
  cr:move_to(((size-geo.width)/2)*.75,0)--(size-geo.height)/2)
  cr:show_layout(pango_l)
  return surface(img)
end

local function create_shape_bounding(wa)
  local w = wibox{}
  w.width  = size
  w.height = size
  w.x=wa.x+wa.width/2-size/2
  w.y=wa.y+wa.height/2-size/2
  w.ontop = true
  if not shape then
    shape    = cairo.ImageSurface(cairo.Format.ARGB32, size, size)
    local cr = cairo.Context(shape)
    cr:set_source_rgba(0,0,0,0)
    cr:paint()
    cr:set_source_rgba(1,1,1,1)
    cr:arc(size/2,size/2,size/2,0,2*math.pi)
    cr:fill()
  end
  w.shape_bounding = shape._native
  return w
end

local function init_wiboxes(direction)
  if #wiboxes > 0 then return end
  for s=1, capi.screen.count() do
    local w = create_shape_bounding(capi.screen[s].geometry)
    wiboxes[s] = w
    w:set_widget(wibox.widget.imagebox(create_text(s)))
  end
  return true
end

local function next_screen(ss,dir,move)
  local scr_index = ss
  for k,s in ipairs(screens) do
    if ss == s then
      scr_index = k
      break
    end
  end

  if dir == "left" then
    scr_index = scr_index == 1 and #screens or scr_index - 1
  elseif dir == "right" then
    scr_index = scr_index == #screens and 1 or scr_index+1
  end

  local geom = capi.screen[scr_index].geometry
  capi.mouse.coords({x=geom.x+geom.width/2,y=geom.y+geom.height/2+55})

  if move then
    local t = awful.tag.selected(ss)
    awful.tag.setscreen(t,scr_index)
    awful.tag.viewonly(t)
  else
    local c = awful.mouse.client_under_pointer()
    if c then
      capi.client.focus = c
    end
  end

  return scr_index
end

function module.display(_,dir,move)
  if #wiboxes == 0 then
    init_wiboxes(dir)
  end
  module.reload(nil,direction)
  local ss,opss = capi.client.focus and capi.client.focus.screen or capi.mouse.screen,pss
  next_screen(ss,dir,move)
  module.reload(nil,direction)
end

function module.hide()
  if #wiboxes == 0 then return end

  for s=1, capi.screen.count() do
    wiboxes[s].visible = false
  end
end

function module.reload(mod,dir,__,___,move)
print("LA",mod and #mod)
  local ss,opss = capi.client.focus and capi.client.focus.screen or capi.mouse.screen,pss
  if dir then
    ss = next_screen(ss,dir:lower(),move or (mod and #mod == 4))
  end

  if pss ~= ss then
    pss = nil
    wiboxes[opss]:set_widget(wibox.widget.imagebox(create_text(opss)))
    pss = ss
    wiboxes[ss]:set_widget(wibox.widget.imagebox(create_text(ss)))
  end

  for s=1, capi.screen.count() do
    wiboxes[s].visible = true
  end
  return true
end

return module
-- kate: space-indent on; indent-width 2; replace-tabs on;