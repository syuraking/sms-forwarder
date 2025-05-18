-- LuaTools需要PROJECT和VERSION这两个信息
PROJECT = "sms_forwarding"
VERSION = "1.0.6"

log.info("main", PROJECT, VERSION)

--使用哪个推送服务
--可选：serverChan/pushplus/wxpusher

local useServer = "wxpusher"
--server酱的配置，用不到可留空，免费用户每天仅可发送五条推送消息
--server酱的SendKey，如果你用的是这个就需要填一个
--https://sct.ftqq.com/sendkey 申请一个
local serverKey = ""

--pushplus配置，用不到可留空，填入你的pushplus token
local pushplusToken = ""

--wxpusher配置，用不到可留空，填入你的WxPusher token
local wxpusherToken = ""
--此wxtopicid是在应用里的主题管理中创建的主题ID，并不是应用ID，请注意 
local wxtopicid = ""

--缓存消息
local buff = {}

-- 引入必要的库文件(lua编写), 内部库不需要require
sys = require("sys")
require "sysplus" -- http库需要这个sysplus

if wdt then
    --添加硬狗防止程序卡死，在支持的设备上启用这个功能
    wdt.init(9000)--初始化watchdog设置为9s
    sys.timerLoopStart(wdt.feed, 3000)--3s喂一次狗
end

log.info("main", "短信转发服务工作中...")

--运营商给的dns经常抽风，手动指定
--socket.setDNS(nil, 2, "119.29.29.29")
socket.setDNS(nil, 1, "223.5.5.5")

--订阅短信消息
sys.subscribe("SMS_INC",function(phone,data)
    --来新消息了
    log.info("【提示】","发现短消息，正在接收内容，准备进行转发...",phone,data)
    table.insert(buff,{phone,data})
    sys.publish("SMS_ADD")--推个事件
end)

sys.taskInit(function()
    while true do
        print("ww",collectgarbage("count"))
        while #buff > 0 do--把消息读完
            collectgarbage("collect")--防止内存不足
            local sms = table.remove(buff,1)
            local code,h, body
            local data = sms[2]
            if useServer == "serverChan" then --server酱
                log.info("【提示】","正在转发至serverChan",data)
                --多试几次好了
                for i=1,10 do
                    code, h, body = http.request(
                            "POST",
                            "https://sctapi.ftqq.com/"..serverKey..".send",
                            {["Content-Type"] = "application/x-www-form-urlencoded"},
                            "title="..string.urlEncode("sms"..sms[1]).."&desp="..string.urlEncode(data)
                        ).wait()
                    log.info("【提示】","开始转发短信至推送服务...\\n内容：",code,h,body,sms[1])
                    if code == 200 then
                        log.info("推送成功...")
                        break
                    end
                    sys.wait(2000)
                end
            elseif useServer == "pushplus" then --pushplus
                log.info("【提示】","正在转发至Pushplus",data)
                    local body = {
                    token = pushplusToken,
                    title = "【短信转发】来自: "..sms[1],
                    content = data
                }
                local json_body = string.gsub(json.encode(body), "\\b", "\\n") --luatos bug
                --多试几次好了
                for i=1,10 do
                    code, h, body = http.request(
                            "POST",
                            "http://www.pushplus.plus/send/messages.json",
                            {["Content-Type"] = "application/json; charset=utf-8"},
                            json_body
                        ).wait()
                    log.info("【提示】","开始转发短信至推送服务...\\n内容：",code,h,body,sms[1])
                    if code == 200 then
                        log.info("推送成功...")
                        break
                    end
                    sys.wait(2000)
                end
            else --useServer == "wxpusher" then --WxPusher
                log.info("【提示】","正在转发至wxpusher",data)
                    local body = {
                    appToken = wxpusherToken,
                    summary = "【短信转发】来自: "..sms[1],
                    topicIds = {wxtopicid},
                    content = data,
                    contentType = 1
                }
                local json_body = string.gsub(json.encode(body), "\\b", "\\n") --luatos bug
                --多试几次好了
                for i=1,10 do
                    code, h, body = http.request(
                            "POST",
                            "https://wxpusher.zjiecode.com/api/send/message",
                            {["Content-Type"] = "application/json; charset=utf-8"},
                            json_body
                        ).wait()
                    log.info("【提示】","开始转发短信至推送服务...\\n内容：",code,h,body,sms[1])
                    if code == 200 then
                        log.info("推送成功...")
                        break
                    end
                    sys.wait(2000)
                end                         
            end
        end
        log.info("【提示】","开始等待下一条新短信...\n如果2小时未收到短信则重启模块")
        print("用时",collectgarbage("count")) 
        sys.waitUntil("SMS_ADD",7200000)
          pm.reboot()
    end
end)


-- 用户代码已结束---------------------------------------------
-- 结尾总是这一句
sys.run()
-- sys.run()之后后面不要加任何语句!!!!!
