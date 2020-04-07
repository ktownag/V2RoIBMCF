#!/bin/bash

# 定义参数检查
paras=$@
function checkPara(){
    local p=$1
    for i in $paras; do if [[ $i == $p ]]; then return; fi; done
    false
}

# 设置 IDE
IDE=false # 通过 IBM Cloud Shell Terminal 部署应用
checkPara 'ide' && IDE=true # 通过 Web IDE 部署应用

# 设置 REGION
REGION=us-south # US South(Dallas, USA), North America
checkPara 'au' && REGION=au-syd # AP South(Sydney, Australia), Asia Pacific
checkPara 'de' && REGION=eu-de # EU Central(Frankfurt, Deutschland), Europe
checkPara 'uk' && REGION=eu-gb # UK South(London, Great Britain), Europe

# 通过 Web IDE 部署应用
if $IDE; then
    # 安装 IBM Cloud CLI
    echo -e '\n======================  注   意  ======================'
    echo '下载 IBM Cloud CLI 可能需要较长时间，有时甚至无法下载。'
    echo '复用 IDE 中现有的 IBM Cloud CLI 环境可以加快部署的进程。'
    echo '======================================================='
    while true;
    do
        echo
        read -p '您现在需要下载与安装 IBM Cloud CLI 吗？[y/n]: ' DI_IBMCLI
        case $DI_IBMCLI in
            [Yy])
                echo -e '\nDownload IBM Cloud CLI ...'
                curl -Lo IBM_Cloud_CLI_amd64.tar.gz https://clis.cloud.ibm.com/download/bluemix-cli/latest/linux64
                echo -e '\nInstall IBM Cloud CLI ...'
                tar -zxf IBM_Cloud_CLI_amd64.tar.gz
                cd ./Bluemix_CLI/
                sudo ./install_bluemix_cli
                ibmcloud config --usage-stats-collect false
                cd .. # 返回起始目录
                break
                ;;
            [Nn])
                break
                ;;
            *)
                echo -e '\n您的输入有误，请重新选择。'
        esac
    done
    # 登录到 IBM Cloud CLI
    echo
    ibmcloud login -a https://cloud.ibm.com -r $REGION
fi

# 获取 APP_NAME & INSTANCES & MEM_SIZE
echo -e '\n++++++++++++++++++++++++++++++++++++++++++++'
echo '  Configure IBM Cloud Foundry Application.'
echo '++++++++++++++++++++++++++++++++++++++++++++'
echo -e -n '\n您打算用哪个应用程序？请原样输入应用程序名称：'
read APP_NAME
while [ -z $APP_NAME ]
do
    echo -e -n '\n您未输入应用程序名称，请重新输入：'
    read APP_NAME
done
echo -e -n '\n您打算运行几个应用实例？请输入数字（默认3）：'
read INSTANCES
if [ -z $INSTANCES ]; then 
    echo -e '\n您未输入实例数量，将使用默认值3。'
    INSTANCES=3
fi
echo -e -n '\n您打算用多少 MB 内存来运行每个实例？请输入数字（默认64）：'
read MEM_SIZE
if [ -z $MEM_SIZE ]; then 
    echo -e '\n您未输入实例内存大小，将使用默认值64。'
    MEM_SIZE=64
fi

# 获取 LOG_LEVEL & V2RAY_PORT & ALTERID，生成或保留 UUID & WebSocket PATH
echo -e '\n+++++++++++++++++++++++++++++++++++++++++++++++++++++'
echo '  Configure V2Ray as a VMess server with WebSocket.'
echo '+++++++++++++++++++++++++++++++++++++++++++++++++++++'
echo -e -n '\n您打算用 V2Ray 错误日志的哪个级别？请输入（默认 none）：'
read LOG_LEVEL
if [ -z $LOG_LEVEL ]; then 
    echo -e '\n您未输入 V2Ray 的错误日志级别，将使用默认值 none 。'
    LOG_LEVEL=none
