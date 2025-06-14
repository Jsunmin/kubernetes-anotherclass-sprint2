#!/bin/bash

yum install -y tar # tar 패키지 설치 (압축 해제 명령어가 없을 경우를 대비)

curl -O https://get.helm.sh/helm-v3.13.2-linux-arm64.tar.gz # Helm 바이너리 패키지 다운로드 (v3.13.2, ARM64 리눅스용)

tar -zxvf helm-v3.13.2-linux-arm64.tar.gz # 다운로드한 Helm 압축 파일을 현재 디렉토리에 풀기

mv linux-arm64/helm /usr/bin/helm # 압축 해제된 디렉토리에서 helm 실행 파일을 /usr/bin/helm으로 이동(설치)

helm version # (선택) 설치된 helm 버전 확인

Helm 구성요소
- Chart: 쿠버네티스 리소스(yaml 파일)의 패키지 ~ 여러 yaml을 템플릿화해서 묶어둔 것
  - Chart.yaml: Chart의 메타데이터 파일
  - values.yaml: Chart의 기본값 설정 파일
  - templates/: Chart에서 사용하는 템플릿 파일들이 위치하는 디렉토리
  - charts/: Chart에서 사용하는 다른 Chart들을 포함하는 디렉토리

- Release: 특정 Chart가 실제로 배포된 인스턴스 (쿠버네티스 클러스터)
  - Chart와 Release의 차이점: Chart는 템플릿, Release는 실제로 설치된 인스턴스
    - 하나의 차트로 dev, staging, production 환경에 각각 다른 Release를 배포함
  - 릴리즈마다 버전, values.yaml, templates 등이 다를 수 있음

- Repository: 여러 Chart를 저장하는 저장소
    - 아티팩트허브 (구 헬름허브), Bitnami 등
    - 예시: api-tester라는 Chart를 설치하면 api-tester라는 Release가 생성됨

- Helm Client: 명령어로 차트 설치, 첩그레이트, 삭제 등 수행

- Temlpaltes, Values
    - 동적 리소스 생성에 쓰이는 틀과 실제 변수 인풋값

echo '======== [1] Jenkins w/ heml ========'
su - jenkins -s /bin/bash
helm version
helm create api-tester # helm 차트 생성
