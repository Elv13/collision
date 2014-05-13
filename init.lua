local capi = { root = root, client     = client      ,
               screen = screen, keygrabber = keygrabber}
local util         = require( "awful.util" )
local awful        = require( "awful"      )
local module = {
  _focus  = require( "customIndicator.focus" ),
  _resize = require( "customIndicator.resize"),
  _max    = require( "customIndicator.max"   ),
}

local current_mode = "focus"

local event_callback = {
  focus  = module._focus._global_bydirection_key,
  move   = module._focus._global_bydirection_key,
  resize = module._resize.resize
}

local start_callback = {
  focus  = module._focus.display,
  move   = module._focus.display,
  resize = module._resize.display
}

local exit_callback = {
  focus  = module._focus._quit,
  move   = module._focus._quit,
  resize = module._resize.hide
}

local keys = {--Normal  Xephyr        G510 alt         G510
  up    = {"Up"    --[[, "&"        , "XF86AudioPause" , "F15"]] },
  down  = {"Down"  --[[, "KP_Enter" , "XF86WebCam"     , "F14"]] },
  left  = {"Left"  --[[, "#"        , "Cancel"         , "F13"]] },
  right = {"Right" --[[, "\""       , "XF86Paste"      , "F17"]] }
}

local function exit_loop()
  exit_callback[current_mode]()
  capi.keygrabber.stop()
  return false
end

-- Event loop
local function start_loop(is_swap,is_max)
  capi.keygrabber.run(function(mod, key, event)
    -- Detect the direction
    for k,v in pairs(keys) do
      if util.table.hasitem(v,key) then
        if event == "press" then
          if not event_callback[current_mode](mod,key,event,k,is_swap,is_max) then
            return exit_loop()
          end
          return
        end
        return true
      end
    end

    if key == "Shift_L" or key == "Shift_R" then
      is_swap = event == "press"
      return true
    elseif key == "Control_L" or key == "Control_R" then
      is_max = event == "press"
      return true
    elseif key == "Alt_L" or key == "Alt_R" then
      exit_callback[current_mode]()
      current_mode = event == "press" and "resize" or "focus"
      start_callback[current_mode](mod,key,event,k,is_swap,is_max)
      return true
    end

    return exit_loop()
  end)
end

function module.focus(direction,c,max)
    current_mode = "focus"
    local screen = (c or capi.client.focus).screen
    if awful.layout.get((c or capi.client.focus).screen) == awful.layout.suit.max then
      module._max.display_clients(screen)
    else
      module._focus.global_bydirection(direction,c,false,true)
    end
    start_loop(false,max)
end

function module.move(direction,c,max)
    current_mode = "move"
    module._focus.global_bydirection(direction,c,true)
    start_loop(true,max)
end

function module.resize(direction,c,max)
    current_mode = "resize"
    start_loop(false,max)
    module._resize.display(c)
end

function module.mouse_resize(c)
    
end

local function new(k)
  local k = k or keys
  local aw = {}

  for k,v in pairs(keys) do
    for _,key_nane in ipairs(v) do
      aw[#aw+1] = awful.key({ modkey,                    }, key_nane, function () module.focus (k         ) end)
      aw[#aw+1] = awful.key({ modkey, "Mod1"             }, key_nane, function () module.resize(k         ) end)
      aw[#aw+1] = awful.key({ modkey, "Shift"            }, key_nane, function () module.move  (k         ) end)
      aw[#aw+1] = awful.key({ modkey, "Shift", "Control" }, key_nane, function () module.move  (k,nil,true) end)
      aw[#aw+1] = awful.key({ modkey,          "Control" }, key_nane, function () module.focus (k,nil,true) end)
    end
  end
  capi.root.keys(awful.util.table.join(capi.root.keys(),unpack(aw)))
end

return setmetatable(module, { __call = function(_, ...) return new(...) end })
-- kate: space-indent on; indent-width 2; replace-tabs on;