fi
echo -e -n '\n您打算在哪个端口上进行入站监听？请输入数字（默认8080）：'
read V2RAY_PORT
if [ -z $V2RAY_PORT ]; then 
    echo -e '\n您未输入端口号，将使用默认值8080。'
    V2RAY_PORT=8080
fi
echo -e -n '\n要生成新 UUID，请按回车键；要用自己的 UUID，请正确输入，仔细核对：'
read UUID
if [ -z $UUID ]; then 
    echo -e '\n您未输入自己的 UUID，将生成新 UUID。'
    UUID=$(cat /proc/sys/kernel/random/uuid)
    echo -e '\nGenerated a new UUID for V2Ray VMess server.'
fi
echo -e -n '\n您打算把 alterId 的值设为多少？请输入数字（默认64）：'
read ALTERID
if [ -z $ALTERID ]; then 
    echo -e '\n您未输入 alterId 的值，将使用默认值64。'
    ALTERID=64
fi
echo -e -n '\n要生成新 WebSocket PATH，请按回车键；要用自己的 WebSocket PATH，请正确输入，仔细核对：'
read WEBSOCKET_PATH
if [ -z $WEBSOCKET_PATH ]; then 
    echo -e '\n您未输入自己的 WebSocket PATH，将生成新 WebSocket PATH。'
    WEBSOCKET_PATH=$(cat /proc/sys/kernel/random/uuid | cut -d '-' -f1)
    echo -e '\nGenerated a new WebSocket PATH for V2Ray VMess server.'
else
    WEBSOCKET_PATH=$(echo $WEBSOCKET_PATH | cut -d '/' -f2) # 删除用户输入字符串开头可能会有的'/'
fi

# 回显各项参数的设置值
echo -e '\n参数设置已完成。您的各项设置如下：'
echo '==========================================================='
echo '  IBM Cloud'
echo '    应用程序名称：   '$APP_NAME
echo '    应用实例数量：   '$INSTANCES
echo '    实例内存大小：   '$MEM_SIZE' MB'
echo
echo '  V2Ray'
echo '    错误日志级别：   '$LOG_LEVEL
echo '    入站监听端口：   '$V2RAY_PORT
echo
echo '  V2Ray VMess server'
echo '    用户ID(UUID)：   '$UUID
echo '    额外ID(alterId)：'$ALTERID
echo '    WebSocket PATH： /'$WEBSOCKET_PATH
echo '==========================================================='

sleep 10

# 清除上次部署应用时遗留的 V2RoIBMCF 文件夹
rm -rf V2RoIBMCF

# 准备 IBM Cloud Foundry 应用程序目录和文件
mkdir -p ./V2RoIBMCF
cd ./V2RoIBMCF/

cat << _EOF_ > Procfile
web: ./v2ray/v2ray
_EOF_

cat << _EOF_ > manifest.yml
---
applications:
- name: ${APP_NAME}
  instances: ${INSTANCES}
  memory: ${MEM_SIZE}MB
  random-route: false
  routes:
  - route: ${APP_NAME}.${REGION}.cf.appdomain.cloud
  buildpacks:
  - binary_buildpack
  path: .
  command: cd ./v2ray && chmod u-w * && ./v2ray -config config.json
_EOF_

cd .. # 返回起始目录

# 下载 V2Ray 文件
echo -e '\n=======================  注   意  ======================='
echo '下载 V2Ray 官方软件包可能需要较长时间，有时甚至无法下载。'
echo '复用 IDE 中上次部署时遗留的 V2Ray 文件可以加快部署的进程。'
echo '========================================================='
while true;
do
    echo
    read -p '您现在要下载 V2Ray 官方软件包吗？[y/n]: ' DL_V2RAY
    case $DL_V2RAY in
        [Yy])
            mkdir -p ./v2ray
            cd ./v2ray/
            echo -e '\nDownload V2Ray ...'
            curl -Lo v2ray.zip https://github.com/v2ray/dist/raw/master/v2ray-linux-64.zip
            cd .. # 返回起始目录
            break
            ;;
        [Nn])
            break
            ;;
        *)
            echo -e '\n您的输入有误，请重新选择。'
    esac
