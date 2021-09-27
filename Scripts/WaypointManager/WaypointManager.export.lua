package.path  = package.path..";.\\LuaSocket\\?.lua;"
package.cpath = package.cpath..";.\\LuaSocket\\?.dll;"

local socket = require("socket")
local JSON = assert(loadfile "Scripts\\JSON.lua")()

local shortdelay = 0.2
local nodelay = 0.05
local longdelay = 0.5

local keyCommandMapping = {
  ["N"] = {
    device = 25,
    command = 3020,
    onvalue = 1,
    offvalue = 0,
    releasedelay = longdelay,
  },
  ["E"] = {
    device = 25,
    command = 3024,
    onvalue = 1,
    offvalue = 0,
    releasedelay = longdelay,
  },
  ["S"] = {
    device = 25,
    command = 3026,
    onvalue = 1,
    offvalue = 0,
    releasedelay = longdelay,
  },
  ["W"] = {
    device = 25,
    command = 3022,
    onvalue = 1,
    offvalue = 0,
    releasedelay = longdelay,
  },
  ["1"] = {
    device = 25,
    command = 3019,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["2"] = {
    device = 25,
    command = 3020,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["3"] = {
    device = 25,
    command = 3021,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["4"] = {
    device = 25,
    command = 3022,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["5"] = {
    device = 25,
    command = 3023,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["6"] = {
    device = 25,
    command = 3024,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["7"] = {
    device = 25,
    command = 3025,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["8"] = {
    device = 25,
    command = 3026,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["9"] = {
    device = 25,
    command = 3027,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["0"] = {
    device = 25,
    command = 3018,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["ENT"] = {
    device = 25,
    command = 3029,
    onvalue = 1,
    offvalue = 0,
    releasedelay = longdelay,
  },
  ["POSN"] = {
    device = 25,
    command = 3010,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["WYPTUP"] = {
    device = 37,
    command = 3022,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["WYPTDWN"] = {
    device = 37,
    command = 3023,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["DATA"] = {
    device = 37,
    command = 3020,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
  ["UFC"] = {
    device = 37,
    command = 3015,
    onvalue = 1,
    offvalue = 0,
    releasedelay = shortdelay,
  },
}


local startKeySeq = {"DATA", "UFC", "POSN"}
local enterSeq = {"ENT"}
local nextWyptSeq = {"WYPTUP", "UFC", "POSN"}


local inputSequence = startKeySeq

local keypressSequence = {}
local keypressSequenceLength = 0
local sequenceStatus = "WAITING" -- "READY" -- "DONE"
local _tNextWyptMgr = 0

local function resetState()
  inputSequence = startKeySeq
  keypressSequence = {}
  keypressSequenceLength = 0
  sequenceStatus = "WAITING"
end


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
  -- wyptmgrServer.log("Constructing sequence for " .. JSON:encode_pretty(decodedWaypoints))

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
  return inputSequence
end

local function executeClickableAction(args)
  wyptmgrServer.log("Pressing button " .. args.command .. " on device " .. args.device .. " with value " .. args.value)
  GetDevice(args.device):performClickableAction(args.command, args.value)
end

local function inputNextKeypress()
  local input = table.remove(keypressSequence, 1);
  keypressSequenceLength = keypressSequenceLength - 1;

  if input == nil then
    wyptmgrServer.log("Out of input, setting status to DONE...")
    sequenceStatus = "DONE"
    
    return nil
  end

  executeClickableAction(input)
  return input.delay
end


local function buildKeypressSequence() 
  for _, input in ipairs(inputSequence) do
    -- format: { device, command, value, delay}

    local inputTable = keyCommandMapping[input]

    local press = { device = inputTable.device, command = inputTable.command, value = inputTable.onvalue, delay = inputTable.releasedelay}
    local release = { device = inputTable.device, command = inputTable.command, value = inputTable.offvalue, delay = nodelay}

    table.insert(keypressSequence, press)
    table.insert(keypressSequence, release)
    keypressSequenceLength = keypressSequenceLength + 2
  end

  sequenceStatus = "READY"
end

local function inputWaypoints(decodedWaypoints)
  wyptmgrServer.log("Building sequence...")
  local inptSeq = buildWyptInputSeq(decodedWaypoints)
  buildKeypressSequence()
  printTable("CMD", keypressSequence)
  wyptmgrServer.log("Sequence Status: " .. sequenceStatus .. " Length: " .. keypressSequenceLength)
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
        wyptmgrServer.log("Waypoints already loaded, ignoring new data...")
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

  if sequenceStatus == "READY" and _tNextWyptMgr - tCurrent < 0.01 then
    wyptmgrServer.log("Actioning sequence...")
    if sequenceStatus == "READY" then
      wyptmgrServer.log("Actioning input...")
      local delay = inputNextKeypress()
      _tNextWyptMgr = tCurrent + delay
    end
    if sequenceStatus == "DONE" then
      wyptmgrServer.log("Completed input.")
      -- reset state
      resetState()
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