--

local obj={}
obj.__index = obj

-- metadata

obj.name = "workspaces"
obj.version = "0.1"
obj.author = "dmg <dmg@turingmachine.org>"
obj.homepage = "https://github.com/dmgerman/hs_select_window.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

obj.winFilter = nil

obj.currentWS = nil
obj.winDims = {}
obj.winSticky = {}
-- implement some sets

obj.storeAreaMargin_x = 10
-- TODO: this has to be set to slightly larger than the size of the bar...
obj.storeAreaMargin_y = 80

obj.workspaces = {
  "1",
  "2",
  "3",
  "4",
  "5",
  "6"
}

obj.wsSpaces = {}
obj.wsWindows = {}

obj.appsDefaultWspace = {
  ["org.gnu.Emacs"] = "3",
  ["com.bambulab.bambu-studio"] = "4"
}

obj.appsSticky = {
  ["com.apple.systempreferences"]=true,
  ["org.hammerspoon.Hammerspoon"]=true,
}

obj.storeArea = nil

obj.menuBar = nil

------------------------------------------------

function obj:dict_new(t)
  local dict = {}
  for _, l in ipairs(t) do
    dict[l] = t[l] or true
  end
  return dict
end

function obj:dict_set(dict, key, val)
  -- we only allow non-false values

  assert(type(dict) == "table", "Dictionary is invalid")
  assert(key ~= nil, "key to insert in dictionary is nil")
  assert(val ~= nil, "use dict_remove, not dict_set, not set", hs.inspect(val))

  dict[key] = val or true

  return dict
end

function obj:dict_get(dict,key)
  assert(type(dict) == "table", "Dictionary is invalid")
  assert(key ~= nil, "key to search in dictionary is nil")

  return dict[key]
end

function obj:dict_remove(dict, key)
  assert(type(dict) == "table", "Dictionary is invalid")
  
  dict[key] = nil
  return dict
end

function obj:dict_in(dict, key)
  -- we don't allow nil values
  -- in the dictionary
  return dict[key] 
end


function obj:window_default_ws(win)
  assert(obj:is_window(win), "invalid window parameter ")
  return obj:dict_get(obj.appsDefaultWspace, win:application():bundleID()) or
    obj.currentWS
end

-------------------------------------------------------------

function obj:ws_len()
  -- return index of workspace
  return #(obj.workspaces)
end

function obj:default_workspace()
  assert(obj.ws_len() > 0, "workspaces is empty")

  return obj.workspaces[1]
end


function obj:ws_index(ws)
  -- return index of workspace
  assert(obj:is_ws(ws), "invalid name for workspace "..ws )
  assert(obj.ws_len() > 0, "workspaces is empty")

  for i,v in ipairs(obj.workspaces) do
    if v == ws then
      return i
    end
  end
  return nil
end


