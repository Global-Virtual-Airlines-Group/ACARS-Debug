
APMode = 0
lastLS = ""

btnCount = 0
updCount = 0
lastLED = 0

-- Joystick/HID data
Vendor = 0x294B
Product = 0x1901
hidHandle = 0 -- hid handle

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
      HandleAPEvent(14)
    elseif (bit == 30) then
      HandleAPEvent(15)
    elseif (bit == 29) then
      HandleAPEvent(16)
    elseif (bit == 28) then
      HandleAPEvent(17)
    elseif (bit == 27) then
      HandleAPEvent(18)
    elseif (bit == 26) then
      HandleAPEvent(19)
    elseif (bit == 25) then
      HandleAPEvent(20)
    elseif (bit == 24) then
      HandleAPEvent(21)
    elseif (bit == 23) then
      HandleAPEvent(22)
    elseif (bit == 22) then
      HandleAPEvent(23)
    elseif (bit == 21) then
      HandleAPEvent(24)
    elseif (bit == 20) then
      HandleAPEvent(25)
    end
  end
end

lastButtonOfs[lastButtonIdx] = v

end

function HandleShutdown()

event.cancel("HandleAPEvent")
if (hidHandle ~= 0) then
  event.cancel("HID_Poll")
  ipc.log("Poll loop stopped")
  ClearLED()
  com.close(hidHandle)
  ipc.log("USB Device (hnd=" .. hidHandle .. ") disconnected")
end

event.cancel("HandleShutdown")
ipc.log("CS757/767 Button Handler shutdown (" .. btnCount .. " buttons, " .. updCount .. " LED updates)")
ipc.exit()

end -- HandleShutdown

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

local isAP = ipc.readLvar("G03_024_LT0") + ipc.readLvar("G03_025_LT0") + ipc.readLvar("G03_026_LT0")
local AP_W = toggleLED(0, ipc.readLvar("G03_011_LT0"), 2)
AP_W = toggleLED(AP_W, ipc.readLvar("G03_020_LT0"), 16)
AP_W = toggleLED(AP_W, ipc.readLvar("G03_019_LT0"), 32)
AP_W = toggleLED(AP_W, ipc.readLvar("G03_006_SW2"), 64)
AP_W = toggleLED(AP_W, isAP, 128)

local g = { ipc.readUD(0x0BEC), ipc.readUD(0x0BF0), ipc.readUD(0x0BF4) } -- n,r,l
local LG_W = toggleLED(0, ipc.readLvar("G01_001_LT1"), 64)
LG_W = toggleLED(LG_W, fromb(g[1] > 16300), 4)
LG_W = toggleLED(LG_W, fromb(g[2] > 16300), 16)
LG_W = toggleLED(LG_W, fromb(g[3] > 16300), 1)
LG_W = toggleLED(LG_W, fromb((g[1] < 16300) and (g[1] > 10)), 8)
LG_W = toggleLED(LG_W, fromb((g[2] < 16300) and (g[2] > 10)), 32)
LG_W = toggleLED(LG_W, fromb((g[3] < 16300) and (g[3] > 10)), 2)

-- ipc.log(ipc.readLvar("O10_003_GL3") .. ' ' .. ipc.readLvar("O10_001_LT0") .. ' ' .. ipc.readLvar("O10_002_LT0"))

local apu = ipc.readLvar("O10_003_GL3") + ipc.readLvar("O10_001_LT0") + ipc.readLvar("O10_002_LT0")
local ai = ipc.readLvar("O06_009_LT0") + ipc.readLvar("O06_010_LT0") + ipc.readLvar("O06_005_LT0") + ipc.readLvar("O06_006_LT0")
local ai2 = ipc.readLvar("O14_001_LT2") + ipc.readLvar("O14_002_LT2") + ipc.readLvar("O14_003_LT2") + ipc.readLvar("O14_004_LT2")
local st = (ipc.readLvar("O15_005_GL5") == 0) or (ipc.readLvar("O15_006_GL5") == 0)
local ff = (ipc.readDBL(0x2020) < 550) or (ipc.readDBL(0x2120) < 550)
local op = ((ipc.readDBL(0x3B60) / 144) < 20) or ((ipc.readDBL(0x3AA0) / 144) < 20)
local hyd = ipc.readLvar("O04_001_LT0") + ipc.readLvar("O04_002_LT0") + ipc.readLvar("O04_003_LT0")

