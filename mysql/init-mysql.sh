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

cd mysql || { echo "디렉토리 변경 실패"; exit 1; }

# 실행중인 mysql container를 삭제
log "mysql container remove."
docker rm -f mysql

# 기존 mysql 이미지를 삭제하고 새로 빌드
log "mysql image remove and build."
docker rmi mysql:latest || true
docker build -t mysql:latest .

# 필요한 환경변수를 Vault에서 가져오기
log "Get credential data from vault..."

TOKEN_RESPONSES=$(curl -s --request POST \
  --data "{\"role_id\":\"${ROLE_ID}\", \"secret_id\":\"${SECRET_ID}\"}" \
  https://vault.nansan.site/v1/auth/approle/login)

CLIENT_TOKEN=$(echo "$TOKEN_RESPONSES" | jq -r '.auth.client_token')

SECRET_RESPONSE=$(curl -s --header "X-Vault-Token: ${CLIENT_TOKEN}" \
  --request GET https://vault.nansan.site/v1/kv/data/authentication)

MYSQL_ROOT_PASSWORD=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.mysql.password')
MYSQL_USER=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.mysql.username')
MYSQL_PASSWORD=$(echo "$SECRET_RESPONSE" | jq -r '.data.data.mysql.password')

# Docker로 mysql 서비스 실행
log "Execute mysql..."
docker run -d \
  --name mysql \
  --restart unless-stopped \
  -v /var/mysql:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
  -e MYSQL_USER=${MYSQL_USER} \
  -e MYSQL_PASSWORD=${MYSQL_PASSWORD} \
  --network nansan-network \
  mysql:latest

echo "작업이 완료되었습니다."
