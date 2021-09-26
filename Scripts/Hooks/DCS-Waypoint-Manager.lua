function waypointmgr_load()
  package.path = package.path .. ";.\\Scripts\\?.lua;.\\Scripts\\UI\\?.lua;"

  local lfs = require("lfs")
  local U = require("me_utilities")
  local Skin = require("Skin")
  local DialogLoader = require("DialogLoader")
  local Tools = require("tools")
  local Input = require("Input")

  local isHidden = true
  local keyboardLocked = false
  local window = nil
  local windowDefaultSkin = nil
  local windowSkinHidden = Skin.windowSkinChatMin()
  local panel = nil
  local textarea = nil

  local UFC_DEVICE = 25
  local AMPCD_DEVICE = 37

  
  local wyptmgr = {
    logFile = io.open(lfs.writedir() .. [[Logs\WaypointManager.log]], "w")
  }

  local dirPath = lfs.writedir() .. [[WaypointManager\]]
  local currentWyptSetPath = nil
  local wyptSetCount = 0
  local wyptSets = {}

  local JSON = assert(loadfile "Scripts\\JSON.lua")()

  local function loadSet(wyptSet)
    wyptmgr.log("loading file " .. wyptSet.path)
    file, err = io.open(wyptSet.path, "r")
    if err then
        wyptmgr.log("Error reading file: " .. wyptSet.path)
        wyptmgr.log(err)
        return ""
    else
        local content = file:read("*all")
        file:close()
        textarea:setText(content)

        -- update title
        window:setText(wyptSet.name)
    end
  end

  local function loadJSONtoLua(path)
    wyptmgr.log('Loading file: ' .. path)
    file, err = io.open(path, "r")
    if err then
      wyptmgr.log("Error reading file: " .. spath)
      return ""
  else
      local content = file:read("*all")
      file:close()
      local decoded = JSON:decode(content)
      return decoded
  end
  end

  local function nextSet()
    if wyptSetCount == 0 then
        return
    end

    local lastWyptSet = nil
    for _, wyptSet in pairs(wyptSets) do
        if currentWyptSetPath == nil or (lastWyptSet ~= nil and lastWyptSet.path == currentWyptSetPath) then
            loadSet(wyptSet)
            currentWyptSetPath = wyptSet.path
            return
        end
        lastWyptSet = wyptSet
    end

    -- restart at the beginning
    loadSet(wyptSets[1])
    currentWyptSetPath = wyptSets[1].path
  end

  local function prevSet()
    local lastWyptSet = nil
    for i, wyptSet in pairs(wyptSets) do
        if currentWyptSetPath == nil or (wyptSet.path == currentWyptSetPath and i ~= 1) then
            loadSet(lastWyptSet)
            currentWyptSetPath = lastWyptSet.path
            return
        end
        lastWyptSet = wyptSet
    end

    -- restart at the end
    loadSet(wyptSets[wyptSetCount])
    currentWyptSetPath = wyptSets[wyptSetCount].path