local ANN_W1 = toggleLED(0, ipc.readLvar("G01_001_LT2"), 32)
ANN_W1 = toggleLED(ANN_W1, hyd, 128)
ANN_W1 = toggleLED(ANN_W1, apu, 16)
ANN_W1 = toggleLED(ANN_W1, fromb(st), 8)
ANN_W1 = toggleLED(ANN_W1, ai + ai2, 4)
ANN_W1 = toggleLED(ANN_W1, fromb(ff), 2)
ANN_W1 = toggleLED(ANN_W1, fromb(op), 1)

local dV = {"ext757_door1_l", "ext757_door2_l", "ext757_door_cargo_1", "ext757_door_cargo_2", "ext757_door3_l", "ext757_door1_r", "ext757_door3_r"}
local d = 1
local isOpen = 0
while ((isOpen == 0) and (d < 8)) do
  isOpen = ipc.readLvar(dV[d])
  d = d + 1
end

local ANN_W2 = toggleLED(0, isOpen, 8)
ANN_W2 = toggleLED(ANN_W2, fromb(ipc.readUW(0x0BC8) > 32000), 2)

local ls = string.char(0) .. string.char(AP_W) .. string.char(LG_W) .. string.char(ANN_W1) .. string.char(ANN_W2)
if (ls ~= lastLS) then
  com.writefeature(hidHandle, ls, wrf)
  lastLS = ls
  updCount = updCount + 1
end

end -- UpdateLED

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
-- 6 = WX radar /terrain toggle
-- 7 = HDG
-- 8 = LNAV
-- 9 = APP
-- 10 = ALT HOLD
-- 11 = VS
-- 12 = IAS/MACH toggle
-- 13 = autopilot engage
-- 14 = Landing Light ON
-- 15 = Landing Light OFF
-- 16 = Taxi Light ON
-- 17 = Taxi Light OFF
-- 18 = Beacon ON
-- 19 = Beacon OFF
-- 20 = Strobes ON
-- 21 = Strobes OFF
-- 22 = Wing Light ON
-- 23 = Wing Light OFF
-- 24 = Logo Light ON
-- 25 = Logo Light OFF
-- 26 = Reverse #1
-- 27 = Reverse #2
-- 28 = setAPMode IAS
-- 29 = setAPMode CRS
-- 30 = setAPMode HDG
-- 31 = setAPMode VS
-- 32 = setAPMode ALT
-- 33 = increment
-- 34 = decrement

if (op == 0) then
  noop()
elseif (op == 1) then 
  ipc.writeLvar("G03_028_SW2", 1)
elseif (op == 2) then 
  ipc.writeLvar("G03_028_SW2", 0)
elseif (op == 3) then
  st = ipc.readLvar("G03_006_SW2")
  ipc.writeLvar("G03_006_SW2", math.abs(st - 1))
elseif (op == 4) then
  z = ipc.readLvar("P04_005_KN6")
  lmd = ipc.readLvar("P04_009_KN6")
  rmd = ipc.readLvar("P20_009_KN6")
  ipc.writeLvar("P04_005_KN6", math.min(z + 1, 6))
  ipc.writeLvar("P20_005_KN6", math.min(z + 2, 6))
  if (lmd ~= 4) then
    ipc.writeLvar("P04_009_KN6", 4)
  end
  if (rmd ~= 4) then
    ipc.writeLvar("P20_009_KN6", 4)
  end
elseif (op == 5) then
  z = ipc.readLvar("P04_005_KN6")
  lmd = ipc.readLvar("P04_009_KN6")
  rmd = ipc.readLvar("P20_009_KN6")
  ipc.writeLvar("P04_005_KN6", math.max(z - 1, 0))
  ipc.writeLvar("P20_005_KN6", math.max(z, 1))
  if (lmd ~= 4) then
      ipc.writeLvar("P04_009_KN6", 4)
  end
  if (rmd ~= 4) then
      ipc.writeLvar("P20_009_KN6", 4)
  end
elseif (op == 6) then
  ipc.writeLvar("KLID", 2604010)
elseif (op == 7) then
  ipc.writeLvar("KLID", 1703016)
elseif (op == 8) then
  ipc.writeLvar("G03_011_BUT", 1)
