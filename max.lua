local capi = {screen=screen,client=client}
local wibox = require("wibox")
local awful = require("awful")
local cairo        = require( "lgi"          ).cairo
local color        = require( "gears.color"  )
local beautiful    = require( "beautiful"    )
local surface      = require( "gears.surface" )
local pango = require("lgi").Pango
local pangocairo = require("lgi").PangoCairo
local module = {}

local w = nil
local rad = 10

local function init()
  w = wibox{}
  w.ontop = true
  w.visible = true
end

local rr,rg,rb
local function get_rgb()
  if not rr then
    local pat = color(beautiful.fg_normal)
    local s,r,g,b,a = pat:get_rgba()
    rr,rg,rb = r,g,b
  end
  return rr,rg,rb
end

local function get_round_rect(width,height,bg)
  local img2 = cairo.ImageSurface(cairo.Format.ARGB32, width,height)
  local cr2 = cairo.Context(img2)
  cr2:set_source_rgba(0,0,0,0)
  cr2:paint()
  cr2:set_source(bg)
  cr2:arc(rad,rad,rad,0,2*math.pi)
  cr2:arc(width-rad,rad,rad,0,2*math.pi)
  cr2:arc(rad  ,height-rad,rad,0,2*math.pi)
  cr2:fill()
  cr2:arc(width-rad,height-rad,rad,0,2*math.pi)
  cr2:rectangle(rad,0,width-2*rad,height)
  cr2:rectangle(0,rad,rad,height-2*rad)
  cr2:rectangle(width-rad,rad,rad,height-2*rad)
  cr2:fill()
  return img2
end

local margin = 15
local function create_arrow(cr,x,y,width, height,direction)
  cr:save()
  cr:translate(x,y)
  if direction then
    cr:translate(width,height)
    cr:rotate(math.pi)
  end
  cr:move_to(x,y)
  local r,g,b = get_rgb()
  cr:set_source_rgba(r,g,b,0.15)
  cr:set_antialias(1)
  cr:rectangle(2*margin,2*(height/7),width/3,3*(height/7))
  cr:fill()
  cr:move_to(2*margin+width/3,(height/7))
  cr:line_to(width-2*margin,height/2)
  cr:line_to(2*margin+width/3,6*(height/7))
  cr:line_to(2*margin+width/3,(height/7))
  cr:close_path()
  cr:fill()
  cr:restore()
end

