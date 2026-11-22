
local mcp777SwitchCode = {234, 235, 236, 237, 238, 239, 240, 241, 242}

lastWXT = 0
lastMCP = 0
APMode = 0
lastLS = ""

btnCount = 0
updCount = 0
lastLED = 0

-- Joystick/HID data

Vendor = 0x294B
Product = 0x1901
Device = 0  -- Multiple devices of the same name need increasing Device numbers.
hidHandle = 0

prevButtons = { 0, 0 }
lastButtonOfs = { 0, 0 }

local function toBits(num, bits)
    -- returns a table of bits
    local t={} -- will contain the bits
    for b=bits,1,-1 do
        rest=math.fmod(num,2)
        t[b]=rest
        num=(num-rest)/2
    end

    return t
end

function HandleVButton(ofs, v)

local bits = 32
local lastButtonIdx = ((ofs - 0x3340) / 4) + 1
local lastValue = lastButtonOfs[lastButtonIdx]

local b = toBits(v, bits)
local lb = toBits(lastValue, bits)
for bit = 1, bits do
  if ((b[bit] ~= lb[bit]) and (b[bit] == 1))then
    -- ipc.log("Toggled Offset " .. ofs .. " Bit " .. (bit-1) .. " = " .. b[bit])
    if (bit == 31) then
      HandleAPEvent(9)
    elseif (bit == 30) then
      HandleAPEvent(10)
    elseif (bit == 29) then
      HandleAPEvent(11)
    elseif (bit == 28) then
      HandleAPEvent(12)
    elseif (bit == 27) then
      HandleAPEvent(13)
    elseif (bit == 26) then
      HandleAPEvent(14)
    elseif (bit == 25) then
      HandleAPEvent(15)
    elseif (bit == 24) then
      HandleAPEvent(16)
    elseif (bit == 23) then
      HandleAPEvent(17)
    elseif (bit == 22) then
      HandleAPEvent(18)
    elseif (bit == 21) then
      HandleAPEvent(19)
    elseif (bit == 20) then
      HandleAPEvent(20)
    end
  end
end

lastButtonOfs[lastButtonIdx] = v

end

function HID_Poll(time)

local buttons = {}
CurrentData, n, discards = com.readlast(hidHandle, rd)
if (n ~= 0) then
  buttons[1], buttons[2] =  com.GetHidButtons(hidHandle, CurrentData)

  -- check for changes   
  if (buttons[2] ~= prevButtons[2]) then
    prevButtons[2] = buttons[2]

    -- Send to FSUIPC as a set of 32 virtual buttons i.e. DWORD offsets 3340 onwards
    ipc.writeUD(0x3344, buttons[2])
    HandleVButton(0x3344, buttons[2])
  end
end

local updInterval = time - lastLED
if (updInterval >= 250) then
  UpdateLED()
  lastLED = time
end

end -- poll function

local function noop()

end

function HandleShutdown()

if (hidHandle ~= 0) then
  event.cancel("HID_Poll")
  ipc.log("Poll loop stopped")
  ClearLED()
  ipc.Log("Annunciators Reset")
  com.close(hidHandle)
  ipc.log("USB Device (hnd=" .. hidHandle .. ") disconnected")
  hidHandle = 0
end

event.cancel("HandleShutdown")
ipc.log("PMDG 777 Button Handler shutdown (" .. btnCount .. " buttons, " .. updCount .. " LED updates)")
ipc.exit()

end

local function fromb(value)

return value and 1 or 0

end -- fromb

local function toggleLED(wd, value, flag)

if (value > 0) then
  wd = logic.Or(wd, flag)
end

return wd

end -- toggleLED

function UpdateLED()


end -- UpdateLED

function ClearLED()

local ls = string.char(0) .. string.char(0) .. string.char(0) .. string.char(0) .. string.char(0)
com.writefeature(hidHandle, ls, wrf)
lastLS = ls
updCount = updCount + 1

end -- ClearLED

function HandleAPEvent(op)

-- ipc.log("APEvent " .. op)

