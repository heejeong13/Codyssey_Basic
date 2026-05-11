## 시스템 관제 자동화 스크립트 개발

### 체크리스트
- [x] SSH 포트 변경(20022) 및 Root 원격 접속 차단 설정 확인 내역  
- [x] 방화벽(UFW 또는 firewalld) 활성화 및 20022/tcp, 15034/tcp만 허용 내역
- [ ] 계정/그룹(agent-admin/dev/test, agent-common/core) 생성 확인 내역
- [ ] 디렉토리 구조 및 권한(ACL 포함) 확인 내역
- [ ] 앱 Boot Sequence 5단계 [OK] 및 "Agent READY" 확인 내역
- [ ] monitor.sh 실행 결과(프로세스/포트/리소스/경고) 내역
- [ ] /var/log/agent-app/monitor.log 누적 기록 확인(최근 라인) 내역
- [ ] crontab 매분 실행 등록 및 자동 실행 확인(1분 후 로그 증가) 내역

---
```bash
# privileged 모드로 실행하면 컨테이너에서도 시스템의 주요 자원에 접근이 가능
$ docker run -it --privileged --name my-ubuntu ubuntu:22.04
$ apt-get update
$ apt-get install vim

# ssh 서버 설치
$ apt-get install -y openssh-server

#네트워크 환경이나 상태 학인을 위한 패키지 설치
$ apt install iproute2 

# sudo권한 사용을 위한 패키지 설치
$ apt-get install sudo 

# 방화벽 설치
$ apt-get install ufw
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
State  Recv-Q Send-Q Local Address:Port   Peer Address:Port Process                       
LISTEN 0      128          0.0.0.0:20022       0.0.0.0:*     users:(("sshd",pid=98,fd=3)) 
LISTEN 0      128             [::]:20022          [::]:*     users:(("sshd",pid=98,fd=4)) 
```

**방화벽 설정**
```bash
#방화벽 활성화
$ ufw enable

# 20022/tcp, 15034/tcp만 허용 
$ ufw allow 20022/tcp
$ ufw allow 15034/tcp

# 상태 확인
$ ufw status
Status: active

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW       Anywhere                  
15034/tcp                  ALLOW       Anywhere                  
20022/tcp (v6)             ALLOW       Anywhere (v6)             
15034/tcp (v6)             ALLOW       Anywhere (v6)   
```

### 2. 계정/그룹/권한 체계(협업+최소 권한)
### 3. 애플리케이션 실행 환경 구성
### 4. 시스템 관제 자동화 스크립트 구현
### 5. 자동 실행 설정