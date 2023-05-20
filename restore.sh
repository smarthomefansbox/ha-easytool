#!/bin/bash
# 定义源文件夹和目标文件夹
SOURCE="/home/backup/ha"
DESTINATION="/usr/share/hassio/homeassistant"
# 获取当前日期和时间
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
# 获取源文件夹中最新的压缩文件
FILENAME=$(ls -t $SOURCE/backup*.gz | head -n 1 | awk -F '/' '{print $NF}')
# 检查源文件是否存在
if [ ! -f "$SOURCE/$FILENAME" ]; then
  echo "源文件不存在，退出。"
  exit 1 # 使用exit命令退出脚本，返回错误码1。
fi
# 停止Home Assistant容器
sudo docker stop homeassistant
echo "已停止Home Assistant容器"
# 设置超时时间和循环等待间隔
timeout=60 # 超时时间，单位为秒
interval=5 # 循环等待间隔，单位为秒
# 计算超时时间点
start_time=$(date +%s)
end_time=$((start_time + timeout))
# 检查Home Assistant容器状态，直到容器不再运行或达到超时时间
while [ "$(sudo docker inspect -f '{{.State.Running}}' homeassistant)" == "true" ]; do
  current_time=$(date +%s)
  if [ $current_time -ge $end_time ]; then
    echo "停止Home Assistant容器超时，无法继续还原。"
    exit 1 # 使用exit命令退出脚本，返回错误码1。
  fi
  sleep $interval
done
echo "Home Assistant容器已停止"
# 强制删除目标目录，并检查是否删除成功

# 检查是否有足够的权限删除目标目录，如果没有则尝试使用sudo命令或者切换到root用户。
if [ ! -w "$DESTINATION" ]; then
  echo "没有写入权限，将尝试使用sudo命令或者切换到root用户..."
  sudo su root # 切换到root用户，需要输入密码。
fi

sudo rm -rf "$DESTINATION"
echo "已删除目标目录"
if [ -d "$DESTINATION" ]; then
  echo "目标目录仍存在，无法继续还原。"
  exit 1 # 使用exit命令退出脚本，返回错误码1。
else 
  echo "目标目录已删除成功"
fi

# 新建并赋权目标目录，并检查是否成功

sudo mkdir "$DESTINATION"
echo "已新建目标目录"
sudo chmod 0755 "$DESTINATION"
echo "已赋权目标目录"

if [ ! -d "$DESTINATION" ] || [ ! -w "$DESTINATION" ]; then
  echo "目标目录不存在或没有写入权限，无法继续还原。"
  exit 1 # 使用exit命令退出脚本，返回错误码1。
else 
  echo "目标目录已准备好"
fi

# 使用tar命令解压源文件，并设置文件权限为0755，并重命名为homeassistant文件夹
sudo tar -xzvf "$SOURCE/$FILENAME" -C "$DESTINATION" --strip-components=1 # 使用--strip-components选项去掉第一层目录结构。
sudo chmod -R 0755 "$DESTINATION/homeassistant" # 直接设置homeassistant文件夹的权限。
echo "源文件已解压、设置权限并重命名"
# 检查还原是否成功
if [ $? -eq 0 ]; then 
  echo "还原成功，文件名为$FILENAME" 
else 
  echo "还原失败，请检查错误信息。"
fi 
# 启动Home Assistant容器 
sudo docker start homeassistant 
echo "已启动Home Assistant容器" 
# 设置超时时间和循环等待间隔 
timeout=600 # 超时时间，单位为秒，这里设定为10分钟。
interval=10 # 循环等待间隔，单位为秒，这里设定为10秒。
# 计算超时时间点 
start_time=$(date +%s)
end_time=$((start_time + timeout))
# 检查Home Assistant容器状态，直到容器运行或达到超时时间 
while [ "$(sudo docker inspect -f '{{.State.Running}}' homeassistant)" == "false" ]; do 
  current_time=$(date +%s) 
  if [ $current_time -ge $end_time ]; then 
    echo "启动Home Assistant容器超时，请检查错误信息。" 
    exit 1 # 使用exit命令退出脚本，返回错误码1。
  fi 
  sleep $interval 
done 
echo "Home Assistant容器正在运行"