-- 1 = autopilot disconnect set
-- 2 = autopilot disconnect release
-- 3 = autothrottle master toggle
-- 4 = HSI range increase
-- 5 = HSI range decrease
-- 6 = WX radar/terrain toggle
-- 7 = Lower MCP increment
-- 8 = Local MCP decrement
-- 9 = Landing Light ON
-- 10 = Landing Light OFF
-- 11 = Taxi Light ON
-- 12 = Taxi Light OFF
-- 13 = Beacon ON
-- 14 = Beacon OFF
-- 15 = Strobes ON
-- 16 = Strobes OFF
-- 17 = Wing Light ON
-- 18 = Wing Light OFF
-- 19 = Logo Light ON
-- 20 = Logo Light OFF
-- 21 = increment
-- 22 = decrement
-- 23 = setAPMode IAS
-- 24 = setAPMode CRS
-- 25 = setAPMode HDG
-- 26 = setAPMode VS
-- 27 = setAPMode ALT
-- 28 = AP
-- 29 = LNAV
-- 30 = HDG
-- 31 = VS
-- 32 = IAS

if (op == 0) then
  noop()
elseif (op == 1) then
  ipc.control(69632+214, 0x20000000)
elseif (op == 2) then
  ipc.control(69632+214, 0x80000000)
elseif (op == 3) then
  local atOn = ipc.readSB(0x6572)
  if (atOn == 1) then
    ipc.control(69632+204, 0x20000000)
    ipc.control(69632+205, 0x20000000)
  else
    ipc.control(69632+204, 0x80000000)
    ipc.control(69632+205, 0x80000000)
  end
elseif (op == 4) then
  local lr = ipc.readSB(0x6522)
  local rr = ipc.readSB(0x6523)
  local lmd = ipc.readSB(0x6520)
  local rmd = ipc.readSB(0x6521)
  if (lr < 7) then
    ipc.control(69632+187, 0x80000000)
    if (rr < 6) then
      ipc.control(69632+254, 0x80000000)
    end
    if (mdR ~= 2) then
      local delta = 2 - rmd
      for i=1,delta,1 do
        if (delta < 0) then
          ipc.control(69632+252, 0x20000000)
        else
          ipc.control(69632+252, 0x80000000)
        end
      end
    end
  end  
elseif (op == 5) then
  lr = ipc.readSB(0x6522)
  rr = ipc.readSB(0x6523)
  lmd = ipc.readSB(0x6520)
  rmd = ipc.readSB(0x6521)
  if (lr > 0) then
    ipc.control(69632+187, 0x20000000)
    if (rr > 1) then
      ipc.control(69632+254, 0x20000000)
    end
    if (mdR ~= 2) then
      local delta = 2 - rmd
      for i=1,delta,1 do
        if (delta < 0) then
          ipc.control(69632+252, 0x20000000)
        else
          ipc.control(69632+252, 0x80000000)
        end
      end
    end
  end
elseif (op == 6) then
  if (lastWXT == 0) then
    ipc.control(69632+195, 0x20000000)
    lastWXT = 1
  elseif (lastWXT == 1) then
    ipc.control(69632+201, 0x20000000)
    lastWXT = 2
  else
    ipc.control(69632+201, 0x80000000)
    lastWXT = 0
  end
elseif (op == 7) then
  lastMCP = math.min(table.getn(mcp777SwitchCode), lastMCP + 1)
  local ctl = mcp777SwitchCode[lastMCP]
  -- ipc.log("lastMCP now " .. lastMCP .. " ctl = " .. ctl)
  ipc.control(69632 + ctl, 0x20000000)
elseif (op == 8) then
  lastMCP = math.max(1, lastMCP - 1)
  local ctl = mcp777SwitchCode[lastMCP]
  -- ipc.log("lastMCP now " .. lastMCP .. " ctl = " .. ctl)
  ipc.control(69632 + ctl, 0x20000000)
elseif (op == 9) then
  local llL = ipc.readUB(0x6485)
  local llR = ipc.readUB(0x6486)
  local llC = ipc.readUB(0x6487)
  if (llL == 0) then ipc.control(69632+22, 0x20000000) end
  if (llR == 0) then ipc.control(69632+24, 0x20000000) end
  if (llC == 0) then ipc.control(69632+23, 0x20000000) end
elseif (op == 10) then
  local llL = ipc.readUB(0x6485)
  local llR = ipc.readUB(0x6486)
  local llC = ipc.readUB(0x6487)
  if (llL ~= 0) then ipc.control(69632+22, 0x20000000) end
  if (llR ~= 0) then ipc.control(69632+24, 0x20000000) end
  if (llC ~= 0) then ipc.control(69632+23, 0x20000000) end
