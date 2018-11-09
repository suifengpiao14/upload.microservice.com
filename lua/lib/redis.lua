local redis = require("resty.redis")

local _R = {}


function _R.new(self,config)
    local red = redis:new()
    if not red then
        ngx.log(ngx.ERR,"can not find redis server : ", config['host'],config['port'])
        return nil
    end
    red:set_timeout(1000)
    red.close = close

     local ok, err = red:connect(config['host'], config['port'])
        if not ok then
            ngx.log(ngx.ERR,"connect to redis error : ", err)
            return close(red)
        end

     if config['auth'] then
         local res, err = red:auth(config['auth'])
         if not res then
             ngx.log(ngx.ERR,"failed to authenticate: ", err)
             return
         end
     end

    return red
end

 local function close(self)
    if not self then
        return
    end

    local pool_Rax_idle_time = 10000 --毫秒
    local pool_size = 100 --连接池大小
    local ok, err = self:set_keepalive(pool_Rax_idle_time, pool_size)
    if not ok then
        ngx.log(ngx.ERR,"set keepalive error : ", err)
    end
end

return _R