elseif (op == 9) then
  ipc.writeLvar("G03_023_BUT", 1)
elseif (op == 10) then
  ipc.writeLvar("G03_020_BUT", 1)
elseif (op == 11) then
  ipc.writeLvar("G03_019_BUT", 1)
elseif (op == 12) then
  ipc.writeLvar("KLID", 1703009)
elseif (op == 13) then
  ipc.writeLvar("G03_025_BUT", 1)
elseif (op == 14) then
  ipc.writeLvar("O20_007_SW2", 1)
  ipc.writeLvar("O20_006_SW2", 1)
  ipc.writeLvar("O20_005_SW2", 1)
elseif (op == 15) then
  ipc.writeLvar("O20_007_SW2", 0)
  ipc.writeLvar("O20_006_SW2", 0)
  ipc.writeLvar("O20_005_SW2", 0)
elseif (op == 16) then
  ipc.writeLvar("O12_006_SW2", 1)
  ipc.writeLvar("O12_007_SW2", 1)
  ipc.writeLvar("O12_008_SW2", 1)
elseif (op == 17) then
  ipc.writeLvar("O12_006_SW2", 0)
  ipc.writeLvar("O12_007_SW2", 0)
  ipc.writeLvar("O12_008_SW2", 0)  
elseif (op == 18) then
  ipc.writeLvar("O20_002_BUT", 1)
elseif (op == 19) then
  ipc.writeLvar("O20_002_BUT", 0)
elseif (op == 20) then
  ipc.writeLvar("O20_003_BUT", 1)
elseif (op == 21) then
  ipc.writeLvar("O20_003_BUT", 0)
elseif (op == 22) then
  ipc.writeLvar("O20_004_BUT", 1)
elseif (op == 23) then
  ipc.writeLvar("O20_004_BUT", 0)
elseif (op == 24) then
  ipc.writeLvar("O26_004_BUT", 1)
elseif (op == 25) then
  ipc.writeLvar("O26_004_BUT", 0)
elseif (op == 26) then
  local r1 = ipc.readSW(0x089a)
  if (r1 > -4000) then
    ipc.writeSW(0x89a, (r1 - 400))
  end
elseif (op == 27) then
  local r2 = ipc.readSW(0x0924)
  if (r2 > -4000) then
    ipc.writeSW(0x0924, (r2 - 400))
  end
elseif ((op > 27) and (op < 33)) then
  local oldAP = APMode
  APMode = op - 28
elseif (op == 33) then
  if (APMode == 0) then
    ipc.writeLvar("KLID", 1703010)
  elseif (APMode == 1) then
    ipc.writeLvar("KLID", 1702006)
  elseif (APMode == 2) then
    ipc.writeLvar("KLID", 1703015)
  elseif (APMode == 3) then
    ipc.writeLvar("KLID", 1703018)
  elseif (APMode == 4) then
    ipc.writeLvar("KLID", 1703021)
  else
    ipc.log("Unknown APMode - " .. APMode)
  end
elseif (op == 34) then
  if (APMode == 0) then
    ipc.writeLvar("KLID", -1703010)
  elseif (APMode == 1) then
    ipc.writeLvar("KLID", -1702006)
  elseif (APMode == 2) then
    ipc.writeLvar("KLID", -1703015)
  elseif (APMode == 3) then
    ipc.writeLvar("KLID", -1703018)
  elseif (APMode == 4) then
    ipc.writeLvar("KLID", -1703021)
  else
    ipc.log("Unknown APMode - " .. APMode)
  end
else
  ipc.log("Unknown parameter - " .. op)
end

-- Reset parameter
if (op > 0) then
  btnCount = btnCount + 1
  ipcPARAM = 0
end

end

-- First, we need to get the device
hidHandle, rd, wrf, wr, hidInit = com.openhid(Vendor, Product, 0, 0)
if (hidHandle == 0) then
  ipc.log("Could not open HID -- polling disabled")
else
  ipc.log("USB Device Connected (hnd=" .. hidHandle .. ")")
  HID_Poll(0)
  event.timer(50, "HID_Poll")
  ipc.log("Poll loop started")
end

event.param("HandleAPEvent")
event.terminate("HandleShutdown")
ipc.log("Registered CS757/767 Button Handler")

ipc.control(65701, 32)
ipc.display("CS757/767 Button Handler registered", 1, 8)
