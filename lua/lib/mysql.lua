local mysql = require "resty.mysql"

local _M = {}

function _M.new(self,config)
    local db, err = mysql:new()
    if not db then
        return nil
    end
    db:set_timeout(1000) -- 1 sec

    local ok, err, errno, sqlstate = db:connect(config)

    if not ok then
        ngx.log(ngx.ERR,'mysql.connect_failed','error_code',errno,'message',err,'sql state',sqlstate)
        return nil
    end

    --设置编码为utf8
    local sql = "SET NAMES utf8" ;
    local res, err, errno, sqlstate = db:query(sql);
    if not res then
        ngx.log(ngx.ERR,'mysql.query_failed','error_code',errno,'message',err,'sql state',sqlstate)
        return nil
    end

    db.close = close
    return db
end

function close(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end
    if self.subscribed then
        return nil, "subscribed state"
    end
    return sock:setkeepalive(10000, 50)
end

return _M