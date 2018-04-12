--init.lua
-------------------------------------------
local function saveCfgSTA(ssid, psw)
    file.open("config.lua", "w+")
    file.writeline("cfgSTA={}")
    file.writeline("cfgSTA.ssid='" .. ssid .. "'")
    file.writeline("cfgSTA.psw='" .. psw .. "'")
    --file.writeline('station_cfg.save=true')
    file.writeline("return cfgSTA")
    file.flush()
    file.close()
    -- compile("config.lua")
end
-------------------------------------------
function saveTime()
    local mTime = {}
    mTime.sec, mTime.usec = rtctime.get()
    file.open("time.lua", "w+")
    file.writeline("mTime={}")
    file.writeline("mTime.sec='" .. mTime.sec .. "'")
    file.writeline("mTime.usec='" .. mTime.usec .. "'")
    file.writeline("return mTime")
    file.flush()
    file.close()
    -- compile("time.lua")
end
-------------------------------------------
local function startSTA()
    -- wifi.eventmon.register(
    --     wifi.eventmon.STA_CONNECTED,
    --     function(T)
    --         print(
    --             "\n\tSTA - CONNECTED" ..
    --                 "\n\tSSID: " .. T.SSID .. "\n\tBSSID: " .. T.BSSID .. "\n\tChannel: " .. T.channel
    --         )
    --     end
    -- )

    -- wifi.eventmon.register(
    --     wifi.eventmon.STA_DISCONNECTED,
    --     function(T)
    --         print(
    --             "\n\tSTA - DISCONNECTED" ..
    --                 "\n\tSSID: " .. T.SSID .. "\n\tBSSID: " .. T.BSSID .. "\n\treason: " .. T.reason
    --         )
    --         --smart()
    --     end
    -- )

    -- wifi.eventmon.register(
    --     wifi.eventmon.STA_AUTHMODE_CHANGE,
    --     function(T)
    --         print(
    --             "\n\tSTA - AUTHMODE CHANGE" ..
    --                 "\n\told_auth_mode: " .. T.old_auth_mode .. "\n\tnew_auth_mode: " .. T.new_auth_mode
    --         )
    --     end
    -- )

    -- wifi.eventmon.register(
    --     wifi.eventmon.STA_DHCP_TIMEOUT,
    --     function()
    --         print("\n\tSTA - DHCP TIMEOUT")
    --         smart()
    --     end
    -- )

    wifi.eventmon.register(
        wifi.eventmon.STA_GOT_IP,
        function()
            print("STATION_GOT_IP")
            print("staIP:" .. wifi.sta.getip())
            sntp.sync(
                "ntp1.aliyun.com",
                function(sec, usec, server, info)
                    print("Time calibration success")
                    saveTime()
                    print('@heap:',node.heap())
                end,
                function(code, info)
                    print("Time calibration failure->code:", code, "info:", info)
                    require("time")
                    rtctime.set(mTime.sec, mTime.usec)
                end,
                1
            )
            do_lua_or_lc("mqtt")
            do_lua_or_lc = nil
            collectgarbage()
        end
    )
    wifi.sta.config(cfgSTA)
end
-------------------------------------------
local function smart() --配置WiFi信息
    print("ESPTOUCH Star, Open APP IOT_Espressif_EspTouch")
    wifi.startsmart(
        0,
        function(ssid, password)
            saveCfgSTA(ssid, password)
            print(string.format("SmartConfig Success!!!\nSSID:%s; PASSWORD:%s", ssid, password))
            startSTA()
        end
    )
end
-----------------------------------------------------------------------------------------------------------

function do_lua_or_lc(fileName)
    if file.exists(fileName .. ".lua") then
        dofile(fileName .. ".lua")
    elseif file.exists(fileName .. ".lc") then
        dofile(fileName .. ".lc")
    else
        print(fileName, "not exists!")
    end
end
-----------------------------------------------------------------------------------------------------------
i2c.setup(0, 1, 2, i2c.SLOW)
require("wk2142")
Wk2142Init()
Wk2142Init=nil
collectgarbage()
-----------------------------------------
-- gpio.mode(0, gpio.OUTPUT)
-- gpio.write(0, gpio.HIGH)
----------------------配置WIFI---------------------
wifi.setmode(wifi.STATION)
if file.exists("config.lc") then
    require("config")
    print("#start turn on wifi...please wait...")
    startSTA()
else
    print("no config file found")
    smart()
end
----------初始化GPIO--------------------------------
require("slave")
require("process")
do_lua_or_lc("uart")
RS485_RE = 0
gpio.mode(RS485_RE, gpio.OUTPUT)
hmi_send("page1.sv.val",0)
hmi_send("page1.cv.val",0)
write_slave({SRUN = 1})
collectgarbage()