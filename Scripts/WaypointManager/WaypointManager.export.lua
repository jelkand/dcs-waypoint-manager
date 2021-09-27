package.path  = package.path..";.\\LuaSocket\\?.lua;"
package.cpath = package.cpath..";.\\LuaSocket\\?.dll;"

local socket = require("socket")
local JSON = assert(loadfile "Scripts\\JSON.lua")()

local keyCommandMap = {
  ["N"] = 3020,
  ["E"] = 3024,
  ["S"] = 3026,
  ["W"] = 3022,
  ["1"] = 3019,
  ["2"] = 3020,
  ["3"] = 3021,
  ["4"] = 3022,
  ["5"] = 3023,
  ["6"] = 3024,
  ["7"] = 3025,
  ["8"] = 3026,
  ["9"] = 3027,
  ["0"] = 3018,
  ["ENT"] = 3029,
  ["POSN"] = 3010,
  ["WYPTUP"] = 3022,
  ["WYPTDWN"] = 3023,
  ["DATA"] = 3020,
  ["UFC"] = 3015,
}

local keyDeviceMap = {
  ["N"] = 25, -- UFC,
  ["E"] = 25, -- UFC
  ["S"] = 25, -- UFC
  ["W"] = 25, -- UFC
  ["1"] = 25, -- UFC
  ["2"] = 25, -- UFC
  ["3"] = 25, -- UFC
  ["4"] = 25, -- UFC
  ["5"] = 25, -- UFC
  ["6"] = 25, -- UFC
  ["7"] = 25, -- UFC
  ["8"] = 25, -- UFC
  ["9"] = 25, -- UFC
  ["0"] = 25, -- UFC
  ["ENT"] = 25, -- UFC
  ["POSN"] = 25, -- UFC
  ["WYPTUP"] = 37, -- AMPCD
  ["WYPTDWN"] = 37, -- AMPCD
  ["DATA"] = 37, -- AMPCD
  ["UFC"] = 37, -- AMPCD
}

local startKeySeq = {"DATA", "UFC", "POSN"}
local enterSeq = {"ENT"}
local nextWyptSeq = {"WYPTUP", "UFC", "POSN"}


local inputSequence = startKeySeq
local inputSequenceLength = 0
local sequenceStatus = "WAITING" -- "READY"
local _tNextWyptMgr = 0
local currentlyPressed



wyptmgrServer = {
  logFile = io.open(lfs.writedir() .. [[Logs\WaypointManagerServer.log]], "w")
}
function wyptmgrServer.log(str)
  if not str then
      return
  end

  if wyptmgrServer.logFile then
      wyptmgrServer.logFile:write("[" .. os.date("%H:%M:%S") .. "] " .. str .. "\r\n")
      wyptmgrServer.logFile:flush()
  end
end


wyptmgrServer.config = {
  receive = {
    address = "localhost",
    port = 8675,
    timeout = 0,
  },
}

local function concatTbls(t1, t2)
  for _, val in ipairs(t2) do table.insert(t1, val) end
  return t1
end

-- https://stackoverflow.com/questions/18313171/lua-rounding-numbers-and-then-truncate
local function round(exact, quantum)
  local quant,frac = math.modf(exact/quantum)
  return quantum * (quant + (frac > 0.5 and 1 or 0))
end

local function fromDDtoDDMMMM(decimalDegrees, axis)
  -- wyptmgrServer.log("Converting " .. string.format("%f", decimalDegrees))
  local direction
  local positiveDegrees = decimalDegrees > 0
  if axis == 'x' then
      direction = positiveDegrees and 'E' or 'W'
  else
      direction = positiveDegrees and 'N' or 'S'
  end

  -- wyptmgrServer.log("Got direction " .. direction)

  local unsignedDegrees = math.abs(decimalDegrees)
  local degrees = tonumber(string.format("%u", unsignedDegrees))
  -- wyptmgrServer.log("Got degrees " .. degrees)
  local minutes = round((unsignedDegrees - degrees) * 60, 0.01)
  -- wyptmgrServer.log("Got minutes " .. minutes)
  return direction .. string.format("%u", degrees) .. string.format("%u", minutes * 100)
