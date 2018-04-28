--mqtt.lua
-----------------------------连接信息
-- local url = "118.89.106.236"
-- local port = 1883
-- local cliendId = "tester5"
-- local user = "tester5"
-- local psw = "tester"
---------------------------------------------------在这里添加订阅消息的主题
--订阅主题列表
subTopic = "master_computer"
---------------------------------------------------在这里添加发布消息的主题
--发布主题列表
pubTopic = "slave_computer"
----------------------------------------------------
--              ID        建立连接的时间  用户名      密码
function mqtt_init()
    local mqtt_config = require("config").mqtt
    m = mqtt.Client(mqtt_config.cliendId, 180, mqtt_config.user, mqtt_config.psw) --创建MQTT客户端
    -- m:on(
    --     "connect",
    --     function(client) --连接成功
    --         print("MQTT Server Connected")
    --     end
    -- )
    -- m:on(
    --     "offline",
    --     function(client) --下线
    --         print("MQTT Server Offline")
    --     end
    -- )
    m:on(
        "message",
        function(client, topic, data) --接收消息回掉函数
            if data ~= nil then --接收到数据
                local decoder = sjson.decoder() --实例化decoder对象
                ok, info = pcall(decoder.write, decoder, data) --安全执行函数
                if ok then
                    data_handle(topic, info)
                else
                    data_handle(topic, data)
                end
            end
        end
    )
    mqtt_init = nil
end

function mqtt_connect()
    -- if not m then
    local mqtt_config = require("config").mqtt
    m:connect(
        mqtt_config.url,
        1883,
        function(client)
            print("IOT MQTT Server Connected")
            m:subscribe(subTopic,0) --订阅预设的主题
        end
        -- function(client, reason)
        --     print("Failed reason: " .. reason)
        --     m:close()
        -- end
    )
    -- end
end
--------------------------------------------------------------------
--------------------------------------------------------------------
-- function subscribe() --订阅,无需修改
--     m:subscribe(subTopic)
-- end
---------------------------------------------------------------------
---------------------------------------------------------------------
---------------------------------------------------------------------
function publish(pubTopic, data) --!!!发布消息,在串口回调里使用此接口将调试信息发布至主题!!!
    if m then
        m:publish(pubTopic, data, 0, 0)
    end
end
---------------------------------------------------------------------
---------------------------------------------------------------------
function pubStream(stream) --上传数据
    -- local tableTime = rtctime.epoch2cal(rtctime.get())
    local data = {}
    data.measurement = "Temperature"
    data.tags = {device = node.chipid()}
    data.fields = stream
    -- if tableTime.year ~= 1970 then
    --     local time_Now =
    --         tableTime.year ..
    --         "-" ..
    --             tableTime.mon ..
    --                 "-" .. tableTime.day .. ";" .. tableTime.hour + 8 .. ":" .. tableTime.min .. ":" .. tableTime.sec
    --     data[1].fields.timeNow = time_Now
    -- end
    -------------------------------------------------------
    --将格式表打包成JSON并上传数据流
    local jsonData = sjson.encoder(data)
    -- local buf = jsonData:read()
    publish("$dp", jsonData:read())
    --------------------------------------------------------
    -- if tableTime.year ~= 1970 then
    --     return jsonData
    -- else
    --     return nil
    -- end
end
---------------------------------------------------------------------
---------------------------------------------------------------------
--[[JSON命令格式举例:
{"cmd":"uart_enter"}
{"test":"this is just test"}
{"cmd":"uart_enter","test":"this is just test"}
]]
function data_handle(topic, data) --解析并执行指令,修改这里完善接口
    if data.cmd == "OTA" then --空中升级
        if data.fileFlag ~= nil and data.fileFlag == "start" then
            fileOTA = file.open(data.fileName, "w")
        end
        fileOTA:write(data.data)
        if data.fileFlag ~= nil and data.fileFlag == "end" then
            fileOTA:flush()
            fileOTA:close()
            while true do
                node.restart()
            end
        end
    elseif data.cmd == "stop" then
        stop_work()
    elseif data.cmd == "run" then
        only_run()
    elseif data.cmd == "test" then
        print(data.cmd)
        publish(pubTopic, "test success!")
    end

    if data.read_mark then --读取信息
        print("@read_mark:", data.read_mark)
        read_slave(data.read_mark)
        readMark_enable = true
    end
    ------------------------------------------------
    --写入信息
    --arg:{"write_mark":{"SV":"60","P":"25"}}
    ------------------------------------------------
    if data.write_mark then
        write_slave(data.write_mark)
    end
    ------------------------------------------------
    --设置工作任务
    --arg:{"work_process":[{"SV":"60"},{"setTime":"10"},{"appointment":"1"}]}
    ------------------------------------------------
    if data.work_process then
        stop_work()
        start_work(data)
    end
end
