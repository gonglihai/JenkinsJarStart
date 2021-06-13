# Jenkins Jar包自动化部署脚本
自动杀死旧版本,自动备份旧版本日志文件、服务包文件

## 使用说明: 
将此脚本与jar包存放于同一目录,配置项目信息.

#目录结构:

```
./
 ├─ backup                                     - jar包备份目录
 │  └─ project-jenkins-yyyy-mm-dd-HH-MM.jar    - 以 jenkins-yyyy-mm-dd-HH-MM 结尾的备份包
 ├─ project.jar                                - 当前版本的jar包
 ├─ jenkins-start.sh                           - jenkins启动脚本
 └─ log                                        - 日志目录
    └─ project.log                             - 当前版本项目的日志
```
