
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

-- returns a table of bits
local function toBits(num, bits)
    local t={}
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
      HandleAPEvent(7)
    elseif (bit == 30) then
      HandleAPEvent(8)
    elseif (bit == 29) then
      HandleAPEvent(9)
    elseif (bit == 28) then
      HandleAPEvent(10)
    elseif (bit == 27) then
      HandleAPEvent(11)
    elseif (bit == 26) then
      HandleAPEvent(12)
    elseif (bit == 25) then
      HandleAPEvent(13)
    elseif (bit == 24) then
      HandleAPEvent(14)
    elseif (bit == 23) then
      HandleAPEvent(15)
    elseif (bit == 22) then
      HandleAPEvent(16)
    elseif (bit == 21) then
      HandleAPEvent(17)
    elseif (bit == 20) then
      HandleAPEvent(18)
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

event.cancel("HandleShutdown")
event.cancel("HandleAPEvent")
if (hidHandle ~= 0) then
  event.cancel("HID_Poll")
  ipc.log("Poll loop stopped")
  ClearLED()
  ipc.log("Throttle LEDs cleared")
  com.close(hidHandle)
  ipc.log("USB Device (hnd=" .. hidHandle .. ") disconnected")
end

ipc.log("PMDG 737 Button Handler shutdown (" .. btnCount .. " buttons, " .. updCount .. " LED updates)")
ipc.exit()

end -- handleShutdown function

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

local apu = ipc.readFLT(0x648C)
local apuMode = ipc.readUB(0x64FB)
local apuOil = ipc.readUB(0x6491)
local pitot = logic.Or(ipc.readUB(0x64AE), ipc.readUB(0x64B2))
local antiIce = ipc.readUD(0x64A6)
antiIce = logic.Not(antiIce, 0x0001001001001)

local starter = ipc.readUW(0x64FC)
if ((logic.Shr(starter, 8) == 0) or (logic.And(starter, 0xFF) == 0)) then
  starter = 1
else
  starter = 0
end

if ((apu > 40) or (apuOil > 0) or (apuMode > 0)) then
  apu = 1
else
  apu = 0
end

local gTr = logic.And(ipc.readUD(0x6570), 0xFFFFFF)
local gLk = logic.And(ipc.readUD(0x6573), 0xFFFFFF)
local gT = { logic.And(gTr, 0xFF), logic.Shr(logic.And(gTr, 0xFF00), 8), logic.Shr(logic.And(gTr, 0xFF0000), 16) }
local gL = { logic.And(gLk, 0xFF), logic.Shr(logic.And(gLk, 0xFF00), 8), logic.Shr(logic.And(gLk, 0xFF0000), 16) }

local masterC = ipc.readUW(0x6506)
local fireWarn = ipc.readUW(0x6504)
local fuelWarn = ipc.readUW(0x646A) + ipc.readUW(0x646C) + ipc.readUW(0x646E)
local hydWarn = ipc.readUD(0x64C1)
local door = logic.Or(ipc.readDD(0x6C14), ipc.readUD(0x6C1C))
local lowVolt = logic.Or(ipc.readUB(0x6470), ipc.readUB(0x6472))
local ff = (ipc.readDBL(0x2020) < 550) or (ipc.readDBL(0x2120) < 550)

local AP_W = toggleLED(0, ipc.readUB(0x6545) + ipc.readUB(0x6547), 128)
AP_W = toggleLED(AP_W, ipc.readUB(0x653F), 1)
AP_W = toggleLED(AP_W, ipc.readUB(0x6540), 2)
AP_W = toggleLED(AP_W, ipc.readUB(0x6542), 4)
AP_W = toggleLED(AP_W, ipc.readUB(0x6544), 32)
AP_W = toggleLED(AP_W, ipc.readUB(0x653C), 64)

local LG_W = toggleLED(0, masterC, 64)
LG_W = toggleLED(LG_W, fireWarn, 128)
LG_W = toggleLED(LG_W, gT[1], 2)
LG_W = toggleLED(LG_W, gL[1], 1)
LG_W = toggleLED(LG_W, gT[2], 8)
LG_W = toggleLED(LG_W, gL[2], 4)
LG_W = toggleLED(LG_W, gT[3], 32)
LG_W = toggleLED(LG_W, gL[3], 16)

