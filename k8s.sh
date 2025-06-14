#!/bin/bash

# Kubernetes 환경 구축 스크립트
# Red Hat 계열 리눅스에서 Kubernetes 클러스터를 설정하기 위한 단계별 스크립트입니다.

echo '======== [4] Rocky Linux 기본 설정 ========'

# ======== [4-1] 패키지 업데이트 ========
# 시스템 패키지를 최신 상태로 유지하기 위해 업데이트를 수행
# 강의와 동일한 실습 환경을 유지하기 위해 주석 처리
yum -y update

# ======== [4-2] 타임존 설정 ========
# 시스템 시간을 서울로 설정하고 NTP(Network Time Protocol)를 활성화하여 시간 동기화
echo '======== [4-2] 타임존 설정 ========'
timedatectl set-timezone Asia/Seoul  # 타임존을 서울로 설정
timedatectl set-ntp true            # NTP 활성화
chronyc makestep                    # 즉시 시간 동기화

# ======== [4-3] 로그 관련 업데이트 ========
# Kubernetes 설치 중 발생할 수 있는 경고 로그를 방지하기 위한 패키지 설치 및 업데이트
echo '======== [4-3] [WARNING FileExisting-tc]: tc not found in system path 로그 관련 업데이트 ========'
yum install -y yum-utils iproute-tc  # 네트워크 트래픽 제어를 위한 tc 명령어 설치
echo '======== [4-3] [WARNING OpenSSL version mismatch 로그 관련 업데이트 ========'
yum update openssl openssh-server -y # OpenSSL 및 OpenSSH를 최신 버전으로 업데이트

# ======== [4-4] hosts 설정 ========
# 클러스터 내 통신을 위해 호스트 이름과 IP 주소를 매핑
echo '======= [4-4] hosts 설정 =========='
cat << EOF >> /etc/hosts
192.168.56.30 k8s-master  # k8s-master라는 호스트 이름을 192.168.56.30 IP에 매핑
EOF

# ======== [5] kubeadm 설치 전 사전작업 ========
#  kubeadm: Kubernetes 클러스터 설치 및 관리 cli 도구
#    - 클러스터 초기화: kubeadm init 명령으로 마스터 노드를 빠르게 설정 가능
#    - 노드 조인: 워커 노드를 클러스터에 쉽게 추가 가능(kubeadm join)
#    - 업그레이드 지원: 클러스터 버전 업그레이드를 도와줌
#    - 베어메탈, VM 등 다양한 환경 지원: 클라우드, 온프레미스 등 어디서나 사용 가능.
#    - 업그레이드 지원: 클러스터 버전 업그레이드를 도와줌

# 방화벽 해제 및 Swap 비활성화 ~ 특정 포트 여는 대신 아예 전부 여는 식으로 해결
echo '======== [5] 방화벽 해제 ========'
systemctl stop firewalld && systemctl disable firewalld  # 방화벽을 비활성화하여 클러스터 통신 방해 방지

echo '======== [5] Swap 비활성화 ========'
swapoff -a && sed -i '/ swap / s/^/#/' /etc/fstab  # Kubernetes는 Swap을 비활성화해야 정상 작동

# ======== [6] 컨테이너 런타임 설치 ========
# Kubernetes에서 컨테이너를 실행하기 위한 containerd 설치 및 설정
echo '======== [6-1] 컨테이너 런타임 설치 전 사전작업 ========'
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay          # 파일 시스템 오버레이 모듈 로드
br_netfilter     # 브릿지 네트워크 필터 모듈 로드
EOF

