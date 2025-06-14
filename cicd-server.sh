echo '======== [1] Rocky Linux 기본 설정 ========'
echo '======== [1-1] 패키지 업데이트 ========'
# echo: 화면에 텍스트를 출력하는 명령어 (진행 상황 표시용)

# yum -y update
# yum: Red Hat 계열 리눅스의 패키지 관리자
# -y: 모든 질문에 자동으로 "yes" 응답
# update: 설치된 모든 패키지를 최신 버전으로 업데이트 (주석 처리됨)

echo '======== [1-2] 타임존 설정 ========'
timedatectl set-timezone Asia/Seoul
# timedatectl: 시스템 시간 및 날짜 설정을 관리하는 명령어
# set-timezone: 시간대를 설정하는 옵션
# Asia/Seoul: 한국 표준시로 시간대 설정

echo '======== [1-3] 방화벽 해제 ========'
systemctl stop firewalld && systemctl disable firewalld
# systemctl: systemd 서비스를 관리하는 명령어
# stop firewalld: firewalld 서비스를 즉시 중지
# &&: 앞 명령어가 성공하면 뒤 명령어 실행
# disable firewalld: 시스템 재부팅 후에도 firewalld가 자동 시작되지 않도록 비활성화


echo '======== [2] Kubectl 설치 ========'
echo '======== [2-1] repo 설정 ========'
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.27/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.27/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF
# cat <<EOF: Here Document 시작 (EOF까지의 내용을 입력으로 사용)
# |: 파이프, 앞 명령어의 출력을 뒤 명령어의 입력으로 전달
# sudo tee: 관리자 권한으로 파일에 내용을 쓰는 명령어
# /etc/yum.repos.d/kubernetes.repo: Kubernetes 패키지 저장소 설정 파일 생성
# 이 설정으로 yum이 Kubernetes 패키지를 다운로드할 위치를 지정

echo '======== [2-2] Kubectl 설치 ========'
yum install -y kubectl-1.27.2-150500.1.1.aarch64 --disableexcludes=kubernetes
# yum install: 패키지 설치 명령어
# -y: 설치 확인 질문에 자동으로 "yes" 응답
# kubectl-1.27.2-150500.1.1.aarch64: 특정 버전의 kubectl 패키지 지정
# --disableexcludes=kubernetes: kubernetes 저장소의 exclude 설정을 무시하고 설치


echo '======== [3] 도커 설치 ========'
yum install -y yum-utils
# yum-utils: yum 패키지 관리자의 추가 유틸리티 설치

yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
# yum-config-manager: yum 저장소를 관리하는 도구
# --add-repo: 새로운 저장소를 추가하는 옵션
# Docker CE(Community Edition) 공식 저장소를 yum에 추가

yum install -y docker-ce-3:23.0.6-1.el9.aarch64 docker-ce-cli-1:23.0.6-1.el9.aarch64 containerd.io-1.6.21-3.1.el9.aarch64
# docker-ce: Docker Community Edition 엔진
# docker-ce-cli: Docker 명령줄 인터페이스
# containerd.io: 컨테이너 런타임
# 모두 특정 버전으로 설치 (aarch64는 ARM64 아키텍처)

systemctl daemon-reload
# systemctl daemon-reload: systemd 데몬을 다시 로드하여 새로운 서비스 파일을 인식

systemctl enable --now docker
# enable: 시스템 재부팅 시 자동으로 시작되도록 설정
# --now: 즉시 서비스 시작
# docker 서비스를 활성화하고 바로 시작


echo '======== [4] OpenJDK 설치  ========'
yum install -y java-17-openjdk
# java-17-openjdk: OpenJDK 17 버전 설치
# Jenkins와 Gradle 실행에 필요한 Java 환경


echo '======== [5] Gradle 설치  ========'
yum -y install wget unzip
# wget: 웹에서 파일을 다운로드하는 도구
# unzip: ZIP 파일을 압축 해제하는 도구

wget https://services.gradle.org/distributions/gradle-7.6.1-bin.zip -P ~/
# wget으로 Gradle 7.6.1 바이너리 배포판을 홈 디렉토리(~/)에 다운로드
# -P: 다운로드할 디렉토리 지정

unzip -d /opt/gradle ~/gradle-*.zip
# unzip: ZIP 파일 압축 해제
# -d /opt/gradle: 압축을 해제할 목적지 디렉토리 지정
# ~/gradle-*.zip: 홈 디렉토리의 gradle로 시작하는 zip 파일

cat <<EOF |tee /etc/profile.d/gradle.sh
export GRADLE_HOME=/opt/gradle/gradle-7.6.1
export PATH=/opt/gradle/gradle-7.6.1/bin:${PATH}
EOF
# 환경변수 설정 파일 생성
# GRADLE_HOME: Gradle 설치 경로 설정
# PATH: Gradle 실행 파일 경로를 시스템 PATH에 추가

chmod +x /etc/profile.d/gradle.sh
# chmod: 파일 권한 변경
# +x: 실행 권한 추가
# 환경변수 설정 파일에 실행 권한 부여

source /etc/profile.d/gradle.sh
# source: 스크립트 파일을 현재 셸에서 실행
# 환경변수 설정을 즉시 적용


echo '======== [6] Git 설치  ========'
yum install -y git
# git: 버전 관리 시스템 설치
# 소스코드 관리 및 Jenkins와의 연동에 필요


echo '======== [7] Jenkins 설치  ========'
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
# wget -O: 다운로드한 파일을 지정된 이름으로 저장
# Jenkins 공식 저장소 설정 파일을 다운로드

rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
# rpm --import: GPG 키를 RPM 데이터베이스에 추가
# Jenkins 패키지의 디지털 서명을 검증하기 위한 공개키 가져오기

yum install -y jenkins-2.440.3-1.1
# Jenkins 특정 버전(2.440.3-1.1) 설치

systemctl enable jenkins
# Jenkins 서비스를 시스템 시작 시 자동으로 실행되도록 설정

systemctl start jenkins
# Jenkins 서비스를 즉시 시작