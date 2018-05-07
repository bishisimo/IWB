work_process = {}
work_process.SV = 0
work_process.setTime = 0
work_process.appointment = 0
work_enable = false
is_working = false
is_online = false

function updataorsave()
    if is_online then
        pubStream(datapoint)
    else
        local encoder = sjson.encoder(datapoint)
        if file.exists("" .. datapoint.id) then
            file.open("" .. datapoint.id, "a")
            file.writeline(encoder:read())
            file.close()
        else
            file.open("" .. datapoint.id, "w")
            file.writeline(encoder:read())
            file.close()
        end
    end
end

-- function saveLog(data)
--     if file.exists("" .. datapoint.id) then
--         file.open("" .. datapoint.id, "a")
--         file.writeline(data)
--         file.close()
--     else
--         file.open("" .. datapoint.id, "w")
--         file.writeline(data)
--         file.close()
--     end
-- end

function online()
    is_online = true
    hmi_send("page0.t2.bco", 2047)
    hmi_send("page0.t2.txt", "online")
end

function offline()
    is_online = false
    hmi_send("page0.t2.bco", 64528)
    hmi_send("page0.t2.txt", "offline")
end

function only_run()
    write_slave({SRUN = 0})
    is_working = true
    hmi_send("page0.bt0.val", 1)
    hmi_send("page0.bt0.txt", "Turn OFF")
    local jsonData = sjson.encoder({state = 1})
    publish(pubTopic, jsonData:read())
end

function stop_work()
    datapoint.end_time=datapoint.cur_time
    work_enable = false
    exe_enable = false
    work_process.setTime = 0
    work_process.appointment = 0
    if timer_updata then
        timer_updata:unregister(timer_updata)
        updataorsave()
    end
    if timer_control then
        timer_control:unregister()
    end
    write_slave({SRUN = 1})
    is_working = false
    hmi_send("page1.sv.val", 0)
    hmi_send("page1.pv.val", 0)
    hmi_send("page1.cv.val", 0)
    hmi_send("page0.bt0.val", 0)
    hmi_send("page0.bt0.txt", "Turn ON")
    local jsonData = sjson.encoder({state = 0})
    publish(pubTopic, jsonData:read())
end

function start_work(data)
    -- print("@start_work")
    if data then
        for k in pairs(work_process) do
            if data.work_process[k] then
                work_process[k] = data.work_process[k]
            end
        end
    end
    work_enable = true
    is_working = true
    print("@appointment,working...")
    hmi_send("page0.bt0.val", 1)
    hmi_send("page0.bt0.txt", "Waiting")
    local jsonData = sjson.encoder({state = 2})
    publish(pubTopic, jsonData:read())
    tmr.create():alarm(
        work_process.appointment * 1000 * 60 + 1000,
        tmr.ALARM_SINGLE,
        function()
            if work_enable then
                print("@immediately,working...")
                hmi_send("page0.bt0.val", 1)
                hmi_send("page0.bt0.txt", "Turn OFF")
                hmi_send("page1.sv.val", work_process.SV)
                read_slave("SV")
                work_enable = false
                exe_enable = true
                local jsonData = sjson.encoder({state = 1})
                publish(pubTopic, jsonData:read())
            end
        end
    )
end
