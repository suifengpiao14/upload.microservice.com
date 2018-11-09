# 基于openresty开发的阿里云oss上传服务
## 安装软件
1.openresty
2. lua 扩展 magick (https://github.com/leafo/magick)
3. lua 扩展  xxtea (https://github.com/xxtea/xxtea-lua)(仓库中自带xxtea.so)
4. 系统安装 aapt  luajit libmagickwand-dev 
## 应用
使用openresty启动项目配置文件(conf/conf.d/file.microservice.com.conf) 监听8182 端口
提供接口 /api/v1/upload/file
调用方法 post
参数  project 项目名称，默认(default) 必须在query中
      filename 存储后的文件名，默认随机生成 必须在query中
	  file post上传文件字段
/doc/api.json 提供openapi 文档(可使用swagger-ui浏览)
## 说明
服务支持上传图片和apk，并分别获得其中的具体信息如图片宽高、大小；apk包名、版本号、icon地址等
返回数据支持加密，具体看conf/conf.d/file.microservice.com 配置文件