end

local function fromStringToSequence(str)
  local result = {}
  for letter in str:gmatch(".") do
    table.insert(result, letter)
  end
  return result
end

local function printTable(name, tbl) 
  for idx, entry in ipairs(tbl) do wyptmgrServer.log("Table " .. name .. " idx " .. idx .. " data: " .. entry) end
end

local function buildWyptInputSeq(decodedWaypoints)
  wyptmgrServer.log("Constructing sequence for " .. JSON:encode_pretty(decodedWaypoints))

  local waypointCount = 0
  for _ in ipairs(decodedWaypoints) do waypointCount = waypointCount + 1 end

  wyptmgrServer.log("Found " .. string.format("%u", waypointCount) .. " waypoints...")


  for idx, coord in ipairs(decodedWaypoints) do
    local lat = fromDDtoDDMMMM(coord.y, "y")
    local latSeq = fromStringToSequence(lat)
    latSeq = concatTbls(latSeq, enterSeq)
    
    local long = fromDDtoDDMMMM(coord.x, "x")
    local longSeq = fromStringToSequence(long)
    longSeq = concatTbls(longSeq, enterSeq)
    if idx ~= waypointCount then
      longSeq = concatTbls(longSeq, nextWyptSeq)
    end


    local coordSeq = concatTbls(latSeq, longSeq)
    inputSequence = concatTbls(inputSequence, coordSeq)
  end

  -- printTable("Sequence", inputSequence)
  local seqLength = 0
  for _ in ipairs(inputSequence) do seqLength = seqLength + 1 end

  inputSequenceLength = seqLength

  sequenceStatus = "READY"

  -- return inputSequence
end

local function sleep(sec)
  socket.select(nil, nil, sec)
end



local function pressButton(device, command)
  wyptmgrServer.log("Pressing device " .. device .. " Command " .. command)
  GetDevice(device):performClickableAction(command, 1)
  wyptmgrServer.log("Saving previously pressed button")
  currentlyPressed = { device, command }
  wyptmgrServer.log("Saved previous as " .. currentlyPressed[1] .. ":" .. currentlyPressed[2])
end

local function legacyInputSequence()
  local input = table.remove(inputSequence, 1);
  inputSequenceLength = inputSequenceLength - 1;
  if input == nil then
    wyptmgrServer.log("Out of input, setting status to DONE...")
    sequenceStatus = "DONE"
    return nil
  end

  wyptmgrServer.log("Looking up input: " .. input)
  local device = keyDeviceMap[input]
  wyptmgrServer.log("Got device: " .. device)
  local command = keyCommandMap[input]
  wyptmgrServer.log("Got command: " .. command)
  pressButton(device, command)
end


local function couroutineInputSequence(t)
  -- local tNext = t
  -- local input = table.remove(inputSequence, 1);
  -- if input == nil then return nil end

  for _, input in ipairs(inputSequence) do
    wyptmgrServer.log("Looking up input: " .. input)
    local device = keyDeviceMap[input]
    wyptmgrServer.log("Got device: " .. device)
    local command = keyCommandMap[input]
    wyptmgrServer.log("Got command: " .. command)
    pressButton(device, command)
    coroutine.yield()
  end
end



local function inputWaypoints(decodedWaypoints)
  wyptmgrServer.log("Building sequence...")
  buildWyptInputSeq(decodedWaypoints)
  wyptmgrServer.log("Sequence Status: " .. sequenceStatus .. " Length: " .. inputSequenceLength)
  -- printTable("SEQ", inputSequence)
end

