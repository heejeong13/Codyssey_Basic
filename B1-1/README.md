## 시스템 관제 자동화 스크립트 개발

### 체크리스트
- [x] SSH 포트 변경(20022) 및 Root 원격 접속 차단 설정 확인 내역  
- [x] 방화벽(UFW 또는 firewalld) 활성화 및 20022/tcp, 15034/tcp만 허용 내역
- [x] 계정/그룹(agent-admin/dev/test, agent-common/core) 생성 확인 내역
- [x] 디렉토리 구조 및 권한(ACL 포함) 확인 내역
- [ ] 앱 Boot Sequence 5단계 [OK] 및 "Agent READY" 확인 내역
- [ ] monitor.sh 실행 결과(프로세스/포트/리소스/경고) 내역
- [ ] /var/log/agent-app/monitor.log 누적 기록 확인(최근 라인) 내역
- [ ] crontab 매분 실행 등록 및 자동 실행 확인(1분 후 로그 증가) 내역

---
```bash
# 과제 진행을 위한 패키지 설치 커맨드
$ sudo apt update && sudo apt install -y vim openssh-server iproute2 sudo ufw acl

# ssh 서버 설치
$ sudo apt install -y openssh-server

# 네트워크 환경이나 상태 학인을 위한 패키지 설치
$ sudo apt install iproute2 

# sudo권한 사용을 위한 패키지 설치
$ sudo apt install sudo 

# 방화벽 설치
$ sudo apt install ufw

# acl 권한
$ sudo apt install acl
```
---

### 1. 기본 보안 및 네트워크 설정
**SSH 설정**
```bash
# ssh 설정 파일 확인
$ cat /etc/ssh/sshd_config

# ssh 포트 변경(20022) 및 Root 원격 접속 차단 설정
Port 20022
PermitRootLogin no

#ssh 설정 변경 후 재시작
$ sudo service ssh restart 

$ ss -tlpn
State   Recv-Q   Send-Q     Local Address:Port      Peer Address:Port  Process  
LISTEN  0        4096             0.0.0.0:20022          0.0.0.0:*              
LISTEN  0        4096                [::]:20022             [::]:*      
```

**방화벽 설정**
```bash
# 방화벽 활성화
$ sudo ufw enable

# 20022/tcp, 15034/tcp만 허용 
$ sudo ufw allow 20022/tcp
$ sudo ufw allow 15034/tcp

# 상태 확인
$ sudo ufw status
Status: active

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW       Anywhere                  
15034/tcp                  ALLOW       Anywhere                  
20022/tcp (v6)             ALLOW       Anywhere (v6)             
15034/tcp (v6)             ALLOW       Anywhere (v6)   
```

### 2. 계정/그룹/권한 체계(협업+최소 권한)
**계정 생성**
```bash
# 운영/관리, cron 실행자
$ sudo adduser agent-admin
# 개발/운영, monitor.sh 작성자
$ sudo adduser agent-dev
# QA/테스트
$ sudo adduser agent-test
```
**그룹 생성**
```bash
# 공통 작업을 위한 agent-common 그룹 생성
$ sudo groupadd agent-common

# 핵심 작업을 위한 agent-core 그룹 생성
$ sudo groupadd agent-core

# 그룹 생성 확인
$ cat /etc/group
```

**계정별 그룹 설정**
```bash
$ sudo usermod -aG agent-common,agent-core agent-admin
$ sudo usermod -aG agent-common,agent-core agent-dev
$ sudo usermod -aG agent-common agent-test
```

**계정 정보 확인**
```bash
$ id agent-admin
uid=1002(agent-admin) gid=1002(agent-admin) groups=1002(agent-admin),100(users),1000(agent-common),1001(agent-core)
$ id agent-dev
uid=1003(agent-dev) gid=1003(agent-dev) groups=1003(agent-dev),100(users),1000(agent-common),1001(agent-core)
$ id agent-test
uid=1004(agent-test) gid=1004(agent-test) groups=1004(agent-test),100(users),1000(agent-common)
```

**디렉토리 접근 권한 변경**
```bash
# 환경 변수 설정
$ export AGENT_HOME=/home/agent-admin/agent-app

# 디렉토리 생성(-p 옵션은 상위 디렉토리도 함께 생성)
$ sudo mkdir -p $AGENT_HOME/upload_files
$ sudo mkdir -p $AGENT_HOME/api_keys
$ sudo mkdir -p /var/log/agent-app

# 디렉토리 그룹 설정
# chmod 2770 -> 2 : SetGID 디렉터리 안에서 새로 생성되는 파일이나 디렉터리는 생성한 사용자의 그룹이 아닌, 부모 디렉터리의 그룹을 상속받음, chmod g+s와 동일
$ sudo chgrp agent-common $AGENT_HOME/upload_files
$ sudo chmod 2770 $AGENT_HOME/upload_files

$ sudo chgrp agent-core $AGENT_HOME/api_keys
$ sudo chmod 2770 $AGENT_HOME/api_keys

$ sudo chgrp agent-core /var/log/agent-app
$ sudo chmod 2770 /var/log/agent-app

# agent-common에게 실행 권한만 부여하여, 하위 폴더로 접근할 수 있도록함
$ sudo setfacl -m g:agent-common:--x /home/agent-admin
$ sudo setfacl -m g:agent-common:--x /home/agent-admin/agent-app

# 디렉토리 권한 확인
drwxrws---  1 root          agent-core   0 May 27 17:16 /var/log/agent-app
drwxrws---  1 agent-admin   agent-core   0 May 27 17:03 /home/agent-admin/agent-app/api_keys
drwxrws---  1 agent-admin   agent-common 0 May 27 17:06 /home/agent-admin/agent-app/upload_files
```
### 3. 애플리케이션 실행 환경 구성
### 4. 시스템 관제 자동화 스크립트 구현
### 5. 자동 실행 설정