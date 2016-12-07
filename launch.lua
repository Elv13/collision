local awful = require("awful")

local launcherw = require("collision.widgets.launchbar")

local module = {}

local session = nil

local function detect_tag_hooks(key, command)
    if session and session.tags_by_id[key] then
        session.mode = "tag"
        session.tag = session.tags_by_id[key]
        session.wiboxes.tags:highlight(key,true)
        return true, nil, "<b>Open on tag:</b>"
    end
end

local function clear(result)
    if session then
        if session.wiboxes.generic then
            session.wiboxes.generic.visible = false
        end
        if session.wiboxes.tags then
            session.wiboxes.tags.visible = false
        end
    end
    mypromptbox[mouse.screen].widget:set_text(type(result) == "string" and result or "")
end

local hooks = {
    {{         },"Return",function(command)
        clear(awful.spawn(command, {
            tag = session.tag
        }))
    end},
    {{"Mod1"   },"Return",function(command)
        clear(awful.spawn(command,{
            intrusive = true,
            tag       = mouse.screen.selected_tag
        }))
    end},
    {{"Shift"  },"Return",function(command)
        clear(awful.spawn(command,{
            intrusive = true,
            ontop     = true,
            floating  = true,
            tag       = mouse.screen.selected_tag
        }))
    end},
    {{"Control"},"Return",function(command)
        clear(awful.spawn(command,{
            new_tag=true
        }))
    end},
    {{         },"Escape",function(command)
        clear()
    end},
}

local function highlight(name, value)
    if not session then return end
    local w = session.widgets[name]
    w[value and "highlight" or "unhighlight"](w)
end

local modifiers_press = {
    Control_L = function() highlight("new_tag",true) end,
    Shift_L   = function() highlight("float"  ,true) end,
    Super_L   = function() end,
    Alt_L     = function()
        if session and session.wiboxes.tags then
            session.wiboxes.tags.visible = true
        end
        highlight("cur_tag",true)
    end,
}

local modifiers_release = {
    Control_L = function() highlight("new_tag",false) end,
    Shift_L   = function() highlight("float"  ,false) end,
    Super_L   = function() end,
    Alt_L     = function()
        if session and session.wiboxes.tags and not session.tag then
            session.wiboxes.tags.visible = false
        end
        highlight("cur_tag",false)
    end,
}

local function keypressed_callback(mod, key, command)
    if modifiers_press[key] then
        modifiers_press[key]()
    end
    if mod["Mod1"] then
        return detect_tag_hooks(key, command)
    end
end

local function keyreleased_callback(mod, key, command)
    if modifiers_release[key] then
        modifiers_release[key]()
    end
end

local function exe_callback(com)
    local result = awful.spawn(com)
    if type(result) == "string" then
        mypromptbox[mouse.screen].widget:set_text(result)
    end

    -- Hide the wiboxes
    clear()

    return true
end

-- Start the launcher
function module.launch()
    -- Show all the hints
    session = launcherw(mouse.screen)

    awful.prompt.run {
        prompt               = "<b>Run: </b>",
        hooks                = hooks,
        textbox              = mypromptbox[mouse.screen].widget,
        history_path         = awful.util.getdir("cache") .. "/history",
        keypressed_callback  = keypressed_callback,
        keyreleased_callback = keyreleased_callback,
        done_callback        = clear,
        completion_callback  = awful.completion.shell,
        exe_callback         = exe_callback,
    }
end

return setmetatable(module, {__call = function(_, ...) return module.launch(...) end})
