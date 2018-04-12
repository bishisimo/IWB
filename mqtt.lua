--mqtt.lua
-----------------------------连接信息
local url = "118.89.106.236"
local port = 1883
local cliendId = "tester5"
local user = "tester5"
local psw = "tester"
---------------------------------------------------在这里添加订阅消息的主题
--订阅主题列表
subTopic = "master_computer"
---------------------------------------------------在这里添加发布消息的主题
--发布主题列表
pubTopic = "slave_computer"
----------------------------------------------------
--              ID        建立连接的时间 s  用户名      密码
m = mqtt.Client(DeviceID, 180, ProductID, AuthInfo) --创建MQTT客户机
m:on(
    "connect",
    function(client) --连接成功
        print("MQTT Server Connected")
    end
)
m:on(
    "offline",
    function(client) --下线
        print("MQTT Server Offline")
    end
)
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
--------------------------------------------------------------------
m:connect(
    url,
    port,
    0,
    1,
    function(client)
        print("IOT MQTT Server Connected")
        subscribe()
        subscribe = nil
        collectgarbage()
        --订阅预设的主题
    end,
    function(client, reason)
        print("Failed reason: " .. reason)
    end
)
--------------------------------------------------------------------
function subscribe() --订阅,无需修改
    m:subscribe(
        subTopic,
        0,
        function(client)
            print("Subscribe topic ", subTopic, " success")
        end
    )
end
---------------------------------------------------------------------
---------------------------------------------------------------------
---------------------------------------------------------------------
function publish(pubTopic, data) --!!!发布消息,在串口回调里使用此接口将调试信息发送至主题!!!
    m:publish(
        pubTopic,
        data,
        1,
        0,
        function(client)
        end
    )
end
---------------------------------------------------------------------
---------------------------------------------------------------------
function pubStream(stream) --上传数据流
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
    local webData = sjson.encoder(data)
    local ok, buf = pcall(webData.read, webData)
    if ok and m ~= nil then
        m:publish(
            "$dp",
            buf,
            1,
            0,
            function(client)
            end
        )
    end
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
function data_handle(topic, datas) --解析并执行指令,修改这里完善接口
    -- print("@data_handle",type(datas),datas)
    if type(datas) == table then
        for _, data in pairs(datas) do
            data_handle_base(data)
        end
    else
        data_handle_base(datas)
    end
end

function data_handle_base(data)
    -- if type(data)=="table"then
    --     for k,v in pairs(data) do
    --         print("@data_handle_base",k,v)
    --     end
    -- else
    --     print("@data_handle_base",data)
    -- end

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
        -- timer_updata = nil
        -- timer_control = nil
        work_enable = false
        write_slave({SRUN = 1})
        -- print("@work_enable",work_enable)
        -- work_enable = false
        -- print("@mqtt",type(timer_updata),timer_updata)
        -- print("@mqtt",type(timer_control),timer_control)
        if timer_updata then
            tmr.unregister(timer_updata)
        end
        if timer_control then
            tmr.unregister(timer_control)
        end
    elseif data.cmd == "run" then
        write_slave({SRUN = 0})
    elseif data.cmd == "test" then
        print(data.cmd)
        publish(pubTopic, "test success!")
    end

    if data.read_mark then --读信息
        print("@read_mark:",data.read_mark)
        read_slave(data.read_mark)
        readMark_enable = true
    end
    ------------------------------------------------
    --写信息
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
        for k in pairs(work_process) do
            if data.work_process[k] then
                work_process[k] = data.work_process[k]
            end
        end
        work_enable = true
        if data.work_process.appointment then
            appointment_handle() --预约
        else
            execute() --立即执行
        end
    end
end
