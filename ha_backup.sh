#!/bin/bash
# 定义目标文件夹和备份路径
SOURCE="/usr/share/hassio/homeassistant"
DESTINATION="/home/backup/ha"
# 获取当前日期和时间
DATE=$(date +"%Y-%m-%d_%H-%M-%S")
# 创建备份文件名
FILENAME="backup_$DATE.tar.gz"

# 检查源目录是否存在 # 添加了这一行代码
if [ ! -d "$SOURCE" ]; then # 添加了这一行代码
  echo "源目录不存在，退出。" # 添加了这一行代码
  exit 1 # 添加了这一行代码
fi # 添加了这一行代码

# 检查目标目录是否存在 # 添加了这一行代码
if [ ! -d "$DESTINATION" ]; then # 添加了这一行代码
  echo "目标目录不存在，创建它..." # 添加了这一行代码
  sudo mkdir -p "$DESTINATION" # 添加了这一行代码
  if [ $? -ne 0 ]; then # 添加了这一行代码
    echo "创建目标目录失败，退出。" # 添加了这一行代码
    exit 1 # 添加了这一行代码
  fi # 添加了这一行代码
fi # 添加了这一行代码

# 停止Home Assistant容器
sudo docker stop homeassistant
echo "已停止Home Assistant容器"

# 设置超时时间和循环等待间隔
timeout=60 # 超时时间，单位为秒
interval=5  # 循环等待间隔，单位为秒

# 计算超时时间点
start_time=$(date +%s)
end_time=$((start_time + timeout))

# 检查Home Assistant容器状态，直到容器不再运行或达到超时时间
while [ "$(sudo docker inspect -f '{{.State.Running}}' homeassistant)" == "true" ]; do
  current_time=$(date +%s)
  if [ $current_time -ge $end_time ]; then
    echo "停止Home Assistant容器超时，无法继续备份。"
    exit 1
  fi
  sleep $interval
done
echo "Home Assistant容器已停止"

# 检测目标文件夹及其上级目录权限
PARENT_DIR=$(dirname "$DESTINATION")
if [ ! -w "$PARENT_DIR" ]; then
  echo "没有写入权限，将尝试设置权限为0755..."
  sudo chmod 0755 "$PARENT_DIR"
  if [ $? -ne 0 ]; then
    echo "无法设置权限，请手动确保目标文件夹的上级目录（$PARENT_DIR）具有适当的权限。"
    exit 1
  fi
fi
echo "目标文件夹及其上级目录权限已检查"

# 检查目标文件夹权限并设置为0755
if [ ! -w "$DESTINATION" ]; then
  echo "没有写入权限，将尝试设置权限为0755..."
  sudo chmod 0755 "$DESTINATION"
  if [ $? -ne 0 ]; then
    echo "无法设置权限，请手动确保目标文件夹（$DESTINATION）具有适当的权限。"
    exit 1
  fi
fi
echo "目标文件夹权限已检查"

# 使用tar命令压缩和打包目标文件夹，并设置文件权限为0755
sudo tar -czvf "$DESTINATION/$FILENAME" -C "$SOURCE" .
sudo chmod -R 0755 "$DESTINATION"
echo "目标文件夹已压缩和设置权限"

# 检查备份是否成功
if [ $? -eq 0 ]; then # 修改了这一行代码，添加了 if 判断语句。
  echo "备份成功，文件名为$FILENAME"
  
  # 保留三个最新的备份文件，删除其余的备份文件 # 修改了这段代码，使用 find 和 sort 命令来排序备份文件。
  backup_files=$(find "$DESTINATION" -name "backup*.gz" -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2)
  count=0
  for file in $backup_files; do 
    count=$((count+1))
    if [ $count -gt 3 ]; then 
      echo "删除$file"
      rm "$file"
    fi 
 done

else # 修改了这一行代码，添加了 else 分支。
  echo "备份失败，请检查错误信息。"
  exit 1 # 修改了这一行代码，添加了退出命令。
fi # 修改了这一行代码，添加了 fi 结束语句。

# 启动Home Assistant容器 
sudo docker start homeassistant # 添加了这一行代码来启动容器。
echo "已启动Home Assistant容器"

# 设置超时时间和循环等待间隔 # 添加了这段代码来设定时间范围。
timeout=600 # 超时时间，单位为秒，这里设定为10分钟。
interval=10 # 循环等待间隔，单位为秒，这里设定为10秒。

# 计算超时时间点 # 添加了这段代码来计算超时时间点。
start_time=$(date +%s)
end_time=$((start_time + timeout))

# 检查Home Assistant容器状态，直到容器运行或达到超时时间 # 添加了这段代码来循环检查容器状态。
while [ "$(sudo docker inspect -f '{{.State.Running}}' homeassistant)" == "false" ]; do 
 current_time=$(date +%s)
 if [ $current_time -ge $end_time ]; then 
   echo "启动Home Assistant容器超时，请检查错误信息。"
   exit 1 
 fi 
 sleep $interval 
done 
echo "Home Assistant容器正在运行"