elseif (op == 11) then
  local isOn = ipc.readUB(0x648E)
  if (isOn == 0) then ipc.control(69632+121, 0x20000000) end
elseif (op == 12) then
  local isOn = ipc.readUB(0x648E)
  if (isOn ~= 0) then ipc.control(69632+121, 0x80000000) end
elseif (op == 13) then
  local isOn = ipc.readUB(0x6488)
  if (isOn == 0) then ipc.control(69632+114, 0x20000000) end
elseif (op == 14) then
  local isOn = ipc.readUB(0x6488)
  if (isOn ~= 0) then ipc.control(69632+114, 0x80000000) end
elseif (op == 15) then
  local isOn = ipc.readUB(0x648F)
  if (isOn == 0) then ipc.control(69632+122, 0x20000000) end
elseif (op == 16) then
  local isOn = ipc.readUB(0x648F)
  if (isOn ~= 0) then ipc.control(69632+122, 0x80000000) end
elseif (op == 17) then
  local isOn = ipc.readUB(0x648B)
  if (isOn == 0) then ipc.control(69632+117, 0x20000000) end
elseif (op == 18) then
  local isOn = ipc.readUB(0x648B)
  if (isOn ~= 0) then ipc.control(69632+117, 0x80000000) end
elseif (op == 19) then
  local isOn = ipc.readUB(0x648A)
  if (isOn == 0) then ipc.control(69632+116, 0x20000000) end
elseif (op == 20) then
  local isOn = ipc.readUB(0x648A)
  if (isOn ~= 0) then ipc.control(69632+116, 0x80000000) end
elseif (op == 21) then
  if (APMode == 0) then
    ipc.control(69632+210, 0x80000000)
    ipc.control(69632+210, 0x00020000)
  elseif (APMode == 1) then
    noop()
  elseif (APMode == 2) then
    ipc.control(69632+2180, 0x80000000)
    ipc.control(69632+2180, 0x00020000)
  elseif (APMode == 3) then
    ipc.control(69632+222, 0x80000000)
    ipc.control(69632+222, 0x00020000)
  elseif (APMode == 4) then
    ipc.control(69632+2250, 0x80000000)
    ipc.control(69632+2250, 0x00020000)
  else
    ipc.log("Unknown APMode - " .. APMode)
  end
elseif (op == 22) then
  if (APMode == 0) then
    ipc.control(69632+210, 0x20000000)
    ipc.control(69632+210, 0x00020000)
  elseif (APMode == 1) then
    noop()
  elseif (APMode == 2) then
    ipc.control(69632+2180, 0x20000000)
    ipc.control(69632+2180, 0x00020000)
  elseif (APMode == 3) then
    ipc.control(69632+222, 0x20000000)
    ipc.control(69632+222, 0x00020000)
  elseif (APMode == 4) then
    ipc.control(69632+2250, 0x20000000)
    ipc.control(69632+2250, 0x00020000)
  else
    ipc.log("Unknown APMode - " .. APMode)
  end
elseif ((op > 22) and (op < 28)) then
  APMode = op - 23
elseif (op == 28) then

elseif (op == 29) then

elseif (op == 30) then
  
elseif (op == 31) then

elseif (op == 32) then

else
  ipc.log("Unknown parameter - " .. op)
end

-- Reset parameter
if (op > 0) then
  btnCount = btnCount + 1
  ipcPARAM = 0
end

end -- function

-- First, we need to get the device
hidHandle, rd, wrf, wr, hidInit = com.openhid(Vendor, Product, Device, 0)
if (hidHandle == 0) then
  ipc.log("Could not open HID -- polling disabled")
else
  ipc.log("USB Device Connected")
  HID_Poll(0)
  event.timer(50, "HID_Poll")
  ipc.log("Poll loop started")
end

event.param("HandleAPEvent")
event.terminate("HandleShutdown")
ipc.log("Registered PMDG 777 Button Handler")

-- Reset lower MCP
ipc.writeLvar("switch_234_a", 100)

ipc.display("PMDG 777 Button Handler registered", 1, 8)