local ANN_W1 = toggleLED(0, hydWarn, 128)
ANN_W1 = toggleLED(ANN_W1, fuelWarn, 2)
ANN_W1 = toggleLED(ANN_W1, pitot+antiIce, 4)
ANN_W1 = toggleLED(ANN_W1, starter, 8)
ANN_W1 = toggleLED(ANN_W1, apu, 16)

local ANN_W2 = toggleLED(0, door, 8)
ANN_W2 = toggleLED(ANN_W2, fuelWarn, 1)
ANN_W2 = toggleLED(ANN_W2, ipc.readUB(0x65A7), 2)
ANN_W2 = toggleLED(ANN_W2, lowVolt, 4)

local ls = string.char(0) .. string.char(AP_W) .. string.char(LG_W) .. string.char(ANN_W1) .. string.char(ANN_W2)
if (ls ~= lastLS) then
  com.writefeature(hidHandle, ls, wrf)
  lastLS = ls
  updCount = updCount + 1
end

end -- updateLED function

function ClearLED()

local ls = string.char(0) .. string.char(0) .. string.char(0) .. string.char(0) .. string.char(0)
com.writefeature(hidHandle, ls, wrf)
ipc.log('Indicators Cleared')
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
-- 7 = Landing Light ON
-- 8 = Landing Light OFF
-- 9 = Taxi Light ON
-- 10 = Taxi Light OFF
-- 11 = Beacon ON
-- 12 = Beacon OFF
-- 13 = Strobes ON
-- 14 = Strobes OFF
-- 15 = Wing Light ON
-- 16 = Wing Light OFF
-- 17 = Logo Light ON
-- 18 = Logo Light OFF
-- 19 = increment
-- 20 = decrement
-- 21 = setAPMode IAS
-- 22 = setAPMode CRS
-- 23 = setAPMode HDG
-- 24 = setAPMode VS
-- 25 = setAPMode ALT
-- 26 = AP
-- 27 = LNAV
-- 28 = HDG
-- 29 = VS
-- 30 = IAS

if (op == 0) then
  noop()
elseif (op == 1) then
  ipc.control(70038, 1)
elseif (op == 2) then
  ipc.control(70038, 0)
elseif (op == 3) then
  local atOn = ipc.readSB(0x6535)
  if (atOn == 1) then
    ipc.control(70012, 0x20000000)
  else
    ipc.control(70012, 0x80000000)
  end
elseif (op == 4) then
  local lr = ipc.readSB(0x651E)
  local rr = ipc.readSB(0x651F)
  local lmd = ipc.readSB(0x651C)
  local rmd = ipc.readSB(0x651D)
  if (lr < 7) then
    ipc.control(69632+361, 0x80000000)
    if (rr < 6) then
      ipc.control(69632+417, 0x80000000)
    end
    if (mdR ~= 2) then
      local delta = 2 - rmd
      for i=1,delta,1 do
        if (delta < 0) then
          ipc.control(69632+415, 0x20000000)
        else
          ipc.control(69632+415, 0x80000000)
        end
      end
    end
  end  
elseif (op == 5) then
  local lr = ipc.readSB(0x651E)
  local rr = ipc.readSB(0x651F)
  local lmd = ipc.readSB(0x651C)
  local rmd = ipc.readSB(0x651D)
  if (lr > 0) then
    ipc.control(69632+361, 0x20000000)
    if (rr > 1) then
      ipc.control(69632+417, 0x20000000)
    end
    if (mdR ~= 2) then
      local delta = 2 - rmd
      for i=1,delta,1 do
        if (delta < 0) then
          ipc.control(69632+415, 0x20000000)
        else
          ipc.control(69632+415, 0x80000000)
        end
      end
    end
  end
elseif (op == 6) then
  if (lastWXT == 0) then
    ipc.control(69632+369, 0x20000000)
    lastWXT = 1
  elseif (lastWXT == 1) then
    ipc.control(69632+375, 0x20000000)
    lastWXT = 2
  else
    ipc.control(69632+375, 0x80000000)
    lastWXT = 0
  end
elseif (op == 7) then
  ipc.control(69632+110, 0x20000000)
elseif (op == 8) then
  ipc.control(69632+110, 0x80000000)
elseif (op == 9) then
  local isOn = ipc.readUB(0x64FA)
  if (isOn == 0) then
    ipc.control(69632+117, 0x20000000)
  end
elseif (op == 10) then
  local isOn = ipc.readUB(0x64FA)
  if (isOn ~= 0) then
    ipc.control(69632+117, 0x20000000)
  end
