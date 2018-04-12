work_process = {}
work_process.SV = 0
work_process.setTime=false
work_process.appointment=false

function saveLog(s)
    file.open("log", "a")
    file.writeline(s)
    file.flush()
    file.close()
end
--预约执行
function appointment_handle()
    local time = work_process.appointment * 1000
    print("@appointment,working...")
    tmr.create():alarm(
        time,
        tmr.ALARM_SINGLE,
        function()
            if work_enable then
                execute()
            end
        end
    )
end

--执行
function execute()
    print("@immediately,working...")
    hmi_send("page1.sv.val" , work_process.SV)
    read_slave("SV")
    exe_enable=true
end