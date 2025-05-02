#!/bin/bash

# 명령어 실패 시 스크립트 종료
set -euo pipefail

# 로그 출력 함수
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# 에러 발생 시 로그와 함께 종료하는 함수
error() {
  log "Error on line $1"
  exit 1
}

trap 'error $LINENO' ERR

log "스크립트 실행 시작."

# docker network 생성
if docker network ls --format '{{.Name}}' | grep -q '^nansan-network$'; then
  log "Docker network named 'nansan-network' is already existed."
else
  log "Docker network named 'nansan-network' is creating..."
  docker network create --driver bridge nansan-network
fi

# 실행중인 phpMyAdmin 삭제
log "phpmyadmin container remove."
docker rm -f phpmyadmin

# 기존 phpmyadmin 이미지를 삭제하고 새로 빌드
log "phpmyadmin image remove and build."
docker rmi phpmyadmin:latest || true
docker build -t phpmyadmin:latest .

# Docker로 phpmyadmin 서비스 실행
log "Execute phpmyadmin..."
docker run -d \
  --name phpmyadmin \
  --restart unless-stopped \
  -p 11000:80 \
  -e PMA_HOST=mysql \
  -e PMA_PORT=3306 \
  --network nansan-network \
  phpmyadmin:latest

echo "작업이 완료되었습니다."