local pango_l = nil
local function draw_shape(s,collection,current_idx,icon_f,y)
  local geo = capi.screen[s].geometry
  local wa  =capi.screen[s].workarea

  --Compute thumb dimensions
  local margins = 2*20 + (#collection-1)*20
  local width = (geo.width - margins) / #collection
  local ratio = geo.height/geo.width
  local height = width*ratio
  local dx = 20

  -- Do not let the thumb get too big
  if height > 150 then
    height = 150
    width = 150 * (1.0/ratio)
    dx = (wa.width-margins-(#collection*width))/2 + 20
  end

  -- Resize the wibox
  w.x,w.y,w.width,w.height = geo.x,y or (wa.y+wa.height) - margin - height,geo.width,height

  local img = cairo.ImageSurface(cairo.Format.ARGB32, geo.width,geo.height)
  local img3 = cairo.ImageSurface(cairo.Format.ARGB32, geo.width,geo.height)
  local cr = cairo.Context(img)
  local cr3 = cairo.Context(img3)
  cr:set_source_rgba(0,0,0,0)
  cr:paint()

  local white,bg = color("#FFFFFF"),color(beautiful.menu_bg_normal or beautiful.bg_normal)
  local img2 = get_round_rect(width,height,white)
  local img4 = get_round_rect(width-6,height-6,bg)

  if not pango_l then
    local pango_crx = pangocairo.font_map_get_default():create_context()
    pango_l = pango.Layout.new(pango_crx)
    pango_l:set_font_description(beautiful.get_font(font))
    pango_l:set_alignment("CENTER")
    pango_l:set_wrap("CHAR")
  end

  local nornal,focus = color(beautiful.fg_normal),color(beautiful.bg_urgent)
  for k,v in ipairs(collection) do
    -- Shape bounding
    cr:set_source_surface(img2,dx,0)
    cr:paint()

    -- Borders
    cr3:set_source(k==current_idx and focus or nornal)
    cr3:rectangle(dx,0,width,height)
    cr3:fill()
    cr3:set_source_surface(img4,dx+3,3)
    cr3:paint()

    -- Print the icon
    local icon = icon_f(v)
    if icon then
      cr3:save()
      local w,h = icon:get_width(),icon:get_height()
      local aspect,aspect_h = width / w,(height-50) / h
      if aspect > aspect_h then aspect = aspect_h end
      cr3:translate(dx+width/2,(height-50)/2)
      cr3:scale(aspect, aspect)
      cr3:set_source_surface(icon,-w/2,-h/2)
      cr3:paint_with_alpha(0.7)
      cr3:restore()
    end

    -- Print a pretty line
    local r,g,b = get_rgb()
    cr3:set_source_rgba(r,g,b,0.7)
    cr3:set_line_width(1)
    cr3:move_to(dx+margin,height - 47)
    cr3:line_to(dx+margin+width-2*margin,height - 47)
    cr3:stroke()

    -- Pring the text
    pango_l.text = v.name
    pango_l.width = pango.units_from_double(width-16)
    pango_l.height = pango.units_from_double(height-40)
    cr3:move_to(dx+8,height-40)
    cr3:show_layout(pango_l)

    -- Draw an arrow
    if k == current_idx-1 then
      create_arrow(cr3,dx,0,width,height,1)
    elseif k == current_idx+1 then
      create_arrow(cr3,dx,0,width,height,nil)
    end

    dx = dx + width + 20
  end

  w:set_bg(cairo.Pattern.create_for_surface(img3))
  w.shape_bounding = img._native
  w.visible = true
end

function module.hide()
  w.visible = false
end

--Client related
local function client_icon(c)
  return surface(c.icon)
end

function module.display_clients(s,direction)
  if not w then
    init()
  end
  if direction then
    awful.client.focus.byidx(direction == "right" and 1 or -1)
    capi.client.focus:raise()
  end
  local clients = awful.client.tiled(s)
  local fk = awful.util.table.hasitem(clients,capi.client.focus)
  draw_shape(s,clients,fk,client_icon)
end

function module.change_focus(mod,key,event,direction,is_swap,is_max)
  awful.client.focus.byidx(direction == "right" and 1 or -1)
  local c = capi.client.focus
  local s = c.screen
  c:raise()
  local clients = awful.client.tiled(s)
  local fk = awful.util.table.hasitem(clients,c)
  draw_shape(s,clients,fk,client_icon)
  return true
end

--Tag related
local function tag_icon(t)
  return surface(awful.tag.geticon(t))
end

local tmp_screen = nil
function module.display_tags(s,direction)
  if not w then
    init()
  end
  tmp_screen = s
  if direction then
    awful.tag[direction == "left" and "viewprev" or "viewnext"](s)
  end
  local tags = awful.tag.gettags(s)
  local fk = awful.util.table.hasitem(tags,awful.tag.selected(s))
  draw_shape(s,tags,fk,tag_icon,capi.screen[s].workarea.y + 15)
end

function module.change_tag(mod,key,event,direction,is_swap,is_max)
  local s = tmp_screen or capi.client.focus.screen
  awful.tag[direction == "left" and "viewprev" or "viewnext"](s)
  local tags = awful.tag.gettags(s)
  local fk = awful.util.table.hasitem(tags,awful.tag.selected(s))
  draw_shape(s,tags,fk,tag_icon,capi.screen[s].workarea.y + 15)
  return true
end

return module
-- kate: space-indent on; indent-width 2; replace-tabs on;