modprobe overlay       # overlay 모듈 활성화
modprobe br_netfilter  # br_netfilter 모듈 활성화

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1  # 브릿지 네트워크(파드 네트워크)에서 발생하는 트래픽들에 iptables 활성화 (Pod간 트래픽 제어)
net.bridge.bridge-nf-call-ip6tables = 1  # IPv6 iptables 활성화 (위랑 같이)
net.ipv4.ip_forward                 = 1  # IP 포워딩 활성화 (Pod간/외부 통신 허용) ~ 리눅스 커널이 패킷 포워딩을 허용하도록 설정 >  Pod에서 외부로 나가는 트래픽, 또는 노드 간 트래픽이 정상적으로 전달되도록 함
EOF
# IP forwarding: 리눅스 시스템이 들어온 네트워크 패킷을 자신의 목적지가 아닌 다른 네트워크로 **전달(라우팅)**할 수 있게 해주는 기능
# 기본적으로 리눅스는 라우터가 아니므로, 외부에서 들어온 패킷을 다른 네트워크로 전달X
#  net.ipv4.ip_forward = 1로 설정하면,
#  이 시스템이 라우터처럼 동작 ~ 예를 들어, Pod에서 외부 네트워크로 나가는 트래픽이나, 다른 노드에서 들어온 트래픽을 목적지로 **전달(포워딩)**할 수 있음 ~ 쿠버네티스설정시 반드시 활성화해야함

sysctl --system  # 위 설정을 시스템에 적용

echo '======== [6-2] 컨테이너 런타임 (containerd 설치) ========'
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo  # Docker 저장소 추가
yum install -y containerd.io-1.6.21-3.1.el9.aarch64  # containerd 설치 (쿠버네티스 1.27 버전과 호환되는 LTS 버전)
systemctl daemon-reload  # systemd 데몬 재로드
systemctl enable --now containerd  # containerd를 활성화하고 즉시 시작

echo '======== [6-3] 컨테이너 런타임 : cri 활성화 ========'
containerd config default > /etc/containerd/config.toml  # 기본 설정 파일 생성
sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml  # Systemd Cgroup 활성화
systemctl restart containerd  # containerd 재시작

# ======== [7] kubeadm 설치 ========
# Kubernetes 클러스터 초기화 및 관리 도구 설치
echo '======== [7] repo 설정 ========'
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.27/rpm/  # Kubernetes 패키지 저장소
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.27/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

echo '======== [7] SELinux 설정 ========'
setenforce 0  # SELinux를 permissive 모드로 설정 (보안 모드 느슨하게 설정)
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config  # 영구적으로 permissive 모드 설정

echo '======== [7] kubelet, kubeadm, kubectl 패키지 설치 ========'
yum install -y kubelet-1.27.2-150500.1.1.aarch64 kubeadm-1.27.2-150500.1.1.aarch64 kubectl-1.27.2-150500.1.1.aarch64 --disableexcludes=kubernetes  # Kubernetes 주요 패키지 설치
systemctl enable --now kubelet  # kubelet 활성화 및 시작

# ======== [8] kubeadm으로 클러스터 생성 ========
# Kubernetes 클러스터 초기화 및 네트워크 플러그인 설치
echo '======== [8-1] 클러스터 초기화 (Pod Network 세팅) ========'
kubeadm init --pod-network-cidr=20.96.0.0/16 --apiserver-advertise-address 192.168.56.30  # 클러스터 초기화
# CIDR 대역으로 20.96.0.0 ~ 20.96.255.255 대역 사용 가능 / 마스터 노드 노출 주소: 192.168.56.30 설정 (다른 노드와 통신시 사용)

echo '======== [8-2] kubectl 사용 설정 ========' # kube-apiserver에 CLI 접근 가능하도록 설정
mkdir -p $HOME/.kube  # kubectl 설정 디렉토리 생성
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config  # 클러스터 설정 복사 (admin.conf에는 인증서와 클러스터 정보가 포함됨)
chown $(id -u):$(id -g) $HOME/.kube/config  # 설정 파일 소유권 변경 ~ kubectl이 위 파일을 가지고 인증된 상태로 kube-apiserver에 통신 가능하게 됨

# calico: Pod 네트워크를 구성해주는 대표적인 CNI(Container Network Interface) 플러그인
#  CNI: 쿠버네티스 내에서 Pod간 통신을 가능하게 하는 네트워크 표준 인터페이스
#  calico ~ IP 주소 할당, 라우팅 담당, 네트워크 정책으로 보안규칙 설정 가능 (트래픽 허용/차단)
echo '======== [8-3] Pod Network 설치 (calico) ========'
kubectl create -f https://raw.githubusercontent.com/k8s-1pro/install/main/ground/k8s-1.27/calico-3.26.4/calico.yaml  # Calico 네트워크 플러그인 설치
kubectl create -f https://raw.githubusercontent.com/k8s-1pro/install/main/ground/k8s-1.27/calico-3.26.4/calico-custom.yaml  # Calico 커스텀 설정 설치

