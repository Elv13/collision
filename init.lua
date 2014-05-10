local capi = { client = client, mouse     = mouse      ,
               screen = screen, keygrabber = keygrabber}
local util         = require( "awful.util"   )
local module = {
  _focus  = require( "customIndicator.focus" ),
  _resize = require( "customIndicator.resize")
}

local current_mode = "focus"

local event_callback = {
  focus  = module._focus._global_bydirection_key,
  move   = module._focus._global_bydirection_key,
  resize = module._resize.resize
}

local exit_callback = {
  focus  = module._focus._quit,
  move   = module._focus._quit,
  resize = module._resize.hide
}

local keys = {--Normal  Xephyr        G510 alt         G510
  up    = {"Up"    , "&"        , "XF86AudioPause" , "F15" },
  down  = {"Down"  , "KP_Enter" , "XF86WebCam"     , "F14" },
  left  = {"Left"  , "#"        , "Cancel"         , "F13" },
  right = {"Right" , "\""       , "XF86Paste"      , "F17" }
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
    end

    return exit_loop()
  end)
end

function module.focus(direction,c,max)
    current_mode = "focus"
    module._focus.global_bydirection(direction,c,false)
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

return module
-- kate: space-indent on; indent-width 2; replace-tabs on;