wyptmgrServer.insert = {
  Start = function(self)
    wyptmgrServer.log("Starting up socket on " .. wyptmgrServer.config.receive.address .. " on port " .. wyptmgrServer.config.receive.port)
    wyptmgrServer.receive = socket.try(socket.udp())
		socket.try(wyptmgrServer.receive:setsockname(wyptmgrServer.config.receive.address,wyptmgrServer.config.receive.port))
		socket.try(wyptmgrServer.receive:settimeout(wyptmgrServer.config.receive.timeout))
    wyptmgrServer.log("Established socket...")
  end,
  BeforeNextFrame = function(self)
		local newdata = false
		newdata = wyptmgrServer.receive:receive()
		if newdata then
      wyptmgrServer.log("Received data: " .. newdata)
      wyptmgrServer.log("Current Status: " .. sequenceStatus)
      local decoded = JSON:decode(newdata)
      if sequenceStatus=="READY" then
        wyptmgrServer.log("Waypoints already loaded, ignoring...")
      else
        inputWaypoints(decoded)
      end
    end
	end,
  Stop = function(self)
    wyptmgrServer.log("Shutting down...")
    if wyptmgrServer.receive then
      socket.try(wyptmgrServer.receive:close())
      wyptmgrServer.receive = nil
    end
  end
}

do
	local OtherLuaExportStart=LuaExportStart
	LuaExportStart=function()
    wyptmgrServer.insert:Start()
		if OtherLuaExportStart then
			OtherLuaExportStart()
		end		
	end
end
do
	local OtherLuaExportBeforeNextFrame=LuaExportBeforeNextFrame
	LuaExportBeforeNextFrame=function()
    wyptmgrServer.insert:BeforeNextFrame()
		if OtherLuaExportBeforeNextFrame then
			OtherLuaExportBeforeNextFrame()
		end
	end
end
local _prevLuaExportActivityNextEvent = LuaExportActivityNextEvent


function LuaExportActivityNextEvent(tCurrent)
  wyptmgrServer.log("Current: " .. tCurrent .. " Next: " .. _tNextWyptMgr .. " Status: " .. sequenceStatus)

  if sequenceStatus == "READY" and tCurrent >= _tNextWyptMgr then
    wyptmgrServer.log("Actioning sequence...")

    if currentlyPressed ~= nil and currentlyPressed[1] ~= nil and currentlyPressed[2] ~= nil then
      wyptmgrServer.log("Clearing press... " .. currentlyPressed[1] .. ":" .. currentlyPressed[2])
      GetDevice(currentlyPressed[1]):performClickableAction(currentlyPressed[2])
      wyptmgrServer.log("Cleared press... " .. currentlyPressed[1] .. ":" .. currentlyPressed[2])
      currentlyPressed = nil
      wyptmgrServer.log("Reset Currently Pressed value")
    end
    if sequenceStatus == "READY" then
      wyptmgrServer.log("Actioning input...")
      legacyInputSequence()
      _tNextWyptMgr = tCurrent + 0.4
    end
    if sequenceStatus == "DONE" then
      wyptmgrServer.log("Completed input.")
      _tNextWyptMgr = tCurrent
    end
  end

  local tNext = _tNextWyptMgr

  if _prevLuaExportActivityNextEvent then
    local _status, _result = pcall(_prevLuaExportActivityNextEvent, tCurrent)
    if _status then
        -- Use lower of our tNext (0.2s) or the previous export's
        if _result and _result < tNext and _result > tCurrent then
            tNext = _result
        end
    else
        wyptmgrServer.log('ERROR Calling other LuaExportActivityNextEvent from another script...')
    end
  end

  -- if tNext == tCurrent then
    wyptmgrServer.log("tNext: " .. tNext .. " tCurrent: " .. tCurrent)
  -- end

  return tNext
end

do
	local OtherLuaExportStop=LuaExportStop
	LuaExportStop=function()
    wyptmgrServer.insert:Stop()
		if OtherLuaExportStop then
			OtherLuaExportStop()
		end						
	end
end