echo '======== [8-4] Master에 Pod를 생성 할수 있도록 설정 ========'
kubectl taint nodes k8s-master node-role.kubernetes.io/control-plane-  # Master 노드에서 Pod 실행 허용 (일반적으로 Master 노드에 유저가 생성하는 Pod를 실행하지 않지만, 실습을 위해 허용)

# ======== [9] 쿠버네티스 편의기능 설치 ========
# Kubernetes 관리 편의성을 위한 추가 기능 설치
echo '======== [9-1] kubectl 자동완성 기능 ========'
yum -y install bash-completion  # bash 자동완성 기능 설치
echo "source <(kubectl completion bash)" >> ~/.bashrc  # kubectl 자동완성 활성화
echo 'alias k=kubectl' >>~/.bashrc  # kubectl 별칭 설정
echo 'complete -o default -F __start_kubectl k' >>~/.bashrc  # 별칭 자동완성 활성화
source ~/.bashrc  # bashrc 재로드

echo '======== [9-2] Dashboard 설치 ========'
kubectl create -f https://raw.githubusercontent.com/k8s-1pro/install/main/ground/k8s-1.27/dashboard-2.7.0/dashboard.yaml  # Kubernetes 대시보드 설치

echo '======== [9-3] Metrics Server 설치 ========'
kubectl create -f https://raw.githubusercontent.com/k8s-1pro/install/main/ground/k8s-1.27/metrics-server-0.6.3/metrics-server.yaml  # Metrics Server 설치



