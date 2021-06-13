#!/bin/bash

#jenkins自动化部署脚本
#自动杀死旧版本,自动备份旧版本日志文件、服务包文件
#author GongLiHai
#date   2021/1/8 16:11
#使用说明: 将此脚本与jar包存放于同一目录,配置项目信息.
#目录结构:
#./
# ├─ backup                                     - jar包备份目录
# │  └─ project-jenkins-yyyy-mm-dd-HH-MM.jar    - 以 jenkins-yyyy-mm-dd-HH-MM 结尾的备份包
# ├─ project.jar                                - 当前版本的jar包
# ├─ jenkins-start.sh                           - jenkins启动脚本
# └─ log                                        - 日志目录
#    ├─ project.log                             - 当前版本项目的日志
#    └─ project.log.yyyy-mm-dd-HH-MM.history    - 旧版本项目的日志

########
# 配置 #
########

#项目名,项目启动成功,备份jar包时重命名使用
PROJECT_NAME="mybox-server"
#项目启用的配置文件 spring.profiles.active的值
PROJECT_ACTIVE_PROFILE="prod"
#打包出来的文件名,项目jar包名称,启动命令 java -jar xxx.jar 
PROJECT_BULID_FILE_NAME="my-box-0.0.1-SNAPSHOT.jar"
#项目日志,日志的目录
LOG_FILE_PATH="./log/mybox-server.log"
#项目启动成功时日志输出的关键字
LOG_SUCCESS_END_MARK="Started MyBoxApplication"
#项目启动失败时日志输出的关键字
LOG_FAIL_END_MARK="Shutting down"

#java环境
export JAVA_HOME=/usr/local/jdk8
export JRE_HOME=/usr/local/jdk8/jre
export CLASSPATH=.:$JAVA_HOME/lib:$JRE_HOME/lib:$CLASSPATH
export PATH=$JAVA_HOME/bin:$JRE_HOME/bin:$PATH

########
# 逻辑 #
########

#获取时间 yyyy-mm-dd-HH-MM
nowDate=$(date "+%Y-%m-%d-%H-%M")

#切换工作目录
cd $(dirname $0)
echo "当前工作目录:`pwd`"

#判断jar包是否存在,不存在异常状态结束脚本
if [ ! -e ./${PROJECT_BULID_FILE_NAME} ]
then
    echo "当前工作目录下找不到${PROJECT_BULID_FILE_NAME}文件"
    exit 1
fi

#判断项目是否已启动,存在kill已启动项目
projectPid=$(ps aux | grep ${PROJECT_BULID_FILE_NAME} | grep -v "grep" | tr -s ' '| cut -d ' ' -f 2)
if [[ ${projectPid} != "" ]]
then
    echo "旧版本项目进程编号:${projectPid},结束旧版本项目进程"
    kill ${projectPid}
    echo "等待停止"
    while true 
    do
        if [[ $(ps aux | grep ${PROJECT_BULID_FILE_NAME} | grep -v "grep" | tr -s ' '| cut -d ' ' -f 2) == "" ]]
        then         
            break
        fi
        sleep 1s
        echo "."
    done
fi

#启动项目
echo "启动项目"
echo "nohup java -jar -Dspring.profiles.active=${PROJECT_ACTIVE_PROFILE} ${PROJECT_BULID_FILE_NAME}  > /dev/null 2>&1 &"
nohup java -jar -Dspring.profiles.active=${PROJECT_ACTIVE_PROFILE} ${PROJECT_BULID_FILE_NAME} > /dev/null 2>&1 &

#等待产生日志文件
echo "等待日志"
while true
do  
    if [ -e ${LOG_FILE_PATH} ]
    then
        break
    fi
    sleep 1s
    echo "."
done

#打印日志内容
echo "------------------------------------启动日志 开始------------------------------------"
tail -f -n 0 ${LOG_FILE_PATH} | sed "/${LOG_SUCCESS_END_MARK}/Q; /${LOG_FAIL_END_MARK}/Q 1";
projectStartStatus=$?
echo "------------------------------------启动日志 结束------------------------------------"

#判断项目启动状态,启动成功备份项目,启动失败异常状态结束脚本
if [[ ${projectStartStatus} != 0 ]]
then
    echo "匹配到启动失败日志标识符\"${LOG_FAIL_END_MARK}\"项目启动失败"
    exit 2
fi

echo "匹配到启动成功日志标识符\"${LOG_SUCCESS_END_MARK}\",项目启动成功"
echo "将 ${PROJECT_BULID_FILE_NAME} 备份到 ./backup/${PROJECT_NAME}-jenkins-${nowDate}.jar"
#判断文件夹是否存在
if [ ! -d "./backup" ]
then
    mkdir ./backup
fi
cp -a ./${PROJECT_BULID_FILE_NAME} ./backup/${PROJECT_NAME}-jenkins-${nowDate}.jar
