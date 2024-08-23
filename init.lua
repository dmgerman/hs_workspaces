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
obj.defaultWspace = "1"

obj.currentWS = obj.defaultWspace
obj.winDims = {}
obj.winHidden = {}
-- implement some sets

obj.storeAreaMargin_x = 10
-- TODO: this has to be set to slightly larger than the size of the bar...
obj.storeAreaMargin_y = 80

obj.storeArea = nil

function obj:store_area_set()
  local fr = hs.screen.mainScreen():frame()
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

  if not dict[key] then
    dict[key] = val or true
  end
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



obj.wsSpaces = {}
obj.wsWindows = {}

obj.appsDefaultWspace = {
  ["org.gnu.Emacs"] = "3",
  ["com.bambulab.bambu-studio"] = "4"
}

obj.appsEverywhere = {
  ["com.apple.systempreferences"]=true,
  ["org.hammerspoon.Hammerspoon"]=true,
}

obj.wspaces = {}

function obj:debug_window(win, st)
  print(st)
  assert(obj:is_window(win), "invalid window parameter ")
  print("Window: ", win)
  print("    ws:       ", obj:window_get_ws(win))
  print("    hidden:   ", obj:win_is_hidden(win))
  print("    fr:       ", obj:win_dimensions_get(win))
  print("    in screen:", obj:win_frame_in_screen(win))
end

function obj:verity_state()
end

function obj:window_is_everywhere(win)
  assert(obj:is_window(win), "invalid window parameter ")

  assert(win ~= nil, "No window provided")
  local app = win:application()
  return obj:dict_in(obj.appsEverywhere, app:bundleID())
end

function obj:window_ignore(win)
  -- ignorable windows 
  assert(obj:is_window(win), "invalid window parameter ")

  return win:screen() ~= hs.screen.primaryScreen()
    or win:isFullScreen()
    or win:isMinimized()
    or (not win:isMaximizable())
    or obj:window_is_everywhere(win) 
end


function obj:window_get_ws(win)
  assert(obj:is_window(win), "invalid window parameter " )
  result = obj:dict_get(obj.wsWindows, win:id())
  assert(result, "Window_get_ws found no ws for win")
  return result["ws"]
end

function obj:window_set_ws(win, ws)
  assert(obj:is_window(win), "invalid window parameter " )
  assert(obj:is_ws(ws), "invalid ws parameter")
  
  obj:dict_set(obj.wsWindows, win:id(),
    {["title"] = win:title(), ["ws"]= ws, ["app"] = win:application()}
  )
end

function obj:window_remove_ws(win)
  assert(obj:is_window(win), "invalid window parameter " )
    
  obj:dict_set(obj.wsWindows, win:id(), nil)
end


function obj:ws_get_windows(ws)
  assert(obj:is_ws(ws), "invalid name for workspace "..ws )

  return obj:dict_get(obj.wsSpaces, ws)
end

function obj:ws_add_window(ws, win)
  assert(obj:is_ws(ws), "invalid name for workspace "..ws )
  assert(obj:is_window(win), "invalid window parameter " )

  local wsDict = obj:dict_get(obj.wsSpaces, ws)

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
  local ws = obj:dict_get(obj.wsSpaces, win:id())
  local wsDict = ws and obj:dict_get(obj.wsSpaces, ws)

  -- remove from workspace
  if wsDict then
    obj:dict_remove(wsDict, win)
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

function obj:win_dimensions_save(win)
  assert(obj:is_window(win), "invalid parameter, should be a window")

  local fr = win:frame()

--  assert(obj:win_frame_in_screen(win), "window not in main screen")

  obj:dict_set(obj.winDims, win:id(), fr)
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
  assert(obj:is_ws(ws), "invalid name for workspace "..ws )
  assert(obj:is_window(win), "invalid window parameter " )

  obj:ws_add_window(ws, win)
  obj:window_set_ws(win, ws)
end

function obj:window_move_to_ws(win, ws)
  assert(type(ws)== "string" and string.len(ws) > 0, "invalid name for workspace in window_move_to_ws ")
  assert(obj:is_window(win), "invalid window parameter ")

  if obj:window_ignore(win) then
    return win
  end
  if obj:window_get_ws(win) == ws then
    -- already in current space
    return win
  end

  obj:ws_remove_window(win)

  obj:ws_insert_window(ws, win)

  obj:window_set_ws(win, ws)

  return win
end

function obj:window_default_ws(win)
  assert(obj:is_window(win), "invalid window parameter ")
  return obj:dict_get(obj.appsDefaultWspace, win:application():bundleID()) or
    obj.currentWS
end

function obj:manage_window(win)
  assert(obj:is_window(win), "invalid window parameter ")

  if obj:window_ignore(win) then
    return 
  end

  local ws = obj:window_default_ws(win)

  obj:ws_insert_window(ws, win)
  obj:window_set_ws(win, ws)
end

function obj:forget_window(win)
  print("forget window: ", win, win:id())
  -- at this point, win might no longer be a win
  obj:ws_remove_window(win)
  obj:window_remove_ws(win)
