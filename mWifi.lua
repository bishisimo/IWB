-- wifi_auth_enable=false
function wifi_init()
    -- print("#start turn on wifi...please wait...")
    -- wifi.setmode(wifi.STATION)
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
        wifi.eventmon.STA_DISCONNECTED,
        function(T)
            if m then
                m:close()
            end
            -- if wifi_auth_enable then
            -- wifi_auth_enable=false
            -- print("@STA_DISCONNECTED")
            offline()
            -- wifi_auth()
            -- end
        end
    )

    wifi.eventmon.register(
        wifi.eventmon.STA_GOT_IP,
        function()
            online()
            adjust_time()
            mqtt_connect()
        end
    )

    local sta = {}
    -- wifi.sta.config(require("config").wifi)
    sta.ssid, sta.pwd = wifi.sta.getdefaultconfig()
    wifi.sta.config(sta)
    -- wifi_auth()
    wifi_init = nil
end

-- function wifi_auth()
--     -- print("@wifi_auth")
--     -- wifi.setmode(wifi.STATIONAP)
--     -- wifi.ap.config({ssid = "IOT", auth = wifi.OPEN})
--     -- enduser_setup.manual(true)
--     enduser_setup.start(
--         -- function()
--         --     print("@enduser_setup success")
--         -- end,
--         -- function(err, str)
--         --     print("enduser_setup: Err #" .. err .. ": " .. str)
--         -- end
--     )
-- end

function adjust_time()
    sntp.sync("ntp1.aliyun.com", save_time, read_time, 1)
end
function save_time(sec) --, usec, server, info
    print("Time calibration success")
    file.open("time.lua", "w+")
    file.writeline("local sec=" .. sec .. " return sec")
    file.close()
end
function read_time()
    local timestamp = require("time")
    if timestamp > rtctime.get() then
        rtctime.set(timestamp)
    else
        save_time(rtctime.get())
    end
end