end

  function wyptmgr.loadConfiguration()
    wyptmgr.log("Loading config file...")
    local tbl = Tools.safeDoFile(lfs.writedir() .. "Config/WaypointManagerConfig.lua", false)
    if (tbl and tbl.config) then
        wyptmgr.log("Waypoint Manager configuration exists...")
        wyptmgr.config = tbl.config
    else
        wyptmgr.log("Configuration not found, creating defaults...")
        wyptmgr.config = {
            hotkey = "Ctrl+Shift+z",
            windowPosition = {x = 200, y = 200},
            windowSize = {w = 350, h = 150},
            fontSize = 14
        }
        wyptmgr.saveConfiguration()
    end

    -- scan waypoint manager dir for pages
    for name in lfs.dir(dirPath) do
        local path = dirPath .. name
        wyptmgr.log(path)
        if lfs.attributes(path, "mode") == "file" then
            if name:sub(-5) ~= ".json" then
                wyptmgr.log("Ignoring file " .. name .. ", because of it doesn't seem to be a json file (.json). Found suffix: " .. name:sub(-5) )
            elseif lfs.attributes(path, "size") > 1024 * 1024 then
                wyptmgr.log("Ignoring file " .. name .. ", because of its file size of more than 1MB")
            else
                wyptmgr.log("found file " .. path)
                table.insert(
                    wyptSets,
                    {
                        name = name:sub(1, -6),
                        path = path
                    }
                )
                wyptSetCount = wyptSetCount + 1
            end
        end
    end

    -- there are no pages, log and do nothing
    if wyptSetCount == 0 then
      wyptmgr.log("No waypoint sets found.")
    end
  end

  function wyptmgr.saveConfiguration()
    U.saveInFile(wyptmgr.config, "config", lfs.writedir() .. "Config/WaypointManagerConfig.lua")
  end

  function wyptmgr.log(str)
    if not str then
        return
    end

    if wyptmgr.logFile then
        wyptmgr.logFile:write("[" .. os.date("%H:%M:%S") .. "] " .. str .. "\r\n")
        wyptmgr.logFile:flush()
    end
  end

  local function unlockKeyboardInput(releaseKeyboardKeys)
    if keyboardLocked then
        DCS.unlockKeyboardInput(releaseKeyboardKeys)
        keyboardLocked = false
    end
  end

  local function lockKeyboardInput()
    if keyboardLocked then
        return
    end

    local keyboardEvents = Input.getDeviceKeys(Input.getKeyboardDeviceName())
    DCS.lockKeyboardInput(keyboardEvents)
    keyboardLocked = true
  end



  
  -- https://stackoverflow.com/questions/18313171/lua-rounding-numbers-and-then-truncate
  local function round(exact, quantum)
    local quant,frac = math.modf(exact/quantum)
    return quantum * (quant + (frac > 0.5 and 1 or 0))
  end

  local function fromDDtoDDMMMM(decimalDegrees, axis)
    local direction
    local positiveDegrees = decimalDegrees > 0
    if axis == 'x' then
        direction =  positiveDegrees and 'E' or 'W'
    else
        direction =  positiveDegrees and 'N' or 'S'
    end

	local unsignedDegrees = math.abs(decimalDegrees)
    local degrees = tonumber(string.format("%u", unsignedDegrees))
    local minutes = round((unsignedDegrees - degrees) * 60, 0.01)
    return direction .. string.format("%u", degrees) .. string.format("%u", minutes* 100)
  end


  local function inputWaypoints()
    wyptmgr.log('Input waypoints clicked...' .. currentWyptSetPath)

    local currentWyptData = loadJSONtoLua(currentWyptSetPath)

    for idx, coord in ipairs(currentWyptData) do
      wyptmgr.log('At index ' .. idx .. 'found x: ' .. coord.x .. ' and y: ' .. coord.y)

      local lat = fromDDtoDDMMMM(coord.y, 'y')
      local long = fromDDtoDDMMMM(coord.x, 'x')
      wyptmgr.log("Calculated " .. lat .. " " .. long)
    end
  end


  function wyptmgr.createWindow()
    wyptmgr.log('Creating window...')
    window = DialogLoader.spawnDialogFromFile(lfs.writedir() .. "Scripts\\WaypointManager\\WaypointManagerWindow.dlg", cdata)
    wyptmgr.log('Found window dialog file...')
    windowDefaultSkin = window:getSkin()
    panel = window.Box
    textarea = panel.WaypointMgrEditBox
    inputWaypointsBtn = panel.WaypointMgrInsertCoordsButton
    prevButton = panel.WaypointMgrPrevButton
    nextButton = panel.WaypointMgrNextButton
    wyptmgr.log('Got Buttons..')

    -- setup textarea
    local skin = textarea:getSkin()
    skin.skinData.states.released[1].text.fontSize = wyptmgr.config.fontSize
    textarea:setSkin(skin)

    wyptmgr.log('Setting up text area callbacks...')
    -- textarea:addChangeCallback(
    --     function(self)
    --         saveWyptSet(currentWyptSet, self:getText(), true)
    --     end
    -- )
    textarea:addFocusCallback(
        function(self)
            if self:getFocused() then
                lockKeyboardInput()
            else
                unlockKeyboardInput(true)
            end
        end
    )
    textarea:addKeyDownCallback(
        function(self, keyName, unicode)
            if keyName == "escape" then
                self:setFocused(false)
                unlockKeyboardInput(true)
            end
        end
    )

    wyptmgr.log('Setting up buttons...')
    -- setup button callbacks
    prevButton:addMouseDownCallback(
        function(self)
            prevSet()
        end
    )
    nextButton:addMouseDownCallback(
        function(self)
            nextSet()
        end
    )
    inputWaypointsBtn:addMouseDownCallback(
        function(self)
            inputWaypoints()
        end
    )

    wyptmgr.log('Setting window bounds...')
    -- setup window
    window:setBounds(
        wyptmgr.config.windowPosition.x,
        wyptmgr.config.windowPosition.y,
        wyptmgr.config.windowSize.w,
        wyptmgr.config.windowSize.h
    )
    wyptmgr.handleResize(window)

    wyptmgr.log('Registering ' .. wyptmgr.config.hotkey .. ' as the hotkey')
    window:addHotKeyCallback(
        wyptmgr.config.hotkey,
        function()
            if isHidden == true then
                wyptmgr.show()
            else
                wyptmgr.hide()
            end
        end
    )
    window:addSizeCallback(wyptmgr.handleResize)
    window:addPositionCallback(wyptmgr.handleMove)

    window:setVisible(true)
    nextSet()

    wyptmgr.hide()
    wyptmgr.log("Waypoint Manager Window created...")
  end

  function wyptmgr.setVisible(b)
    window:setVisible(b)
  end

  function wyptmgr.handleResize(self)
    local w, h = self:getSize()

    panel:setBounds(0, 0, w, h - 20)
    textarea:setBounds(0, 0, w, h - 20 - 20)
    prevButton:setBounds(0, h - 40, 50, 20)
    nextButton:setBounds(55, h - 40, 50, 20)

    if wyptSetCount > 1 then
        inputWaypointsBtn:setBounds(120, h - 40, 50, 20)
    else
        inputWaypointsBtn:setBounds(0, h - 40, 50, 20)
    end

    wyptmgr.config.windowSize = {w = w, h = h}
    wyptmgr.saveConfiguration()
  end

  function wyptmgr.handleMove(self)
    local x, y = self:getPosition()
    wyptmgr.config.windowPosition = {x = x, y = y}
    wyptmgr.saveConfiguration()
  end

  function wyptmgr.show()
    wyptmgr.log('Showing window...')
    if window == nil then
        wyptmgr.log('Window not found. Creating now...')
        local status, err = pcall(wyptmgr.createWindow)
        if not status then
            net.log("[Waypoint Manager] Error creating window: " .. tostring(err))
        end
    end

    window:setVisible(true)
    window:setSkin(windowDefaultSkin)
    panel:setVisible(true)
    window:setHasCursor(true)

    inputWaypointsBtn:setVisible(true)

    -- show prev/next buttons only if we have more than one page
    if wyptSetCount > 1 then
        prevButton:setVisible(true)
        nextButton:setVisible(true)
    else
        prevButton:setVisible(false)
        nextButton:setVisible(false)
    end

    isHidden = false
  end

  function wyptmgr.hide()
    window:setSkin(windowSkinHidden)
    panel:setVisible(false)
    textarea:setFocused(false)
    window:setHasCursor(false)
    -- window.setVisible(false) -- if you make the window invisible, its destroyed
    unlockKeyboardInput(true)

    isHidden = true
  end

  function wyptmgr.onSimulationFrame()
    if wyptmgr.config == nil then
        wyptmgr.loadConfiguration()
    end

    if not window then
        wyptmgr.log("Creating Waypoint Manager window hidden...")
        wyptmgr.createWindow()
    end
  end

  DCS.setUserCallbacks(wyptmgr)

  net.log("[Waypoint Manager] Loaded...")
end

net.log("[Waypoint Manager] Loading...")
local status, err = pcall(waypointmgr_load)
if not status then
  net.log("[Waypoint Manager] Load Error: " .. tostring(err))
end
