#!/bin/bash
# jenkins 执行 shell 杀死子进程问题
BUILD_ID=dontKillMe

# jenkins自动化部署脚本
# 自动杀死旧版本,自动备份旧版本日志文件、服务包文件
# author GongLiHai
# date   2021/1/8 16:11
# 使用说明: 将此脚本与jar包存放于同一目录,配置项目信息.
# 目录结构:
# ./
#  ├─ backup                                     - jar包备份目录
#  │  └─ project-jenkins-yyyy-mm-dd-HH-MM.jar    - 以 jenkins-yyyy-mm-dd-HH-MM 结尾的备份包
#  ├─ project.jar                                - 当前版本的jar包
#  ├─ jenkins-start.sh                           - jenkins启动脚本
#  └─ log                                        - 日志目录
#     ├─ project.log                             - 当前版本项目的日志
#     └─ project.log.yyyy-mm-dd-HH-MM.history    - 旧版本项目的日志

########## 配置

# 项目名,项目启动成功,备份jar包时重命名使用
PROJECT_NAME="auto_download"
# 打包出来的文件名,项目jar包名称,启动命令 java -jar xxx.jar
PROJECT_BULID_FILE_NAME="auto_download.jar"
# 项目启用的配置文件 spring.profiles.active的值
PROJECT_ACTIVE_PROFILE="prod"
# 项目日志,日志的目录
LOG_FILE_PATH="log/auto_download.log"
# 项目启动成功时日志输出的关键字
LOG_SUCCESS_END_MARK="Started AutoDownloadApplication"
# 项目启动失败时日志输出的关键字
LOG_FAIL_END_MARK="Shutting down"

# java 命令路径
JAVA="/root/home/tools/jdk17/bin/java"
# jvm 启动参数
START_PARAMS="-Xmx32m -jar -Dspring.profiles.active=${PROJECT_ACTIVE_PROFILE}"

# 等待停止超时时间, 超过设置的时间后强制退出 (kill - 9), 单位: 秒, -1 不强制退出
WAIT_TIMEOUT_STOP=30
# 通过日志判断启动结果超时时间, 单位: 秒
WAIT_TIMEOUT_READ_LOG=60

########## 函数

# 切换工作目录
function changeWorkspace() {
  cd $(dirname $0)
  echo "工作目录: $(pwd)"
}

# 结束脚本 带状态码, 打印描述
function rExit() {
  echo $2
  exit $1
}

# 检查 jar 包是否存在, 不存在 结束脚本, $? 为 1
function checkJarExists() {
  if [ ! -e ./$1 ]; then
    if [ ! -e ./$1.runtime ]; then
      rExit 1 "工作目录下找不到 ${PROJECT_BULID_FILE_NAME} 文件"
    fi
    mv $1.runtime $1
  fi
}

# 根据 函数第一个参数值 查 进程id, 如果进程id存在, 则 kill 并阻塞等待进程结束
function checkIsRuning() {
  projectPid=$(ps aux | grep $1 | grep -v "grep" | tr -s ' ' | cut -d ' ' -f 2)
  if [[ ${projectPid} != "" ]]; then
    echo "$1 已启动, 停止. 进程编号:${projectPid}"
    kill ${projectPid}
    echo "等待停止 $1"
    sum=0
    while true; do
      if [[ $(ps aux | grep $1 | grep -v "grep" | tr -s ' ' | cut -d ' ' -f 2) == "" ]]; then
        break
      fi
      sleep 1s
      sum=$(expr $sum + 1)
      if [ $sum == ${WAIT_TIMEOUT_STOP} ]; then
        echo "等待超时, 强制退出(kill -9)"
        kill -9 ${projectPid}
        break
      fi
      echo ".$sum"
    done
    echo "已停止"
  fi
}

# 启动 jar 包, 打印日志, 匹配关键字, 判断启动结果, 启动失败 结束脚本
function startJar() {
  # 重命名
  mvName="${PROJECT_BULID_FILE_NAME}.runtime"
  mv ${PROJECT_BULID_FILE_NAME} ${mvName}
  # 启动项目
  echo "nohup ${JAVA} ${START_PARAMS} ${mvName}  > /dev/null 2>&1 &"
  nohup ${JAVA} ${START_PARAMS} ${mvName} >/dev/null 2>&1 &

  # 等待产生日志文件
  echo "等待日志文件"
  sum=0
  while true; do
    if [ -e ${LOG_FILE_PATH} ]; then
      break
    fi
    sleep 1s
    sum=$(expr $sum + 1)
    if [ $sum == ${WAIT_TIMEOUT_READ_LOG} ]; then
      echo ""
      rExit 2 "等待日志文件超时, 请检查日志文件配置文件目录是否正确"
    fi
    echo ".$sum"
  done

  # 打印日志内容
  echo "------------------------------------日志 开始------------------------------------"
  timeout ${WAIT_TIMEOUT_READ_LOG} /usr/bin/bash -c "tail -f -n 0 ${LOG_FILE_PATH} | sed \"/${LOG_SUCCESS_END_MARK}/Q; /${LOG_FAIL_END_MARK}/Q 1\""
  projectStartStatus=$?
  echo "------------------------------------日志 结束------------------------------------"

  if [[ ${projectStartStatus} == 0 ]]; then
    rExit 0 "启动成功 (匹配到启动成功日志标识符 \"${LOG_SUCCESS_END_MARK}\")"
  fi

  # 是否超时
  if [[ ${projectStartStatus} == 124 ]]; then
    rExit 2 "启动失败, 读取日志超时"
  fi

  # 判断项目启动状态,启动成功备份项目,启动失败异常状态结束脚本
  if [[ ${projectStartStatus} == 1 ]]; then
    rExit 2 "启动失败 (匹配到启动失败日志标识符\"${LOG_FAIL_END_MARK}\")"
  fi

  rExit ${projectStartStatus} "启动失败, 未知的返回状态码: ${projectStartStatus}"
}

# 备份
function backup() {
  nowDate=$(date "+%Y-%m-%d-%H-%M")
  echo "将 ${PROJECT_BULID_FILE_NAME} 备份到 ./backup/${PROJECT_NAME}-jenkins-${nowDate}.jar"
  # 判断文件夹是否存在
  if [ ! -d "./backup" ]; then
    mkdir ./backup
  fi
  cp -a ./${PROJECT_BULID_FILE_NAME}.runtime ./backup/${PROJECT_NAME}-jenkins-${nowDate}.jar
}

########## main
changeWorkspace
checkJarExists ${PROJECT_BULID_FILE_NAME} # 检查jar包是否存在
checkIsRuning ${PROJECT_BULID_FILE_NAME}  # 停服务
startJar                                  # 启服务
#backup     # 备份
