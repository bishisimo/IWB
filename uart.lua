receive_analysis_result = {}
datapoint = {}
readMark_enable = false --读数据使能
exe_enable = false --加热程序使能
updata_enable = false --上传数据使能
gpio.trig(
    3,
    "down",
    function()
        if bit.band(wk_readReg(1, 0x0B), 0x08) ~= 0 then
            local data = {}
            local len = wk_readReg(1, 0x0a)
            -- print("@len1", len)
            for i = 1, len do
                data[i] = wk_readReg(1, 0x0d)
                -- print("1->", data[i], ":", string.char(data[i]))
            end
            if len == 10 then
                ---------------------------------------------------------------------------------------------------------------
                receive_analysis_result.PV = (bit.lshift(data[2], 8) + data[1]) * 0.1
                receive_analysis_result.SV = (bit.lshift(data[4], 8) + data[3]) * 0.1
                receive_analysis_result.OB = (bit.lshift(data[8], 8) + data[7]) * 0.1
                --------------------------------------------------------------------------------
                if readMark_enable then --如果启用读数据
                    local jsonData = sjson.encoder(receive_analysis_result)
                    publish(pubTopic, jsonData:read()) --通过主题发布
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
                    if work_process.setTime then --如果设定了加温时间
                        local per_tem = (work_process.SV - datapoint.PV) / work_process.setTime --计算间隔温度
                        interval = work_process.setTime / times --计算每次调整温度间隔时间
                        -- print("@interval", interval)
                        for i = 1, times do
                            target_process[i] = per_tem * interval * i + datapoint.PV
                            print("@target_process", i, target_process[i])
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
                    timer_updata = tmr.create() --创建定时器,读当前温度并上传
                    timer_updata:alarm(
                        5000,
                        tmr.ALARM_SEMI,
                        function()
                            -- print("@timer_updata",timer_updata)
                            read_slave("SV")
                            updata_enable = true
                            timer_updata:start()
                        end
                    )
                    --开启数据点上报]
                    ------------------------------------------------------------------------
                    --[下位机执行
                    hmi_send("page1.cv.val", target_process[1])
                    write_slave({SV = table.remove(target_process, 1), SRUN = 0})
                    if #target_process > 0 then --需要多次写入时,按时间间隔重设定温度
                        -- print("@#target_process", #target_process)
                        timer_control = tmr.create()
                        timer_control:alarm(
                            interval * 60000,
                            tmr.ALARM_SEMI,
                            function()
                                if #target_process > 0 then
                                    -- print("@timer_control",timer_control)
                                    hmi_send("page1.cv.val", target_process[1])
                                    datapoint.CV = target_process[1] + 0.001
                                    write_slave({SV = table.remove(target_process, 1)})
                                    timer_control:start()
                                else
                                    datapoint.end_time = tmr.time()
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
                if updata_enable and m then
                    datapoint.PV = receive_analysis_result.PV + 0.001
                    hmi_send("page1.pv.val", datapoint.PV)
                    datapoint.cur_time = tmr.time() - datapoint.start_time
                    datapoint.time=rtctime.get()
                    local encoder = sjson.encoder(datapoint)
                    saveLog(encoder:read())
                    pubStream(datapoint)
                    updata_enable = false
                end
            else
                read_slave("SV")
            end
        end
        ------------------------------------------------------------------
        ------------------------------------------------------------------
        if bit.band(wk_readReg(2, 0x0B), 0x08) ~= 0 then
            local data = {}
            local len = wk_readReg(2, 0x0a)
            for i = 1, len do
                data[i] = wk_readReg(2, 0x0d)
            end
            if len == 1 then
                if data[1] == 1 then
                    only_run()
                else
                    stop_work()
                end
            elseif len == 5 then
                stop_work()
                work_process.SV = data[1]
                local setTime = (bit.lshift(data[3], 8) + data[2])
                local appointment = (bit.lshift(data[5], 8) + data[4])
                if setTime > 0 then
                    work_process.setTime = setTime
                end
                -- if appointment > 0 then
                    work_process.appointment = appointment
                -- end
                start_work()
            elseif len == 6 then
                if data[1] == 99 then
                    wifi.sta.clearconfig()
                    enduser_setup.start()
                end
            end
        end
    end
)
