#!/bin/bash
# 开启调试模式
set -x
# 定义源文件夹和目标文件夹
SOURCE="/home/backup/ha"
DESTINATION="/usr/share/hassio/homeassistant"
# 获取当前日期和时间
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
# 定义一个日志文件名
LOGFILE="/home/backup/restore_$DATE.log"
# 获取源文件夹中最新的压缩文件
FILENAME=$(find "$SOURCE" -maxdepth 1 -name "backup*.gz" -printf "%T@ %f\n" | sort -n | tail -n 1 | cut -d' ' -f2)
# 检查源文件是否存在
if [[ ! -f "$SOURCE/$FILENAME" ]]; then
  echo "源文件不存在，退出。" | tee -a "$LOGFILE"
  exit 1 # 使用exit命令退出脚本，返回错误码1。
fi
# 定义一个函数来检查容器的状态
check_container_status() {
  # 获取容器名作为参数
  local container_name=$1
  # 获取期望的状态作为参数
  local expected_status=$2
  # 设置超时时间和循环等待间隔
  local timeout=60 # 超时时间，单位为秒
  local interval=5 # 循环等待间隔，单位为秒
  # 计算超时时间点
  local start_time=$(date +%s)
  local end_time=$((start_time + timeout))
  # 检查容器状态，直到容器达到期望的状态或达到超时时间
  while [[ "$(sudo docker inspect -f '{{.State.Running}}' $container_name)" != "$expected_status" ]]; do
    local current_time=$(date +%s)
    if [[ $current_time -ge $end_time ]]; then
      echo "检查$container_name容器状态超时，无法继续操作。" | tee -a "$LOGFILE"
      exit 1 # 使用exit命令退出脚本，返回错误码1。
    fi
    sleep $interval
  done
}
# 停止Home Assistant容器，并检查容器状态是否为false（即停止）
sudo docker stop homeassistant | tee -a "$LOGFILE"
check_container_status homeassistant false 
echo "Home Assistant容器已停止" | tee -a "$LOGFILE"
# 强制删除目标目录，并检查是否删除成功

# 检查是否有足够的权限删除目标目录，如果没有则尝试使用sudo命令或者切换到root用户。
if [[ ! -w "$DESTINATION" ]]; then
  echo "没有写入权限，将尝试使用sudo命令或者切换到root用户..." | tee -a "$LOGFILE"
  sudo su root # 切换到root用户，需要输入密码。
fi

sudo rm -rf "$DESTINATION" | tee -a "$LOGFILE"
if [[ ! -d "$DESTINATION" ]]; then 
  echo "目标目录已删除成功" | tee -a "$LOGFILE"
else 
  echo "目标目录仍存在，无法继续还原。" | tee -a "$LOGFILE"
  exit 1 # 使用exit命令退出脚本，返回错误码1。
fi

# 新建并赋权目标目录，并检查是否成功

sudo mkdir "$DESTINATION" | tee -a "$LOGFILE"
sudo chmod 0755 "$DESTINATION" | tee -a "$LOGFILE"

if [[ ! -d "$DESTINATION" ]] || [[ ! -w "$DESTINATION" ]]; then
  echo "目标目录不存在或没有写入权限，无法继续还原。" | tee -a "$LOGFILE"
  exit 1 # 使用exit命令退出脚本，返回错误码1。
else 
  echo "目标目录已准备好" | tee -a "$LOGFILE"
fi

# 使用tar命令解压源文件，并设置文件权限为0755，并重命名为homeassistant文件夹
sudo tar -xzvf "$SOURCE/$FILENAME" -C "$DESTINATION" --strip-components=1 | tee -a "$LOGFILE"# 使用--strip-components选项去掉第一层目录结构。
sudo chmod -R 0755 "$DESTINATION/homeassistant" | tee -a "$LOGFILE"# 直接设置homeassistant文件夹的权限。
echo "源文件已解压、设置权限并重命名" | tee -a "$LOGFILE"
# 检查还原是否成功
if [[ $? == 0 ]]; then 
  echo "还原成功，文件名为$FILENAME" | tee -a "$LOGFILE"
else 
  echo "还原失败，请检查错误信息。" | tee -a "$LOGFILE"
fi 
# 启动Home Assistant容器，并检查容器状态是否为true（即运行）
sudo docker start homeassistant | tee -a "$LOGFILE"
check_container_status homeassistant true 
echo "Home Assistant容器正在运行" | tee -a "$LOGFILE"

