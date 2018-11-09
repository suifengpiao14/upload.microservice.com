
local http=require('resty.http');

local _M = {
    _VERSION = '0.0.1',
}

function _M.init(host,config)
    if not host then
        ngx.log(ngx.ERR,"validation host can not be empty");
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR);
    end
    _M.host=host;
    _M.scheme= config.scheme or "http";
    _M.http_proxy = config.http_proxy or nil;
    _M.https_proxy = config.https_proxy or nil;
    _M.connect_timeout = config.connect_timeout or 3000; -- 默认3s
    _M.send_timeout = config.send_timeout or 3000; -- 默认3s
    _M.read_timeout = config.read_timeout or 5000; -- 默认5s
end



function _M.validateRequest()
    if (ngx.var.request_method == 'OPTIONS') then
        return ngx.OK;
    end

    local httpc = http.new()
    local original_headers=ngx.req.get_headers();
          original_headers["x-host"]=original_headers.host; -- 增加原始host （java spring boot 部署不认可host，只认port）
          original_headers["host"]=_M.host;

    ngx.req.read_body();
    local options={
        method = ngx.req.get_method(),
        path = ngx.var.request_uri,
        query = ngx.var.args,
        headers = original_headers,
        body = ngx.req.get_body_data(),
    }

    httpc:set_timeouts(_M.connect_timeout, _M.send_timeout, _M.read_timeout); -- 连接时间3s 发送时间3s 读取时间5s
    local proxy_options={
        http_proxy = _M.http_proxy or nil,
        https_proxy = _M.https_proxy or nil,
    };
    httpc:set_proxy_options(proxy_options);

    _M.scheme =_M.scheme or "http";
    local res, err = httpc:request_uri(_M.scheme.."://".._M.host..ngx.var.request_uri,options)

    if err then
        ngx.log(ngx.ERR,err);
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR);
    end

    if res.status == ngx.HTTP_NO_CONTENT  or  res.status == ngx.OK then -- 验证服务器返回204、200 标识成功
            return ngx.OK;
    end

    ngx.log(ngx.DEBUG,"Final validation result:" .. res.body .. ", [" .. res.status .. "]")

     if res.status == ngx.HTTP_FORBIDDEN or res.status == ngx.HTTP_UNAUTHORIZED or res.status == ngx.HTTP_BAD_REQUEST or tonumber(res.status) > 599 then
            return _M.decorateResponse(res)
        end
      return ngx.exit(res.status);

end

-- 处理错误
function _M.decorateResponse(res)
    if res == nil then
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
    end

    if res.header ~= nil then
        for k, v in pairs(res.header) do
            val = tostring(v)
            ngx.header[k] = val
        end
    end

    if res.truncated then
        return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR);
    end

    ngx.status=res.status
    ngx.say(res.body);
    return ngx.exit(ngx.status);
end


return _M;