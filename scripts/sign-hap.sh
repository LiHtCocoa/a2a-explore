#!/usr/bin/env bash
# 受信任的 HAP 后签名辅助脚本（只做签名，不重新编译、不执行 artifact 内任何内容）。
# 用法: sign-hap.sh <unsigned.hap> <out.hap>
#
# 签名材料全部经环境变量传入（来自 GitHub Environment "signing" 的 Secrets，禁止提交到仓库）:
#   HAP_P12_BASE64 / HAP_CER_BASE64 / HAP_P7B_BASE64 / HAP_KEY_ALIAS / HAP_KEY_PASSWORD / HAP_STORE_PASSWORD
# 临时签名文件在退出时自动删除。
set -euo pipefail

IN_FILE="${1:?usage: sign-hap.sh <unsigned.hap> <out.hap>}"
OUT_FILE="${2:?usage: sign-hap.sh <unsigned.hap> <out.hap>}"

: "${HAP_P12_BASE64:?缺少 secret HAP_P12_BASE64}"
: "${HAP_CER_BASE64:?缺少 secret HAP_CER_BASE64}"
: "${HAP_P7B_BASE64:?缺少 secret HAP_P7B_BASE64}"
: "${HAP_KEY_ALIAS:?缺少 secret HAP_KEY_ALIAS}"
: "${HAP_KEY_PASSWORD:?缺少 secret HAP_KEY_PASSWORD}"
: "${HAP_STORE_PASSWORD:?缺少 secret HAP_STORE_PASSWORD}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "$HAP_P12_BASE64" | base64 -d > "$WORK/app.p12"
echo "$HAP_CER_BASE64" | base64 -d > "$WORK/app.cer"
echo "$HAP_P7B_BASE64" | base64 -d > "$WORK/app.p7b"
test -s "$WORK/app.p12" || { echo "HAP_P12_BASE64 解码后为空" >&2; exit 1; }
test -s "$WORK/app.cer" || { echo "HAP_CER_BASE64 解码后为空" >&2; exit 1; }
test -s "$WORK/app.p7b" || { echo "HAP_P7B_BASE64 解码后为空" >&2; exit 1; }

JAR="command-line-tools/sdk/default/openharmony/toolchains/lib/hap-sign-tool.jar"
test -f "$JAR" || { echo "找不到 hap-sign-tool.jar: $JAR" >&2; exit 1; }
mkdir -p "$(dirname "$OUT_FILE")"

java -jar "$JAR" sign-app \
  -keyAlias "$HAP_KEY_ALIAS" \
  -signAlg SHA256withECDSA \
  -mode localSign \
  -appCertFile "$WORK/app.cer" \
  -profileFile "$WORK/app.p7b" \
  -inFile "$IN_FILE" \
  -keystoreFile "$WORK/app.p12" \
  -outFile "$OUT_FILE" \
  -keyPwd "$HAP_KEY_PASSWORD" \
  -keystorePwd "$HAP_STORE_PASSWORD"

echo "签名完成: $OUT_FILE"