done

# 准备 V2Ray 目录和文件
mkdir -p ./V2RoIBMCF/v2ray
cd ./v2ray/
unzip -qo v2ray.zip
chmod 755 ./v2ray ./v2ctl
cp {v2ray,v2ctl,geoip.dat,geosite.dat} ../V2RoIBMCF/v2ray/

# 创建 V2Ray vmess 配置文件 config.json
cd ../V2RoIBMCF/v2ray/

cat << _EOF_ > config.json
{
  "log": {
    "access": "none",
    "error": "./v2ray/error.log",
    "loglevel": "${LOG_LEVEL}"
  },
  "inbounds": [
    {
      "port": ${V2RAY_PORT},
      "listen": "0.0.0.0",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "alterId": ${ALTERID}
          }
        ],
        "disableInsecureEncryption": true
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/${WEBSOCKET_PATH}"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": [
          "http",
          "tls"
        ]
      },
      "tag": "vmess_main"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "block"
    }
  ],
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
      {
        "type": "field",
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "protocol": [
          "bittorrent"
        ],
        "outboundTag": "block"
      }
    ]
  }
}
_EOF_

cd .. # 返回 V2RoIBMCF 目录

# 确定应用部署的目标地区、组织和空间
echo
ibmcloud target -r $REGION
ibmcloud target --cf

# 删除 IBM Cloud Foundry 上的同名应用程序（保留路径）
echo
ibmcloud cf delete $APP_NAME -f

# 部署应用到 IBM Cloud Foundry
echo
ibmcloud cf push --no-start

# 获取应用程序端口信息，设置 APP_GUID & APP_PORT & ROUTE_GUID
APP_GUID=$(ibmcloud cf app $APP_NAME --guid | tail -n 1)
APP_PORT=$(ibmcloud cf curl /v2/apps/$APP_GUID/route_mappings | grep "app_port" | grep -o '[[:digit:]]*') 
ROUTE_GUID=$(ibmcloud cf curl /v2/apps/$APP_GUID/route_mappings | grep "route_guid" | cut -d '"' -f4)

# 把应用程序的端口从 APP_PORT 改为 V2RAY_PORT
if [ "$V2RAY_PORT" != "$APP_PORT" ]; then
    echo -e "\nChanging the PORT of ${APP_NAME} from ${APP_PORT} to ${V2RAY_PORT} ..."
    ROUTE_MAP_GUID_DEL=$(ibmcloud cf curl /v2/apps/$APP_GUID/route_mappings | grep "guid" | head -n 1 | cut -d '"' -f4)
    echo
    ibmcloud cf curl /v2/apps/$APP_GUID -X PUT -d '{"ports": ['"$APP_PORT"', '"$V2RAY_PORT"']}'
    echo
    ibmcloud cf curl /v2/route_mappings -X POST -d '{"app_guid": "'"$APP_GUID"'", "route_guid": "'"$ROUTE_GUID"'", "app_port": '"$V2RAY_PORT"'}' 
    echo
    ibmcloud cf curl /v2/route_mappings/$ROUTE_MAP_GUID_DEL -X DELETE
    echo
    ibmcloud cf curl /v2/apps/$APP_GUID -X PUT -d '{"ports": ['"$V2RAY_PORT"']}'
    echo -e "\nDone. The PORT of ${APP_NAME} has been Changed from ${APP_PORT} to ${V2RAY_PORT}."
fi

# 显示应用程序使用的端口
echo -e "\nPlease check the PORT of ${APP_NAME}: "$(ibmcloud cf curl /v2/routes/$ROUTE_GUID/route_mappings | grep "app_port" | grep -o '[[:digit:]]*')

# 启动应用程序
echo
ibmcloud cf start $APP_NAME
echo
