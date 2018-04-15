work_process = {}
work_process.SV = 0
work_process.setTime = false
work_process.appointment = 1
work_enable = false
function saveLog(s)
    file.open("log", "a")
    file.writeline(s)
    file.flush()
    file.close()
end

function only_run()
    write_slave({SRUN = 0})
    hmi_send("page0.bt0.val", 1)
    hmi_send("page0.bt0.txt", "运行中")
end

function stop_work()
    work_enable = false
    exe_enable = false
    work_process.setTime = false
    work_process.appointment = 1
    write_slave({SRUN = 1})
    if timer_updata then
        timer_updata:unregister(timer_updata)
    end
    if timer_control then
        timer_control:unregister()
    end
    hmi_send("page1.sv.val", 0)
    hmi_send("page1.pv.val", 0)
    hmi_send("page1.cv.val", 0)
    hmi_send("page0.bt0.val", 0)
    hmi_send("page0.bt0.txt", "空闲中")
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
    print("@appointment,working...")
    hmi_send("page0.bt0.txt", "预约中")
    tmr.create():alarm(
        work_process.appointment * 1000,
        tmr.ALARM_SINGLE,
        function()
            if work_enable then
                print("@immediately,working...")
                hmi_send("page0.bt0.val", 1)
                hmi_send("page0.bt0.txt", "运行中")
                hmi_send("page1.sv.val", work_process.SV)
                read_slave("SV")
                exe_enable = true
            end
        end
    )
end