# ======== [10] 게스트 OS 상태 확안 ========
/etc/*-release # OS 버전 확인
hostname # 호스트 이름 확인
ip addr # 네트워크 인터페이스 상태 확인 ~ inet 192.168.56.30/24
lscpu # CPU 정보 확인
free -h # 메모리 정보 확인
timedatectl # 시간대 및 NTP 설정 확인 (NTP: 네트워크 통해 시간 동기화 해주는 프로토콜 ~ timedatectl set-ntp true 로 설정 가능)
systemctl status firewalld # 방화벽 상태 확인
free || cat /etc/fstab | grep swap # Swap 비활성화 확인 (cat 에서는 swap 공간 정의 설정이 주석이어야)
# iptable 관련 셋업 (https://kubernetes.io/ko/docs/setup/production-environment/container-runtimes/#ipv4%EB%A5%BC-%ED%8F%AC%EC%9B%8C%EB%94%A9%ED%95%98%EC%97%AC-iptables%EA%B0%80-%EB%B8%8C%EB%A6%AC%EC%A7%80%EB%90%9C-%ED%8A%B8%EB%9E%98%ED%94%BD%EC%9D%84-%EB%B3%B4%EA%B2%8C-%ED%95%98%EA%B8%B0)
cat /etc/modules-load.d/k8s.conf
lsmod | grep overlay # obverlay(컨테이너 레이어드 파일 시스템 지원, 주요 컨테이너 런타임이 overlayFS를 기본 파일시스템 드라이버로 사용) 모듈 확인
lsmod | grep br_netfilter # br_netfilter(브릿지 네트워크에서 발생하는 패킷을 iptables로 전달하게 해줌 ~ Pod, 노느닥ㄴ 트래픽 제어에 필수) 모듈 확인
cat /etc/sysctl.d/k8s.conf # iptables 활성화, IP 포워딩 설정 확인
systemctl status containerd # containerd 상태 확인
systemctl status kubelet # kubelet 상태 확인 (active 아니면, systemctl restart kubelet 명령으로 재시작)
kubectl get -n kube-system cm kubelet-config -o yaml # kubelet 설정 확인 (cgroup-driver: systemd ~ redhat 계열 리눅스에서 kubelet이 systemd를 cgroup 드라이버로 사용하도록 설정)
sestatus || cat /etc/selinux/config # SELinux 상태 확인 (permissive 모드인지)

# ======== [11] 쿠버네티스 클러스터 확인 ========
kubectl get node # 마스터 노드 상태 확인
kubectl cluster-info dump | grep -m 1 cluster-cidr # pod network cidr 설정 확인
kubectl cluster-info # apiserver advertise address 적용 확인
kubectl get pods -n kube-system # kubernetes component pod 확인
# 쿠버네티스 클러스터가 정상적이지 않으면 아래 명령어로 초기화
  kubeadm reset
  kubeadm init --pod-network-cidr=20.96.0.0/12 --apiserver-advertise-address 192.168.56.30
cat ~/.kube/config # kubectl 설정 파일 확인 (인증서 확인, 서버 주소)
# Calico Pod 상태 확인
  kubectl get -n calico-system pod
  kubectl get -n calico-apiserver pod
  kubectl get installations.operator.tigera.io default -o yaml  | grep cidr # cidr 적용 확인
kubectl describe nodes | grep Taints # Master 노드 taint 설정 확인 (taint: 특정 조건이 맞지 않으면 Pod가 이 노드에 스케줄링되지 않도록 제한을 거는 기능)
cat ~/.bashrc # kube 편의 기능 (https://kubernetes.io/docs/reference/kubectl/quick-reference/)
kubectl get pod -n kubernetes-dashboard # 대시보드 Pod 상태 확인
kubectl get pod -n kube-system  | grep metrics # 메트릭 서버 Pod 상태 확인
kubectl top pod -A # 메트릭 서버 설치되었으면 > -A 옵션으로 모든 네임스페이스의 Pod 리소스 사용량 확인 가능


# ======== [12] 모니터링 시스템 세팅 ========
yum -y install git # git 설치
# 로컬 저장소 생성
git init monitoring
git config --global init.defaultBranch main
cd monitoring
git remote add -f origin https://github.com/k8s-1pro/install.git
git config core.sparseCheckout true # Git 저장소에서 전체가 아니라 일부 디렉토리/파일만 선택적으로 체크아웃(다운로드)할 수 있게 해주는 기능 활성화
echo "ground/k8s-1.27/prometheus-2.44.0" >> .git/info/sparse-checkout # Prometheus 설치 파일 경로
echo "ground/k8s-1.27/loki-stack-2.6.1" >> .git/info/sparse-checkout # Loki 설치 파일 경로
git pull origin main # sparse-checkout에 적힌 프로메테우스와 로키스택만 저장
# 프로메테우스 설치
kubectl apply --server-side -f ground/k8s-1.27/prometheus-2.44.0/manifests/setup # 프로메테우스 CRD(Custom Resource Definition) 설치
 # CRD: Kubernetes에 새로운 리소스 타입(예: Prometheus, Alertmanager 등)을 추가할 수 있게 해주는 확장 기능
 # --server-side 옵션: 서버에서 병합 및 적용을 처리하도록 하여, 리소스 충돌을 줄이고 선언적 관리에 적합
kubectl wait --for condition=Established --all CustomResourceDefinition --namespace=monitoring # CRD가 준비될 때까지 대기
kubectl apply -f ground/k8s-1.27/prometheus-2.44.0/manifests # 프로메테우스 설치
kubectl get pods -n monitoring
# 로키 스택 설치
kubectl apply -f ground/k8s-1.27/loki-stack-2.6.1
kubectl get pods -n loki-stack
# Prometheus 삭제
kubectl delete --ignore-not-found=true -f ground/k8s-1.27/prometheus-2.44.0/manifests -f ground/k8s-1.27/prometheus-2.44.0/manifests/setup
# Loki-stack 삭제
kubectl delete -f ground/k8s-1.27/loki-stack-2.6.1

# ======== [12] 오브젝트 확인 ========
kubectl describe svc kubernetes-dashboard -n kubernetes-dashboard # 파드의 노출된 포트번호확인 (targetPort 클러스터 내부, nodePort 클러스터 외부)

