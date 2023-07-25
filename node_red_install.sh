#!/bin/bash

# 检查系统是否是debian11
if [ "$(lsb_release -is)" != "Debian" ] || [ "$(lsb_release -rs)" != "11" ]; then
    echo "This script only works on Debian 11."
    exit 1
fi

# 检查是否安装了node.js和npm
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "Installing node.js and npm..."
    # 使用官方的安装脚本来获取最新的版本
    curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
    sudo apt install nodejs -y
fi

# 检查是否安装了node red
if ! command -v node-red &> /dev/null; then
    echo "Installing node red..."
    # 使用npm命令来安装node red，并参考官方的文档来解决权限或者编译的问题
    sudo npm install -g --unsafe-perm --production node-red
fi

# 使用systemd来管理node red的服务
echo "Setting up node red service..."
# 创建一个名为node-red.service的文件，并复制到/etc/systemd/system/目录下
cat << EOF | sudo tee /etc/systemd/system/node-red.service > /dev/null
[Unit]
Description=Node-RED
After=syslog.target network.target

[Service]
ExecStart=/usr/local/bin/env node-red-pi --max-old-space-size=1024 -v
WorkingDirectory=/usr/local/lib/node_modules/node-red
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

# 执行相关命令来启动和开机自启动node red服务
sudo systemctl daemon-reload
sudo systemctl enable node-red.service
sudo systemctl start node-red.service

# 编辑~/.node-red/settings.js文件，修改uiPort属性为6000，然后重启node red服务
echo "Changing node red port to 6000..."
sed -i 's/^uiPort: .*/uiPort: "6000",/' ~/.node-red/settings.js
sudo systemctl restart node-red.service

echo "Done."

