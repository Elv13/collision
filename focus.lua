local capi = { client = client , mouse      = mouse     ,
               screen = screen , keygrabber = keygrabber,}

local setmetatable = setmetatable
local ipairs       = ipairs
local util         = require( "awful.util"   )
local client       = require( "awful.client" )
local alayout      = require( "awful.layout" )
local wibox        = require( "wibox"        )
local cairo        = require( "lgi"          ).cairo
local beautiful    = require( "beautiful"    )
local color        = require( "gears.color"  )

local module = {}
local wiboxes,delta = nil,100

---------------- Visual -----------------------
local function gen(item_height)
  local img = cairo.ImageSurface(cairo.Format.ARGB32, item_height,item_height)
  local cr = cairo.Context(img)
  local rad = 10
  cr:set_source_rgba(0,0,0,0)
  cr:paint()
  cr:set_source_rgba(1,1,1,1)
  cr:arc(rad,rad,rad,0,2*math.pi)
  cr:arc(item_height-rad,rad,rad,0,2*math.pi)
  cr:arc(rad,item_height-rad,rad,0,2*math.pi)
  cr:arc(item_height-rad,item_height-rad,rad,0,2*math.pi)
  cr:fill()
  cr:rectangle(0,rad, item_height, item_height-2*rad)
  cr:rectangle(rad,0, item_height-2*rad, item_height)
  cr:fill()
  return img._native
end

local function constructor(width)
  local img = cairo.ImageSurface(cairo.Format.ARGB32, width, width)
  local cr = cairo.Context(img)
  cr:move_to(0,0)
  cr:set_source(color(beautiful.fg_normal))
  cr:paint()
  cr:set_source(color(beautiful.bg_normal))
  cr:set_antialias(1)
  cr:rectangle(0, (width/2), 10, (width/2))
  cr:rectangle(width-10, (width/2), 10, (width/2))
  for i=0,(width/2) do
    cr:rectangle(i, 0, 1, (width/2)-i)
    cr:rectangle(width-i, 0, 1, (width/2)-i)
  end
  cr:fill()
  return cairo.Pattern.create_for_surface(img)
end

local function init()
  local bounding,arrow = gen(75),constructor(55)
  wiboxes = {}
  for k,v in ipairs({"up","right","down","left","center"}) do
    wiboxes[v] = wibox({})
    wiboxes[v].height = 75
    wiboxes[v].width  = 75
    wiboxes[v].ontop  = true
    if v ~= "center" then
      local ib,m = wibox.widget.imagebox(),wibox.layout.margin()
      local img = cairo.ImageSurface(cairo.Format.ARGB32, 55, 55)
      local cr = cairo.Context(img)
      cr:translate(55/2,55/2)
      cr:rotate((k-1)*(2*math.pi)/4)
      cr:translate(-(55/2),-(55/2))
      cr:set_source(arrow)
      cr:paint()
      ib:set_image(img)
      m:set_margins(10)
      m:set_widget(ib)
      wiboxes[v]:set_widget(m)
      wiboxes[v].shape_bounding = bounding
    end
  end
  wiboxes["center"]:set_bg(beautiful.bg_urgent)
  local img = cairo.ImageSurface(cairo.Format.ARGB32, 75,75)
  local cr = cairo.Context(img)
  cr:set_source_rgba(0,0,0,0)
  cr:paint()
  cr:set_source_rgba(1,1,1,1)
  cr:arc( 75/2,75/2,75/2,0,2*math.pi  )
  cr:fill()
  wiboxes["center"].shape_bounding = img._native
end

local function display_wiboxes(cltbl,geomtbl,float,swap,c)
  if not wiboxes then
    init()
  end
  for k,v in ipairs({"left","right","up","down","center"}) do
    local next_clients = (not (float and swap)) and cltbl[util.get_rectangle_in_direction(v , geomtbl, capi.client.focus:geometry())] or c
    if next_clients or k==5 then
      local same, center = capi.client.focus == next_clients,k==5
      local geo = center and capi.client.focus:geometry() or next_clients:geometry()
      wiboxes[v].visible = true
      wiboxes[v].x = (swap and float and (not center)) and (geo.x + (k>2 and (geo.width/2) or 0) + (k==2 and geo.width or 0) - 75/2) or (geo.x + geo.width/2 - 75/2)
      wiboxes[v].y = (swap and float and (not center)) and (geo.y + (k<=2 and geo.height/2 or 0) + (k==4 and geo.height or 0) - 75/2) or (geo.y + geo.height/2 - 75/2)
    else
      wiboxes[v].visible = false
    end
  end
end

---------------- Position -----------------------
local function float_move(dir,c)
  return ({left={x=c:geometry().x-delta},right={x=c:geometry().x+delta},up={y=c:geometry().y-delta},down={y=c:geometry().y+delta}})[dir]
end

local function float_move_max(dir,c)
  return ({left={x=capi.screen[c.screen].workarea.x},right={x=capi.screen[c.screen].workarea.width+capi.screen[c.screen].workarea.x-c:geometry().width}
      ,up={y=capi.screen[c.screen].workarea.y},down={y=capi.screen[c.screen].workarea.y+capi.screen[c.screen].workarea.height-c:geometry().height}})[dir]
end

local function floating_clients()
  local ret = {}
  for v in util.table.iterate(client.visible(),function(c) return client.floating.get(c) end) do
    ret[#ret+1] = v
  end
  return ret
end

local function bydirection(dir, c, swap,max)
  if c then
    local float = client.floating.get(c) or alayout.get(c.screen) == alayout.suit.floating
    -- Move the client if floating, swaping wont work anyway
    if swap and float then
      c:geometry((max and float_move_max or float_move)(dir,c))
      display_wiboxes(nil,nil,float,swap,c)
    else
      -- Get all clients rectangle
      local cltbl,geomtbl = max and floating_clients() or client.tiled(),{}
      for i,cl in ipairs(cltbl) do
        geomtbl[i] = cl:geometry()
      end
      local target = util.get_rectangle_in_direction(dir, geomtbl, c:geometry())
      -- If we found a client to focus, then do it.
      if target then
        if swap ~= true then
          capi.client.focus = cltbl[((not cltbl[target] and #cltbl == 1) and 1 or target)]
          capi.client.focus:raise()
        else
          c:swap(cltbl[target])
        end
        display_wiboxes(cltbl,geomtbl,float,swap,c)
      end
    end
  end
end

function module.global_bydirection(dir, c,swap,max)
  bydirection(dir, c or capi.client.focus, swap,max)
end

function module._global_bydirection_key(mod,key,event,direction,is_swap,is_max)
  bydirection(direction,capi.client.focus,is_swap,is_max)
  return true
end

function module.display(mod,key,event,direction,is_swap,is_max)
  local c = capi.client.focus
  local cltbl,geomtbl = max and floating_clients() or client.tiled(),{}
  for i,cl in ipairs(cltbl) do
    geomtbl[i] = cl:geometry()
  end
  display_wiboxes(cltbl,geomtbl,client.floating.get(c) or alayout.get(c.screen) == alayout.suit.floating,is_swap,c)
end

function module._quit()
  for k,v in ipairs({"left","right","up","down","center"}) do
    wiboxes[v].visible = false
  end
end

return setmetatable(module, { __call = function(_, ...) return new(...) end })
-- kate: space-indent on; indent-width 2; replace-tabs on;