elseif (op == 11) then
  local isOn = ipc.readUB(0x6501)
  if (isOn == 0) then
    ipc.control(69632+124, 0x20000000)
  end
elseif (op == 12) then
  local isOn = ipc.readUB(0x6501)
  if (isOn ~= 0) then
    ipc.control(69632+124, 0x20000000)
  end
elseif (op == 13) then
  local isOn = ipc.readUB(0x6500)
  if (isOn ~= 2) then
    ipc.control(69632+123, 0x80000000)
    if (isOn == 0) then
      ipc.control(69632+123, 0x80000000)
    end
  end
elseif (op == 14) then
  local isOn = ipc.readUB(0x6500)
  if (isOn ~= 0) then
    ipc.control(69632+123, 0x20000000)
    if (isOn == 2) then
      ipc.control(69632+123, 0x20000000)
    end
  end
elseif (op == 15) then
  local isOn = ipc.readUB(0x6502)
  if (isOn == 0) then
    ipc.control(69632+125, 0x80000000)
  end
elseif (op == 16) then
  local isOn = ipc.readUB(0x6502)
  if (isOn ~= 0) then
    ipc.control(69632+125, 0x20000000)
  end
elseif (op == 17) then
  local isOn = ipc.readUB(0x64FF)
  if (isOn == 0) then
    ipc.control(69632+122, 0x20000000)
  end
elseif (op == 18) then
  local isOn = ipc.readUB(0x64FF)
  if (isOn ~= 0) then
    ipc.control(69632+122, 0x20000000)
  end
elseif (op == 19) then
  if (APMode == 0) then
    ipc.control(69632+384, 0x80000000)
    ipc.control(69632+384, 0x00020000)
  elseif (APMode == 1) then
    ipc.control(69632+376, 0x80000000)
    ipc.control(69632+376, 0x00020000)
  elseif (APMode == 2) then
    ipc.control(69632+390, 0x80000000)
    ipc.control(69632+376, 0x00020000)
  elseif (APMode == 3) then
    ipc.control(69632+401, 0x80000000)
    ipc.control(69632+376, 0x00020000)
  elseif (APMode == 4) then
    ipc.control(69632+400, 0x80000000)
    ipc.control(69632+376, 0x00020000)
  else
    ipc.log("Unknown APMode - " .. APMode)
  end
elseif (op == 20) then
  if (APMode == 0) then
    ipc.control(69632+384, 0x20000000)
    ipc.control(69632+384, 0x00080000)
  elseif (APMode == 1) then
    ipc.control(69632+376, 0x20000000)
    ipc.control(69632+376, 0x00080000)
  elseif (APMode == 2) then
    ipc.control(69632+390, 0x20000000)
    ipc.control(69632+390, 0x00080000)
  elseif (APMode == 3) then
    ipc.control(69632+401, 0x20000000)
    ipc.control(69632+401, 0x00080000)
  elseif (APMode == 4) then
    ipc.control(69632+400, 0x20000000)
    ipc.control(69632+400, 0x00080000)
  else
    ipc.log("Unknown APMode - " .. APMode)
  end
elseif ((op > 20) and (op < 26)) then
  APMode = op - 21
elseif (op == 26) then
  local isAP = logic.Or(ipc.readUB(0x6545), ipc.readUB(0x6547))
  if (isAP > 0) then
    ipc.control(70038, 1)
    ipc.sleep(250)
    ipc.control(70038, 0)
  else
    ipc.control(69632+402, 0x20000000)
  end
elseif (op == 27) then
  ipc.control(69632+397, 0x20000000)
elseif (op == 28) then
  ipc.control(69632+392, 0x20000000)
elseif (op == 29) then
  ipc.control(69632+395, 0x20000000)
elseif (op == 30) then
  ipc.control(69632+382, 0x20000000)
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
  ipc.log("Could not open HID -- polling/LED disabled")
else
  ipc.log("USB Device Connected, hnd=" .. hidHandle)
  HID_Poll(0)
  event.timer(50, "HID_Poll")
  ipc.log("Poll loop started")
end

event.param("HandleAPEvent")
event.terminate("HandleShutdown")
ipc.log("Registered PMDG 737 Button Handler")

ipc.control(65701, 32)
ipc.display("PMDG 737 Button Handler registered", 1, 8)