function obj:ws_next(ws)
  assert(#(obj.workspaces) > 0, "workspaces is empty")
  local i = ws_index(ws)
  assert(i>0, "worskpace does not exist")
  
  return (i+1)%(obj.ws_len)
end

function obj:ws_prev(ws)
  assert(#(obj.workspaces) > 0, "workspaces is empty")
  local i = ws_index(ws)
  assert(i>0, "worskpace does not exist")
  
  return (i-1)%(obj.ws_len)
end

function obj:menuBar_update()

  assert(obj.menuBar, "menubar not created yet")

  obj.menuBar:setTitle(obj.currentWS)

--  print("------------------->>>>>>>>>>>>>>>>>>>>>>>>>")
--  print(hs.inspect(obj.wsSpaces))
--  print("------------------->>>>>>>>>>>>>>>>>>>>>>>>>")

  local items = {}
  for _, ws in ipairs(obj.workspaces) do
    local wsTable = obj:ws_get_windows_table(ws)
    local size = (wsTable and obj:table_len(wsTable)) or 0

    table.insert(items, {title = string.format("%s (%d)", ws, size),
        fn = function() obj:ws_goto(ws) end})
    if size > 0 then
      for wid, _ in pairs(wsTable) do
        local win = hs.window(wid)
        if win then
          table.insert(items, {title = string.format("   %s:%s", win:title(), win:application():name()),
              fn = function()
                obj:ws_goto(ws)
                win:focus()
          end})
        else
          print("did not really exist", wid, hs.inspect(wsTable))
        end
      end
    end
  end
  table.insert(items, {title = "Sticky windows"})
  for i,win in ipairs(hs.window.orderedWindows()) do
    if not obj:window_is_managed(win) and
      obj:window_in_managed_screen(win) and
      win:isStandard()
    then
--      print("*******************************************************************", hs.inspect(win))
--      print("Display: ", win:screen(), hs.screen.primaryScreen())
--      print("frame: ", hs.inspect(win:frame()))
--      print("Stadnard", win:isStandard())
      table.insert(items, {title = string.format("   %s:%s", win:title(), win:application():name()),
          fn = function()
            win:focus()
      end})
    end
  end

  obj.menuBar:setMenu(items)
end


function obj:menuBar_init()
  obj.menuBar = hs.menubar.new(true)
  obj:menuBar_update()
end

function obj:store_area_set()
  local fr = hs.screen.primaryScreen():frame()
  obj.storeArea = hs.geometry(fr.x2-obj.storeAreaMargin_x, fr.y2-obj.storeAreaMargin_y)
end

function obj:is_window(w)
  -- must be number, and it should return valid window
  --  return type(w) == "number" and hs.window.get(w)
  return type(w) == "userdata" and w.application
end

function obj:is_ws(ws)
  return type(ws)== "string" and string.len(ws) > 0
end




function obj:debug_window(win, st)
  assert(obj:is_window(win), "invalid window parameter ")
  if st then
    print("\n")
    print(st)
  end
  print("Window: ", win)
  print("      Managed:", obj:window_is_managed(win))
  print("   App:       ", win:application():bundleID())
  print("    screen    ", obj:window_in_managed_screen(win))
  print("cur screen    ", win:screen())
  print("    ws:       ", obj:window_get_ws(win))
  print("    hidden:   ", obj:win_is_hidden(win))
  print("    fr:       ", obj:win_dimensions_get(win))
  print(" curfr:       ", win:frame())
  print("    in screen:", obj:win_in_screen(win))
  print("")
end

function obj:debug_wid(wid, st)
  print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>", hs.inspect(wid), type(wid))
  assert(type(wid) == "number", "invalid wid parameter ")
  if st then
    print("\n")
    print(st)
  end
  win = hs.window(wid)
  print("Window id: ", wid, win)
  if win then
    obj:debug_window(win)
  else
    print("        Window no longer exists")
    print(hs.inspect( obj:dict_get(obj.wsWindows, wid)))
    print("")
  end
end



function obj:debug_windows(st)
  print("\n")
  print(st)
  for wid,v in pairs(obj.wsWindows) do
    win = hs.window(wid)
    print(win, hs.inspect(v))
    if win then
      obj:debug_window(win,nil)
    else
      print("LLLLLLLLLLLLLLLL window does not exist")
      obj:debug_wid(wid, nil)
    end
  end
end

function obj:window_get_sticky(win)
  assert(obj:is_window(win), "invalid window parameter " )
  return obj.winSticky[win:id()]
end

function obj:window_is_sticky(win)
  assert(obj:is_window(win), "invalid window parameter ")

  assert(win ~= nil, "No window provided")
  local app = win:application()

  return obj:dict_in(obj.appsSticky, app:bundleID()) 
    or obj:window_get_sticky(win)
end

function obj:window_set_sticky(win, st)
  assert(obj:is_window(win), "invalid window parameter " )
  assert(type(st)=="boolean", "invalid boolean value to stickyness")

  if not st then
    -- this will remove the entry
    st = nil
  end
  obj.winSticky[win:id()] = nil
  return win
end

function obj:window_in_managed_screen(win)
  assert(obj:is_window(win), "invalid window parameter ")
  return win:screen() == hs.screen.primaryScreen()
end

function obj:window_is_managed(win)
  assert(obj:is_window(win), "invalid window parameter ")
  return obj:window_get_ws(win) ~= nil
end


function obj:window_ignore(win)
  -- ignorable windows 
  assert(obj:is_window(win), "invalid window parameter ")

  return (not obj:window_in_managed_screen(win))
    or win:isFullScreen()
    or win:isMinimized()
    or (not win:isMaximizable())
    or obj:window_is_sticky(win) 
end


function obj:window_get_ws(win)
  assert(obj:is_window(win), "invalid window parameter " )
  local result = obj:dict_get(obj.wsWindows, win:id())
  if result then
    return result["ws"]
  else
    return nil
  end
end

function obj:window_set_ws(win, ws)
  assert(obj:is_window(win), "invalid window parameter " )
  assert(obj:is_ws(ws), "invalid ws parameter")
  
  if obj:window_get_ws(win) == ws then
    -- already set, 
    return 
  end

  obj:dict_set(obj.wsWindows, win:id(),
    {["title"] = win:title(),
      ["ws"]= ws,
      ["app"] = win:application(),
      ["sticky"] = false
    }
  )
end

function obj:window_remove_ws(win)
  assert(obj:is_window(win), "invalid window parameter " )
    
  obj:dict_remove(obj.wsWindows, win:id())
end


function obj:ws_get_windows_table(ws)
  assert(obj:is_ws(ws), "invalid name for workspace "..ws )

--  print("ws:", ws)
--  print("    ", hs.inspect(obj.wsSpaces))

  return obj:dict_get(obj.wsSpaces, ws)
end

function obj:ws_add_window(ws, win)
  assert(obj:is_ws(ws), "invalid name for workspace "..ws )
  assert(obj:is_window(win), "invalid window parameter " )

  local wsDict = obj:ws_get_windows_table(ws)

  if not wsDict then
    wsDict = {}
    obj:dict_set(obj.wsSpaces, ws, wsDict) 
  end

  assert(wsDict)

  obj:dict_set(wsDict, win:id(), true)

end

function obj:ws_remove_window(win)
  -- find the ws of the window
  assert(obj:is_window(win), "invalid window parameter ")
  -- remove from spaces
  
  local ws = obj:window_get_ws(win)
  assert(ws, "no workspace found for this window, it was not managed" .. hs.inspect(win))

  local wsDict = ws and obj:ws_get_windows_table(ws)
  -- remove from workspace
  if wsDict then
    obj:dict_remove(wsDict, win:id())
  end
end

function obj:frame_in_store_area(fr)
  local result = fr.x == obj.storeArea.x and fr.y == obj.storeArea.y

  --  print("\nStorage\n", win,result,"\n", hs.inspect(fr),"\n", hs.inspect(obj.storeArea))

  --  print("******             STORAGE <<<: ", result)
  return result
end

function obj:win_in_store_area(win)
  assert(obj:is_window(win), "invalid window parameter " )
--  print("******             STORAGE ****")
  return obj:frame_in_store_area(win:frame())

end

function obj:win_is_hidden(win)
  assert(obj:is_window(win), "invalid parameter, should be a window")

  return obj:win_in_store_area(win)
end


function obj:win_in_screen(win)
  assert(obj:is_window(win), "invalid window parameter " )

--  print("window in frame of screen: ", win)
  
  if obj:win_in_store_area(win) then
--    print("Window is in store area!!")
    return false
  end

  local result = win:screen() == hs.screen.primaryScreen()
  return result
end

function obj:win_dimensions_unset(win)
  assert(obj:is_window(win), "invalid parameter, should be a window")

  obj:dict_remove(obj.winDims, win:id())
end

function obj:win_dimensions_save(win)
  assert(obj:is_window(win), "invalid parameter, should be a window")
  
  obj:debug_window(win, "  >> save dimensions ")

  local fr = nil
  if not obj:win_in_store_area(win) then
    fr = win:frame()
  end

  if fr then
    obj:dict_set(obj.winDims, win:id(), fr)
  else
    obj:dict_remove(obj.winDims, win:id())
  end

  obj:debug_window(win, "  << save dimensions ")
  return fr
end

function obj:win_dimensions_get(win)
  assert(obj:is_window(win), "invalid parameter, should be a window")

  return obj:dict_get(obj.winDims, win:id())
end
  
function obj:windows_get_all()
  -- return all managed windows and their worskpace
  return obj.wsWindows
end

function obj:ws_insert_window(ws, win)
  -- we need to insert it in the windows  and into the workspace
  assert(obj:is_ws(ws),      "invalid name for workspace " .. hs.inspect(ws) )
  assert(obj:is_window(win), "invalid window parameter " )

  obj:ws_add_window(ws, win)
  obj:window_set_ws(win, ws)
end

function obj:window_move_to_ws(win, ws)
  assert(type(ws)== "string" and string.len(ws) > 0, "invalid name for workspace in window_move_to_ws ")
  assert(obj:is_window(win), "invalid window parameter ")

  if obj:window_ignore(win) then
    hs.alert("Request to move window ignored")
    return win
  end
  if obj:window_get_ws(win) == ws then
    -- already in current space
    hs.alert("Window already in destination workspace")
    return win
  end

  obj:ws_remove_window(win)

  obj:ws_insert_window(ws, win)

  obj:window_set_ws(win, ws)

  return win
end


function obj:manage_window(win, pws)
  assert(obj:is_window(win), "invalid window parameter ")
  assert(obj:window_get_ws(win) == nil, "Window to manage is already managed")


  if obj:window_ignore(win) then
    return nil
  end

  local defWS =  obj:window_default_ws(win) 

  local ws = pws or defWS or obj.currentWS

  obj:ws_insert_window(ws, win)
  obj:window_set_ws(win, ws)
  obj:menuBar_update()
  return win
end

function obj:forget_window(win)
  assert(obj:is_window(win), "invalid window parameter ")
  print("forget window: ", win, win:id())
  -- at this point, win might no longer be a win
  if obj:window_is_managed(win) then
    obj:ws_remove_window(win)
    obj:window_remove_ws(win)
  else
    print("Window is not managed, but requested to unmanage", win)
  end
  obj:debug_window(win, "\n\n                FORGOT window    ")
  obj:menuBar_update()
end

function obj:window_in_current_ws(win)
  assert(obj:is_window(win), "invalid window parameter ")
  return obj:window_get_ws(win) ~= obj.currentWS 
end

function obj:window_at_saved_position(win)
  assert(obj:is_window(win), "invalid window parameter ")
  assert(obj:window_is_managed(win))

  return obj:win_dimensions_get(win) == win:frame()
end

function obj:update_window_position(win)
  assert(obj:is_window(win), "invalid window parameter ")

  if obj:window_ignore(win) then
    -- don't do anything when window is ignored
    return 
  end
  if not obj:window_is_managed(win) then
    print("Window was not managed. start managing")
    obj:manage_window(win)
    return
  end
  if obj:win_is_hidden(win) then
    return
  end

  if obj:window_get_ws(win) ~= obj.currentWS then
    obj:window_set_ws(win, obj.currentWS)
  end
  obj:win_dimensions_unset(win)
  obj:debug_window(win, "Window was position updated")
  obj:menuBar_update()
end

function obj:callback_do_window_move(win)
  if obj:window_in_managed_screen(win) then
    if not obj:window_ignore(win) then

      if not obj:window_is_managed(win) then
        obj:manage_window(win)
      else
        obj:update_window_position(win)
      end
      obj:menuBar_update()
    end
  elseif obj:window_is_managed(win) then
    obj:forget_window(win)
  end
end


function callback_window(win, appName, event)
  print(string.format("WS EVENT >>>>>>>>>>>>>>>>>>> [%s]", event))

  if event == "windowDestroyed" then
    if obj:window_in_managed_screen(win) then
      obj:forget_window(win)
      obj:menuBar_update()
    end
    return
  end
   
  if event == "windowCreated" then

    if obj:window_in_managed_screen(win) then
      if obj:window_is_managed(win) then
        obj:update_window_position(win)
      else
        obj:manage_window(win)
      end
      obj:menuBar_update()
    end

    return 
  end

  if event == "windowMoved" then

    obj:callback_do_window_move(win)
    return

--    if not obj:window_ignore(win) then
--      obj:window_move_to_ws(win, obj.currentWS)
--      print("Window moved to workspace: ", obj.currentWS, win)
--    end
--    return
  end
  if event == "windowFocused" then
    if obj:window_ignore(win) then
      return 
    end
    print("window focused event for window", win)
    -- at this point the window is managed by us
    -- but either it is hidden, or it is already visible
    -- if it is visible, it is ok
    -- 
    -- if it is hidden, send us to its workspace
    --   that will take care of unhidding it
    --   and any other window in that workspace
    if obj:win_is_hidden(win) then
      -- switch to the
      local ws = obj:window_get_ws(win) or obj.currentWS
      obj:ws_goto(ws)
    end
    obj:menuBar_update()
    return 
  end
  print("EVENT NOT HANDLED>>>>>>>>>>>>>>>>>>>>", event)

end

function obj:win_filters_disable()
  print("                      -------- Filters disabled>>>")
  if obj.winFilter then
    obj.winFilter:pause()
  end
end

function obj:win_filters_enable()
  print("                      -------- Filters enabled<<<<")
  if obj.winFilter then
    obj.winFilter:resume()
  end
end





---------------------------------------------------
function obj:move_to_storage_area(win)
  assert(obj:is_window(win), "invalid parameter, should be a window")
  assert(not obj:win_is_hidden(win), "window is already in storage!!")

  -- remember, lua returns references
  local winFr = hs.geometry.copy(obj:win_dimensions_save(win))

  winFr.x = obj.storeArea.x
  winFr.y = obj.storeArea.y

  win:move(winFr)

  assert(obj:win_in_store_area(win), "Window did not move to storage area")
end

function obj:hide(win)
  assert(obj:is_window(win), "invalid parameter, should be a window")

  print("Hide: <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< ", win)

  if obj:window_ignore(win) then
    print("endHide: <<<<<<<<<<<<<<<<<<<<<<<< ignore", win)
    return
  end

  if obj:win_is_hidden(win) then
    print("endHide: <<<<<<<<<<<<<<<<<<<<<<<< hidden", win)
    print("window is already hidden")
    return
  end
  
  obj:move_to_storage_area(win)

  print("endHide: <<<<<<<<<<<<<<<<<<<<<<<<,end ", win)
end

function obj:restore(win)
  print("       RESTORE       >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>restoring", win)
  assert(obj:is_window(win), "invalid parameter, should be a window")

  -- this restores a window

  -- this function is only responsible for restoring it, not
  -- window must be hidden before this function is called

  if obj:window_ignore(win) then
    print("ENd>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>restoring, ignore", win)
    return
  end

  if not obj:win_is_hidden(win) then
    print(">>>>>>>>>>>>>>RESTORE:        window is not hidden", win, obj:win_is_hidden(win))
    print("ENd>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>restoring, not hidden", win)
    return
  end

  local frame = obj:win_dimensions_get(win) or obj:window_frame_to_primary_display(win)

  assert(frame)
  win:move(frame)

  obj:win_dimensions_unset(win)
  print("         RESTORE            ENd>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>restoring, end", win)
end


function obj:window_frame_to_primary_display(win)
  assert(obj:is_window(win), "invalid parameter, should be a window")

  -- remember, lua returns references
  local frame = hs.geometry.copy(win:frame())
  local dFr = hs.screen.primaryScreen():frame()
  frame.x = dFr.x
  frame.y = dFr.y
  return frame
end

function obj:hide_toggle(win)
  assert(obj:is_window(win), "invalid parameter, should be a window")

  if obj:window_ignore(win) then
    return
  end

  if obj:win_is_hidden(win) then
    print("restore")
    obj:restore(win)
  else
    print("hide")
    obj:hide(win)
  end
end

function obj:restore_all_windows()
  local wins = obj:windows_get_all()
  for win, ws in pairs(wins) do
    obj:restore(win)
  end
end

function obj:ws_goto(ws)

  if ws == obj.currentWS then
    return
  end

  local bt = hs.timer.localTime() 
  function delta()
    return hs.timer.localTime()  - bt
  end
  print("Workspace to move to ", ws)
  assert(obj:is_ws(ws), "invalid name for workspace ")

  print("Begin goto*******************************************----------------", ws)
  obj.currentWS = ws

  print("Starting:", delta())

  obj:win_filters_disable()
  print("Starting 1.5:", delta())
  local wins = obj:windows_get_all()
--  print("Wins:", hs.inspect(wins))
  print("Starting 2:", delta())
  for wid, wdata in pairs(wins) do
    print("Starting 3:",delta())
    local win = hs.window(wid)
    if win and (not obj:window_ignore(win))  then --and obj:win_frame_in_screen(win)
--      print("Window:", wid, ws, hs.inspect(wdata))
      local wws = wdata["ws"]
      if wws == ws then
  --      obj:debug_window(win, "+++++++in goto to restore: \n")
--        print("\n\nTo restore")
        obj:restore(win)
      else
--        obj:debug_window(win, "---------------++++in goto to hide: \n")
--        print("\n\nTo hide")
        obj:hide(win)
      end
    end
  end
  print("Starting 4:", delta())
  obj:focus_window_in_current_ws()
  obj:win_filters_enable()
  obj:menuBar_update()
  obj:ws_display()
  print("Starting 5:", delta())
  print("End goto *******************************************----------------", ws)
end

function obj:focused_window_to_ws(ws, go)
  if ws == obj.currentWS then
    hs.alert("Window already in workspace")
    return
  end
  local win = hs.window.focusedWindow()
  if win then
    obj:window_move_to_ws(win, ws)
    if go then
      obj:ws_goto(ws)
    end
  end
end

function obj:table_len(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

function obj:ws_display()
  local wins = obj:ws_get_windows_table(obj.currentWS) or {}
  hs.alert(string.format("Current workspace: %s (%d windows)", obj.currentWS, obj:table_len(wins)))
end

function obj:focus_window_in_current_ws()
  for i,win in ipairs(hs.window.orderedWindows()) do
    if (not obj:window_ignore(win)) and obj:window_is_managed(win) then
      if (obj:window_get_ws(win) == obj.currentWS) then
        print("\n\n>>>>>>>>>>>>>>>>> window to focus", win)
        win:focus()
        return
      end
    end
  end
end

function obj:initialize()
  --- some initialization
  local cWin = hs.window.focusedWindow()

  obj.currentWS = obj.default_workspace()
  obj:menuBar_init()
  obj:store_area_set()

  -- startup: give all current windows a workspace
  -- and move windows to where they belong

  for i,win in ipairs(hs.window.allWindows()) do
    obj:manage_window(win)
  end

  local destionWs = (cWin and obj:window_is_managed(cWin) and obj:window_get_ws(cWin)) or
    obj.currentWs
  
  obj:ws_goto(destionWs)

  -- set windows filter and its callback

  obj.winFilter = hs.window.filter.new()
  obj.winFilter:setDefaultFilter{}
  obj.winFilter:subscribe(hs.window.filter.windowCreated, callback_window)
  obj.winFilter:subscribe(hs.window.filter.windowDestroyed, callback_window)
  obj.winFilter:subscribe(hs.window.filter.windowFocused, callback_window)
  obj.winFilter:subscribe(hs.window.filter.windowMoved, callback_window)
  --obj.winFilter:subscribe(hs.window.filter.windowMoved, callback_window_move)

end

obj:initialize()


hs.hotkey.bind({"alt"}, "1",    function () obj:ws_goto("1") end)
hs.hotkey.bind({"alt"}, "2",    function () obj:ws_goto("2") end)
hs.hotkey.bind({"alt"}, "3",    function () obj:ws_goto("3") end)
hs.hotkey.bind({"alt"}, "4",    function () obj:ws_goto("4") end)
hs.hotkey.bind({"alt"}, "5",    function () obj:ws_goto("5") end)
hs.hotkey.bind({"alt"}, "6",    function () obj:ws_goto("6") end)

hs.hotkey.bind({"shift", "alt"}, "1",    function () obj:focused_window_to_ws("1", true) end)
hs.hotkey.bind({"shift", "alt"}, "2",    function () obj:focused_window_to_ws("2", true) end)
hs.hotkey.bind({"shift", "alt"}, "3",    function () obj:focused_window_to_ws("3", true) end)
hs.hotkey.bind({"shift", "alt"}, "4",    function () obj:focused_window_to_ws("4", true) end)
hs.hotkey.bind({"shift", "alt"}, "5",    function () obj:focused_window_to_ws("5", true) end)
hs.hotkey.bind({"shift", "alt"}, "6",    function () obj:focused_window_to_ws("6", true) end)


return obj
