-- "LogLvars" example LUA plug-in, by Pete Dowson, February 2009
-- Enhanced by Luke Kolin, April 2019

-- Number of lines in the display
displayMax = 5

-- Substrings within LVARs to search for
varMatch = {}
-- varMatch = {"flap_latch", "flap_rng","dialaflap"}
-- varMatch = {"FSDT_GSX_NUM", "FSDT_GSX_MENU_OPEN", "FSDT_GSX"}
-- varMatch = {"QW_ap_master_l", "at_mode", "ap_lat_mode", "ap_vert_mode"}
-- varMatch = {"FSDT_GSX_NUMPASSENGERS","FSDT_GSX_BOARDING_CARGO_PERCENT","FSDT_GSX_PILOTS_ON_BOARD","FSDT_GSX_CREW_ON_BOARD","FSDT_GSX_STATE"}
-- varMatch = {"NGXFwd","NGXAft"}
-- varMatch = {"ext757"}
-- varMatch = {"B717_fcp_cgs_nav"}
-- varMatch = {"md11_thr_l_ats_bt","md11_thr_r_ats_bt","md11_ap_state","md11_ats_state","md11_lyoke_ap_bt","md11_ryoke_ap_bt"}
-- varMatch = {"md11_ext_r_spoiler","md11_ext_l_spoiler"}
-- varMatch = {"FSLCONC", "sstsim"}
-- varMatch = {"G03_024_LT0","G03_006_SW2","G03_001_IND","G03_012_LT0","G03_011_LT0","G03_013_LT0","G03_019_LT0","G03_016"}
-- varMatch = {"ext767","ext757_door"}
varMatch = {"B757_MCP_CMD_1_BUTTON","B757_MCP_CMD_2_BUTTON","B757_MCP_CMD_3_BUTTON","BBS_AUTO_THROTTLE","B757_MCP_VNAV_BUTTON","B757_MCP_LNAV_BUTTON","B757_MCP_SPD_BUTTON"}

varExclude = {}
-- varExclude = { "FSDT"}
-- varExclude = { "FSDT","MD11_LTS","fsdt","RAAS","md11_lmcdu","md11_rmcdu","md11_cmcdu","md11_obs"}
-- varExclude = {"csTerr","_IND","_BUT","_NDL","_pilot_"}

-- Timers, how long to sleep between value scans and LVAR name rescans (ms)
sleepTime = 25
rescanCount = 7500

local vals = {}
local names = {}
local lines = {}

-- Scan for LVAR names
local function loadLVARNames()
   i = 0
   while i < 65536 do
      name = ipc.getLvarName(i)
      if name == nil then
         return i
      end
      
      if name ~= names[i] then
         vals[i] = nil
         names[i] = name
      end
      
      i = i + 1
   end
   
   return i
end

-- Read LVAR values and log changed values
local function scanLVARs(max)
   i = 0
   hasChanged = false
   while i < max do
      name = names[i]
      isMatch = table.getn(varMatch) == 0
      for j = 1, table.getn(varMatch), 1 do
         isMatch = isMatch or string.find(name, varMatch[j]) ~= nil
      end

      for j = 1, table.getn(varExclude), 1 do
         isMatch = isMatch and string.find(name, varExclude[j]) == nil
      end
      
      if isMatch then
         n = ipc.readLvar(name)
         if n ~= vals[i] then
            vals[i] = n
            hasChanged = true
            logEntry = "L:" .. name .. "=" .. n
            table.insert(lines, logEntry)
            ipc.log(logEntry)
            if table.getn(lines) > displayMax then
               table.remove(lines, 1)
            end
         end
      end
   
      i = i + 1   
   end
   
   return hasChanged
end

-- Show the display window
local function showDisplay(data)
   disp = ""
   j = table.getn(data)

   repeat
      disp = disp .. "\n" .. data[j]
      j = j - 1
   until j < 1

   ipc.display(disp)
   return 1
end

cnt = 0
maxVar = loadLVARNames()
ipc.log("Starting")

while 1 do
   cnt = cnt + sleepTime
   isChanged = scanLVARs(maxVar)
   if isChanged then
      showDisplay(lines)
   end
   
   if cnt > rescanCount then
      maxVar = loadLVARNames()
      cnt = 0
   end
   
   ipc.sleep(sleepTime)
end
