function wk_writeReg(dev_addr, reg_addr, data)
    local addr = 0x00 + bit.lshift(1, 5) + bit.lshift(dev_addr - 1, 2)
    i2c.start(0)
    --iic起始时序
    -- i2c.address(0, addr, i2c.TRANSMITTER)
    i2c.write(0, addr)
    --	IA1IA0为低电平,发送控制字节，
    i2c.write(0, reg_addr)
    --发送寄存器地址
    i2c.write(0, data)
    --发送需要写的数据
    i2c.stop(0)
    --iic结束时序
end
-- user defined function then read from reg_addr content of dev_addr
function wk_readReg(dev_addr, reg_addr)
    local addr = 0x00 + bit.lshift(1, 5) + bit.lshift(dev_addr - 1, 2)
    i2c.start(0)
    -- rck=i2c.address(0, addr, i2c.TRANSMITTER)
    -- print("rck",rck)
    i2c.write(0, addr)
    i2c.write(0, reg_addr)
    i2c.stop(0)
    -- tmr.delay(1000)
    i2c.start(0)
    -- rck=i2c.address(0, addr+1, i2c.RECEIVER)
    -- print("rck",rck)
    i2c.write(0, addr + 1)
    local c = i2c.read(0, 1)
    i2c.stop(0)
    return string.byte(c)
end

function wk_init()
    i2c.setup(0, 1, 2, i2c.SLOW)
    wk_writeReg(1, 0x00, 0x03) --使能子串口时钟
    wk_writeReg(1, 0x01, 0x03) --软件复位子串口
    wk_writeReg(2, 0x10, 0x03) --使能子串口中断，包括子串口总中断和子串口内部的接收中断，和设置中断触点
    ------------------------------------------------------------------------------
    wk_writeReg(1, 0x07, 0x03) -- 初始化FIFO和设置固定中断触点
    wk_writeReg(1, 0x06, 0XFF) --设置任意中断触点，如果下面的设置有效，那么上面FCR寄存器中断的固定中断触点将失效
    wk_writeReg(1, 0x03, 1) --切换到page1
    -- wk_writeReg(1, 0x07, 0X0a)--设置接收触点为64个字节
    -- wk_writeReg(1, 0x08, 0X10)--设置发送触点为16个字节
    --配置波特率(9600)
    wk_writeReg(1, 0x04, 0x00)
    wk_writeReg(1, 0x05, 0x47)
    --
    wk_writeReg(1, 0x03, 0) --切换到page0
    wk_writeReg(1, 0x04, 0x03) --使能子串口的发送和接收使能
    -------------------------------------------------------------------------------
    wk_writeReg(2, 0x07, 0x03) -- 初始化FIFO和设置固定中断触点
    wk_writeReg(2, 0x06, 0XFF) --设置任意中断触点，如果下面的设置有效，那么上面FCR寄存器中断的固定中断触点将失效
    wk_writeReg(2, 0x03, 1) --切换到page1
    -- wk_writeReg(2, 0x07, 0X06)--设置接收触点为6个字节
    -- wk_writeReg(2, 0x08, 0X10)--设置发送触点为16个字节
    --配置波特率(115200)
    wk_writeReg(2, 0x04, 0x00)
    wk_writeReg(2, 0x05, 0x05)
    --
    wk_writeReg(2, 0x03, 0) --切换到page0
    wk_writeReg(2, 0x04, 0x03) --使能子串口的发送和接收使能
    wk_init=nil
end

function uart_send(port, data)
    if type(data) == "string" then
        n = string.len(data)
        for i = 1, n do
            wk_writeReg(port, 0x0D, string.sub(data, i, i))
        end
    else
        wk_writeReg(port, 0x0D, data)
    end
end
function uart1_send(data)
    uart_send(1, data)
    -- print("@uart1:", string.format("%x", data))
end
function hmi_send(s,v)
    local data
    if type(v)=='number' then
        data=s..'='..math.floor(v)
    else
        data=s..'="'..v..'"'
    end
    uart_send(2, data)
    uart_send(2, 0xff)
    uart_send(2, 0xff)
    uart_send(2, 0xff)
end
