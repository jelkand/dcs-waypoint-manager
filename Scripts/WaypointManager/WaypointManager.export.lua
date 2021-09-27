package.path  = package.path..";.\\LuaSocket\\?.lua;"
package.cpath = package.cpath..";.\\LuaSocket\\?.dll;"

local socket = require("socket")
local JSON = assert(loadfile "Scripts\\JSON.lua")()

local UFC_DEVICE = 25
local AMPCD_DEVICE = 37

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
      GetDevice(25):performClickableAction(3019, 1)
      GetDevice(25):performClickableAction(3019, 0)
      wyptmgrServer.log("Got data..." .. newdata)
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
do
	local OtherLuaExportStop=LuaExportStop
	LuaExportStop=function()
    wyptmgrServer.insert:Stop()
		if OtherLuaExportStop then
			OtherLuaExportStop()
		end						
	end
end