end


function callback_window(win, appName, event)

  if event == "windowDestroyed" then
    print("Window destroyed: ", win)
    obj:forget_window(win)
    return
  end
   
  if event == "windowCreated" then
    print("Window created: ", win)
    obj:manage_window(win)
    return 
  end

  if event == "windowMoved" then
    print("#################################################event for window moved", win)
    print("hidden  ", obj:win_is_hidden(win))
    print("current ", win:frame())
    print("saved   ", obj:win_dimensions_get(win))
    if (not obj:window_ignore(win)) and not obj:win_is_hidden(win) then
      if obj:window_get_ws(win) ~= obj.currentWS then
        -- it is not where it is supposed to be, save new location
        print("  ------------ save new workspace")
        obj:win_dimensions_save(win)
      end
      print("  ------------ save new location")
      obj:window_set_ws(win, obj.currentWS)
      -- window was 
    end
    print("#################################################")

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
    return 
  end
  print("event not handled>>>>>>>>>>>>>>>>>>>>", event)

end

function obj:win_filters_disable()
  print("                      -------- Filters disabled>>>")
  obj.winFilter:pause()
end

function obj:win_filters_enable()
  print("                      -------- Filters enabled<<<<")
  obj.winFilter:resume()
end





---------------------------------------------------
function obj:move_to_storage_area(win)
  assert(obj:is_window(win), "invalid parameter, should be a window")
  print("***********************************************************")
  local winFr = win:frame()
  print("WinFrame: ", hs.inspect(winFr))
  winFr.x = obj.storeArea.x
  winFr.y = obj.storeArea.y
  win:move(winFr)
  print("WinFrame: ", hs.inspect(win:frame()))
  print("***********************************************************")

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
  obj:win_dimensions_save(win)
--  local screenFr = hs.screen.mainScreen():frame()
  
  obj:move_to_storage_area(win)

  print("endHide: <<<<<<<<<<<<<<<<<<<<<<<<,end ", win)
end

function obj:restore(win)
  print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>restoring", win)
  assert(obj:is_window(win), "invalid parameter, should be a window")

  if obj:window_ignore(win) then
    print("ENd>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>restoring, ignore", win)
    return
  end

  if not obj:win_is_hidden(win) then
    print(">>>>>>>>>>>>>>RESTORE:        window is not hidden", win, obj:win_is_hidden(win))
    print("ENd>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>restoring, not hidden", win)
    return
  end

  local frame = obj:win_dimensions_get(win)

  if not frame or obj:frame_in_store_area(frame) then
    local fr = hs.screen.mainScreen():frame()
    print("restoring to <0,0>", fr, fr.x, fr.y)
    win:move({x=fr.x,y=fr.y})
  else
    print("restoring to frame .....", frame)
    win:move(frame)
  end

  print("ENd>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>restoring, end", win)
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
  assert(obj:is_ws(ws), "invalid name for workspace "..ws )

  print("Begin goto*******************************************----------------", ws)
  obj.currentWS = ws

  obj:win_filters_disable()
  local wins = obj:windows_get_all()
--  print("Wins:", hs.inspect(wins))

  for wid, wdata in pairs(wins) do
    local win = hs.window(wid)
    local wws = wdata["ws"]
    if win and (not obj:window_ignore(win))  then --and obj:win_frame_in_screen(win)
      if wws == ws then
  --      obj:debug_window(win, "+++++++in goto to restore: \n")
        print("Window:", wid, vdata)
        print("Window2:", win)
        print("\n\nTo restore")
        obj:restore(win)
      else
--        obj:debug_window(win, "---------------++++in goto to hide: \n")
        print("Window:", wid, vdata)
        print("Window2:", win)
        print("\n\nTo hide")
        obj:hide(win)
      end
    end
  end

  obj:win_filters_enable()
  obj:ws_display()
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

function obj:ws_display()
  hs.alert("Current workspace: " .. obj.currentWS)
end

--- some initialization

obj:store_area_set()


-- startup: give all current windows a workspace
-- and move windows to where they belong

for i,win in ipairs(hs.window.allWindows()) do
  print("Window......... ", win)
  local ws = obj:window_default_ws(win)

  if obj:win_in_store_area(win) then
    print("window was left in store area, moving back")
    win:move({x=0, y=0})
  else
    print("window was not in store area")
  end
  obj:ws_insert_window(ws, win)
  if ws ~= obj.currentWS then
    obj:hide(win)
  end
end

-- set windows filter and its callback

obj.winFilter = hs.window.filter.new()
obj.winFilter:setDefaultFilter{}
obj.winFilter:subscribe(hs.window.filter.windowCreated, callback_window)
obj.winFilter:subscribe(hs.window.filter.windowDestroyed, callback_window)
obj.winFilter:subscribe(hs.window.filter.windowFocused, callback_window)
obj.winFilter:subscribe(hs.window.filter.windowMoved, callback_window)
--obj.winFilter:subscribe(hs.window.filter.windowMoved, callback_window_move)


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
