receive_analysis_result = {}
recv_ready = false
recv_enable = false
datapoint = {}
readMark_enable = false --读数据使能
exe_enable = false --加热程序使能
updata_enable = false --上传数据使能
gpio.trig(
    3,
    "down",
    function()
        if bit.band(Wk2142ReadReg(1, 0x0B), 0x08) ~= 0 then
            
            local data = {}
            local len = Wk2142ReadReg(1, 0x0a)
            print("@len1", len)
            for i = 1, len do
                data[i] = Wk2142ReadReg(1, 0x0d)
                -- print("1->", data[i], ":", string.char(data[i]))
            end
            if len == 10 then
                ---------------------------------------------------------------------------------------------------------------
                receive_analysis_result.PV = (bit.lshift(data[2], 8) + data[1]) * 0.1
                receive_analysis_result.SV = (bit.lshift(data[4], 8) + data[3]) * 0.1
                receive_analysis_result.OB = (bit.lshift(data[8], 8) + data[7]) * 0.1
                --------------------------------------------------------------------------------
                if readMark_enable then --如果启用读数据
                    local webData = sjson.encoder(receive_analysis_result)
                    local ok, jsonData = pcall(webData.read, webData)
                    if ok then
                        publish(pubTopic, jsonData) --通过主题发布
                    end
                    readMark_enable = false
                end
                ---------------------------------------------------------------------------------
                ---------------------------------------------------------------------------------
                --[初始化
                if exe_enable then
                    datapoint.start_time = 0
                    datapoint.cur_time = 0
                    datapoint.end_time = 0
                    datapoint.SV = 0
                    datapoint.CV = 0
                    datapoint.PV = 0
                    local target_process = {}
                    local times = 10
                    local interval = 1
                    --插补算法控制加热曲线
                    datapoint.PV = receive_analysis_result.PV
                    datapoint.SV = work_process.SV
                    if work_process.setTime then    --如果设定了加温时间
                        local per_tem = (work_process.SV - datapoint.PV) / work_process.setTime    --计算间隔温度
                        interval = work_process.setTime / times    --计算每次调整温度间隔时间
                        print("@interval",interval)
                        for i = 1, times do
                            table.insert(target_process, per_tem * interval * i + datapoint.PV)
                            print("@target_process", target_process[i])
                        end
                    else
                        table.insert(target_process, datapoint.SV)
                    end
                    datapoint.CV = target_process[1] + 0.001
                    datapoint.start_time = tmr.time()
                    datapoint.end_time = 0
                    --初始化]]
                    ------------------------------------------------------------------------
                    --[开启数据点上报
                    timer_updata = tmr.create()
                    --创建定时器,读当前温度并上传
                    timer_updata:alarm(
                        5000,
                        tmr.ALARM_SEMI,
                        function(t)
                            read_slave("SV")
                            updata_enable = true
                            t:start()
                        end
                    )
                    --开启数据点上报]
                    ------------------------------------------------------------------------
                    --[下位机执行
                    hmi_send("page1.cv.val", target_process[1])
                    write_slave({SV = table.remove(target_process, 1), SRUN = 0})
                    --分段写入
                    if #target_process > 0 then --需要多次写入时,按时间间隔重设定温度
                        print("@#target_process", #target_process)
                        timer_control = tmr.create()
                        timer_control:alarm(
                            interval * 60000,
                            tmr.ALARM_SEMI,
                            function(t)
                                if #target_process > 0 then
                                    hmi_send("page1.cv.val", target_process[1])
                                    datapoint.CV = target_process[1] + 0.001
                                    write_slave({SV = table.remove(target_process, 1)})
                                    t:start()
                                end
                            end
                        )
                    end
                    --下位机执行]
                    exe_enable = false
                end
                ------------------------------------------------------------------------
                --上传数据点
                ------------------------------------------------------------------------
                if updata_enable then
                    datapoint.PV = receive_analysis_result.PV + 0.001
                    hmi_send("page1.pv.val", datapoint.PV)
                    datapoint.cur_time = tmr.time() - datapoint.start_time
                    -- print("@curtime", datapoint.cur_time)
                    local encoder = sjson.encoder(datapoint)
                    local ok, jsonData = pcall(encoder.read, encoder)
                    if ok then
                        saveLog(jsonData)
                    end
                    pubStream(datapoint)
                    updata_enable = false
                end
            else
                read_slave("SV")
            end
        end
        -- print("1->", recv_ready, ":", data)
        ------------------------------------------------------------------
        ------------------------------------------------------------------
        if bit.band(Wk2142ReadReg(2, 0x0B), 0x08) ~= 0 then
            local data = {}
            local len = Wk2142ReadReg(2, 0x0a)
            print("@len2", len)
            for i = 1, len do
                data[i] = Wk2142ReadReg(2, 0x0d)
                print("2->", data[i], ":", string.char(data[i]))
            end
        end
    end
)
