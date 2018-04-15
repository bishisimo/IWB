----------------------------向温控模块读数据----------------------------
--[[

    网络发送格式  {"read_mark":"HIAL"}
    更新为:{"read_mark":"P"}
    地址代号+52H（82）+要读的参数代号+0+0+校验码
    校验码: 要读参数的代号×256+82+ADDR   低字节在前，高字节在后

--]]
function read_slave(target)
    local mark = mark_analysis(target)
    send_handle(mark)
end

-------------------------向温控模块写数据-------------------------------
--[[

    网络发送格式  {"write_mark":"HIAL","write_value":"16"}
    更新为:{"write_mark":{"SV":50}}->{SV=50}
    地址代号+43H（67）+要写的参数代号+写入数低字节+写入数高字节+校验码
    效验码： 要写的参数代号×256+67+要写的参数值+ADDR
            低字节在前，高字节在后
--]]
function write_slave(data)
    local mark = 0 --参数代号)
    local list = {}
    for k, v in pairs(data) do
        table.insert(list, k)
    end
    tmr.create():alarm(
        200,
        tmr.ALARM_SEMI,
        function(t)
            -- local index=list[i]
            -- print('@data1',data.SV)
            -- print('...@data2',data.index)
            if #list > 0 then
                local key = table.remove(list, 1)
                mark = mark_analysis(key)
                -- print("@mark:",mark)
                if mark == 0x1b then
                    send_handle(mark, data[key])
                else
                    send_handle(mark, data[key] * 10)
                end
                t:start()
            end
        end
    )
    -- for k, v in pairs(data) do
    --     -------------------解析命令---------------------
    --     mark = mark_analysis(k)
    --     send_handle(mark, v * 10)
    --     tmr.delay(100000)
    --     --温控仪单位为 0.1度  故扩大10倍
    -- end
end
--------------------------------将功能转换成地址--------------------------------
function mark_analysis(target)
    local mark = 0
    if target == "SV" then
        mark = 0x00 --设定值
    elseif target == "HIAL" then
        mark = 0x01 --上限报警
    elseif target == "LOAL" then
        mark = 0x02 --下限报警
    elseif target == "HDAL" then
        mark = 0x03 --偏差上限报警
    elseif target == "LDAL" then
        mark = 0x04 --偏差下限报警
    elseif target == "AHYS" then
        mark = 0x05 --报警回差
    elseif target == "CTRL" then
        mark = 0x06 --Ctrl控制方式
    elseif target == "P" then
        mark = 0x07 --P
    elseif target == "I" then
        mark = 0x08 --I
    elseif target == "D" then
        mark = 0x09 --D
    elseif target == "INP" then
        mark = 0X0B --输入规格
    elseif target == "SRUN" then 
        mark = 0X1B --运行状态 --0，run；1，StoP；2，HoLd
    elseif target == "CHYS" then
        mark = 0x1C --控制回差（死区）
    elseif target == "AT" then
        mark = 0X1D --自整定选择 0：OFF 1：on  2：FoFF
    end
    return mark
end
--------------------------------发送数据--------------------------------
function send_handle(mark, value)
    local data = {}
    --read:checkout = mark * 256 + 0x52 + 0x01
    --writ:checkout = mark * 256 + 0x43 + value + 0x01
    local checkout = value and (mark * 256 + 0x43 + value + 0x01) or mark * 256 + 0x52 + 0x01
    local address = value and 0x43 or 0x52
    data[1]=0x81
    data[2]=0x81
    data[3]=address
    data[4]=mark
    data[5]=value and bit.clear(value, 8, 9, 10, 11, 12, 13, 14, 15) or 0x00
    data[6]=value and bit.rshift(value, 8) or 0x00
    data[7]=bit.clear(checkout, 8, 9, 10, 11, 12, 13, 14, 15)
    data[8]=bit.rshift(checkout, 8)
    gpio.write(RS485_RE, gpio.HIGH) --拉高RE引脚
    tmr.create():alarm(
        10,
        tmr.ALARM_SEMI,
        function(t)
            if #data > 0 then
                uart1_send(table.remove(data, 1))
                t:start()
            else
                gpio.write(RS485_RE, gpio.LOW) --拉低RE引脚
            end
        end
    )
    
end
