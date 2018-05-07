--init.lua
----------------------加载模块--------------------
require("wk2142")   --加载IIC转串口逻辑
require("mMqtt")     --加载MQTT逻辑
require("mWifi")     --加载WiFi逻辑
require("process")  --加载处理逻辑
require("slave")    --加载温控逻辑
read_time()
----------------------配置wk串口------------------
wk_init()
----------------------注册串口事件-----------------
dofile("uart.lc")
----------------------配置MQTT--------------------
mqtt_init()
----------------------配置WIFI--------------------
wifi_init()
---------------------初始化温控模块----------------
offline()
RS485_RE = 0
gpio.mode(RS485_RE, gpio.OUTPUT)
stop_work()
collectgarbage("collect")
