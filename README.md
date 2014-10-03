Collision window navigation module for AwesomeWM
================================================

This module add some visual indicators for common window management operations.
It is now easier to know the impact of a given command as a visual queue will
be printed on the screen. Collision has 3 modes:

* **Focus**: Move the focus from client to client
* **Move**: Move a client
* **Resize**: Change a client dimensions
* **Tag**: Move to the previous/next tag

# Installation

First, clone the repository

```lua
    mkdir -p ~/.config/awesome
    cd ~/.config/awesome
    git clone https://github.com/Elv13/collision
```

Now, open ~/.config/awesome/rc.lua (or copy /etc/xdg/awesome/rc.lua to 
~/.config/awesome/rc.lua fist if you never modified your Awesome config before)
 and add this line at the **end** of rc.lua:

```lua
    require("collision")()
```

It is a very good idea to also change the default `mod4+arrow` shortcut to
something else:

```lua
    --Change
    awful.key({ modkey,           }, "Left",   awful.tag.viewprev       ),
    awful.key({ modkey,           }, "Right",  awful.tag.viewnext       ),

    --To:
    --awful.key({ modkey,           }, "Left",   awful.tag.viewprev       ),
    --awful.key({ modkey,           }, "Right",  awful.tag.viewnext       ),
```

Your done!

# Usage

Using Collision is easy. You just have to hit the arrow keys (`➡` `⬆` `⬇` `⬅`)
with some modifiers keys. The `Shift` key is usually used for grabbing something
while the `Control` key is used to max out the effect.

| Modifier 1 | Modifier 2   | Modifier 3 | Effect                                                |
| :--------: | :----------: | :--------: | ----------------------------------------------------- |
| `Mod4`     |              |            | Move the focus om the tiled layer                     |
| `Mod4`     |              | `Control`  | Move the focus on the floating layer                  |
| `Mod4`     | `Shift`      |            | Move a client in the tiled or floating layer          |
| `Mod4`     | `Shift`      | `Control`  | Move a floating client to the far side of that screen |
| `Mod4`     | `Mod1 (Alt)` |            | Resize a client relative to the bottom right corner   |
| `Mod4`     | `Mod1 (Alt)` | `Shift`    | Resize a client relative to the top left corner       |
| `Control`  | `Mod1 (Alt)` |            | Move to the next/previous tag                         |

# Using different keys

Due to the large ammount of keyboard shortcut Collision create, they are
auto-generated automatically. While this make installation simpler, it also
make Collision somewhat hard-coded magic. Some alternative keymaps can also
be ackward to use because of the reliance on mod keys such as `Alt` and `Control`.

That being said, Collision allow some basic remapping. Instead of:

```lua
    require("collision")()
```

This can be used:

```lua
    require("collision") {
        --        Normal    Xephyr       Vim      G510
        up    = { "Up"    , "&"        , "k"   , "F15" },
        down  = { "Down"  , "KP_Enter" , "j"   , "F14" },
        left  = { "Left"  , "#"        , "h"   , "F13" },
        right = { "Right" , "\""       , "l"   , "F17" },
    }
```

Of course, if the `Vim` keys are used, any other shortcut binded to them have to
be removed from rc.lua.
