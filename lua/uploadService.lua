local resty_upload = require "resty.upload";
local random = require "resty.random"
local oss = require "oss";
local resty_md5 = require "resty.md5"
local resty_str = require "resty.string"
local cjson= require "cjson";
local xxtea = require("xxtea")


function file_exists(path)
  local file = io.open(path, "rb")
  if file then file:close() end
  return file ~= nil
end


local _M = {
    __version = "0.01"
}

local mt = {__index = _M}

function new(oss_config)
    return setmetatable(oss_config, mt)
end


function upload(self,keys,filename)
    local file, err = self:_read_file();
    filename = filename or self:_generate_filename(file.name);
    local err,url,response=self:_upload(file.body,file.type,filename);
    if err then
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR);
    end
    local extra= self:_getExtraInfo(file.type,file.body);
    local data ={
        url=url,
        type=file.type,
        size=string.len(file.body),
        md5=self:_md5(file.body),
        extra=extra
    }
    local response =self:_response(data)
    local str=cjson.encode(response);
    -- 检测当前项目是否需要加密
    local project = self:_get_project();
    if keys and keys[project] then
        str= xxtea.encrypt(str,keys[project]);
    end
    ngx.header["content-type"]="application/json";
    ngx.say(str);
    return;
end


function openapi()

end

-- 获取上传的文件
function _read_file(self)
    local chunk_size = 4096
    local form, err = resty_upload:new(chunk_size)
    if err then
        local response=self:_response(nil,400,err);
        ngx.log(ngx.ERR,response["message"]);
        ngx.status=ngx.HTTP_BAD_REQUEST;
        ngx.say(cjson.encode(data));
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end
    form:set_timeout(20000)
    local file = {}
    if not err then
        while true do
            local typ, res, err2 = form:read()
            if not typ then
                err = err2
                print("failed to read: ", err2)
                break
            end

            if typ == 'header' and res[1] == 'Content-Disposition' then
                local filename = string.match(res[2], 'filename="(.*)"')
                file.name = filename
            end

            if typ == 'header' and res[1] == 'Content-Type' then
                file['type'] = res[2]
            end
            if typ == 'body' and file then
                file[typ] = (file[typ] or '') .. res
            end
            if typ == "eof" then
                break
            end
        end
    end
    return file, err
end

--上传图片类型时，增加图片宽高属性
function _afterUploadImage(self,binary)
    local magick = require "magick";
    local img,err=magick.load_image_from_blob(binary);
    if err then

        local response = self:_response(nil,400,"magick load image error:"..err);
        ngx.log(ngx.ERR,response["message"]);
        ngx.status=ngx.HTTP_BAD_REQUEST;
        ngx.say(cjson.encode(response));
        ngx.exit(ngx.HTTP_BAD_REQUEST);
    end
    local width = img:get_width();
    local height = img:get_height();
    img:destroy();
    local output={
        width = width,
        height = height
    };
    return output;
end

--上传安卓包时，增加图片宽高属性
function _afterUploadAndroidApk(self,binary)
    local tmpFilename=os.tmpname();

    local tmpFile = io.open(tmpFilename,"w")
    tmpFile:write(binary);
    tmpFile:close();
    local cmd = "aapt  dump badging "..tmpFilename.." |grep -E '(package|application).*='|awk -F ':' '{print $2}'";
    ngx.log(ngx.INFO,"aapt system shell :"..cmd);
    local rsfile = io.popen(cmd)
    local rschar = rsfile:read("*all");
    ngx.log(ngx.INFO,"aapt system shell result:"..rschar);
    local output={};
    for k,v in string.gmatch(rschar,"(%w+)=['\"]([^%s]+)['\"]") do
        output[k]=v;
    end
    local icon=output['icon'] or nil
    if icon then
     -- 获取icon 图标
     cmd= "unzip -o  "..tmpFilename.." "..icon.." -d /tmp/apk_icon/ |grep '"..icon.."' |awk -F':' '{print $2}'" ;
     ngx.log(ngx.INFO,"unzip system shell :"..cmd);
     rsfile = io.popen(cmd)
     rschar = rsfile:read("*all")
     os.remove(tmpFilename); -- 及时删除临时文件
     ngx.log(ngx.INFO,"unzip system shell result:"..rschar);
     local icon_file= rschar and string.gsub(rschar, "^%s*(.-)%s*$", "%1");
     if not file_exists(icon_file) then
        ngx.log(ngx.WARN,"can't get icon file");
     else
        local f = assert(io.open(icon_file,'r'))
        local binary = f:read('*all')
        f:close()
        os.remove(icon_file); -- 及时删除临时文件
        local base_filename=string.match(icon_file, ".+/([^/]*%.%w+)$")
        local type="image/png";
        local err,url,response=self:_upload(binary,type,base_filename);
        if err then
            ngx.log(ngx.WAR,"upload icon error:"..err);
        else
            output['icon']=url;
        end
     end
    end
    return output;
end

function _get_project(self)
    return ngx.var.arg_project or "default";
end

function _generate_filename(self,basename)
    local project = self:_get_project();
    local current_date = os.date("%Y%m%d%H%M%S");
    return project .."/" .. current_date .. basename
end

function _md5(self,content)
    local md5 = resty_md5:new()
    if not md5 then
        ngx.log(ngx.ERR,"failed to create md5 object")
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR);
    end

     ok = md5:update(content)
    if not ok then
        ngx.log(ngx.ERR,"failed to add data")
        ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR);
    end
    local digest = md5:final()
    md5:reset();
    return resty_str.to_hex(digest);
end

function _upload(self,binary,file_type,filename)
    local oss_config = {
        accessKey	  =   self.accessKey,
        secretKey	  =   self.secretKey,
        bucket      =   self.bucket,
        endpoint    =   self.endpoint
    }
    local client = oss.new(oss_config)
    local err,url, body = client:put_object(binary, file_type,filename)
    if err then
        ngx.log(ngx.WAR,"upload file error"..err);
    end
    return err,url,response;
end

function _response(self,data,statusCode,message)
    local data= data or nil;
    local message =message or "ok"
    local statusCode = statusCode or 200
    local response ={
            message=message,
            statusCode=statusCode,
        }
    if data then
        response["data"]=data;
    end

    return response;
end

function _getExtraInfo(self,type,binary)
    if  string.match(type,"image") then
        return self:_afterUploadImage(binary);
    end

    if string.match(type,"android") then
        return self:_afterUploadAndroidApk(binary);
    end
    return {}
end


-- public
_M.new = new
_M.upload = upload


-- private
_M._generate_filename = _generate_filename
_M._read_file = _read_file
_M._md5 = _md5
_M._afterUploadImage = _afterUploadImage
_M._afterUploadAndroidApk = _afterUploadAndroidApk
_M._getExtraInfo = _getExtraInfo
_M._upload = _upload
_M._encrypt = _encrypt
_M._get_project = _get_project
_M._response = _response

return _M