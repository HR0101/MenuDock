#!/usr/bin/env bash
#
# notarize.sh
# MenuDock.app を署名し，DMG を作成して Apple の公証（notarization）まで行うスクリプト．
#
# 流れ: 署名(Hardened Runtime) -> app に staple -> DMG 作成 -> DMG 署名
#       -> notarytool で公証 -> DMG に staple -> 検証
#
# 使い方:
#   1) 初回のみ Keychain に資格情報を登録する（App 用パスワードは Keychain にのみ保存）:
#        xcrun notarytool store-credentials "MenuDock-Notary" \
#          --apple-id "you@example.com" \
#          --team-id  "XXXXXXXXXX" \
#          --password "xxxx-xxxx-xxxx-xxxx"   # appleid.apple.com で発行する App 用パスワード
#
#   2) 署名 ID（Developer ID Application）を環境変数で指定して実行:
#        SIGN_IDENTITY="Developer ID Application: Your Name (XXXXXXXXXX)" \
#          ./notarize.sh /path/to/MenuDock.app
#
#   引数を省略するとカレントディレクトリの MenuDock.app を対象にする．

set -euo pipefail

# ---- 設定（環境変数で上書き可能）-------------------------------------------

# 公証対象のアプリ名（拡張子なし）．出力 DMG の名前にも使う．
readonly APP_NAME="${APP_NAME:-MenuDock}"

# Keychain に store-credentials で登録したプロファイル名．
readonly KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-MenuDock-Notary}"

# 署名に使う Developer ID Application 証明書の名称．
# 未設定の場合は Keychain から自動検出を試みる．
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

# DMG のボリューム名と出力先．
readonly DMG_VOLNAME="${DMG_VOLNAME:-${APP_NAME}}"
readonly DMG_OUTPUT="${DMG_OUTPUT:-${APP_NAME}.dmg}"

# 対象 .app のパス（第1引数 > カレントの ${APP_NAME}.app の順で決定）．
APP_PATH="${1:-${APP_NAME}.app}"

# ---- ユーティリティ ---------------------------------------------------------

# エラーメッセージを表示して終了するヘルパー．
abort() {
  echo "エラー: $*" >&2
  exit 1
}

# 進捗見出しを表示するヘルパー．
step() {
  echo ""
  echo "==> $*"
}

# ---- 事前チェック -----------------------------------------------------------

step "事前チェック"

# 必要なコマンドの存在確認．
for cmd in codesign hdiutil xcrun; do
  command -v "${cmd}" >/dev/null 2>&1 || abort "${cmd} コマンドが見つかりません．Xcode Command Line Tools を導入してください．"
done

# notarytool / stapler が利用可能か確認．
xcrun notarytool --help >/dev/null 2>&1 || abort "xcrun notarytool が利用できません．Xcode を最新にしてください．"
xcrun stapler --help   >/dev/null 2>&1 || abort "xcrun stapler が利用できません．"

# 対象 .app の存在確認．
[ -d "${APP_PATH}" ] || abort "対象アプリが見つかりません: ${APP_PATH}"

# 署名 ID が未指定なら Keychain から自動検出する．
if [ -z "${SIGN_IDENTITY}" ]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep "Developer ID Application" \
    | head -n 1 \
    | sed -E 's/.*"(.+)"$/\1/')"
fi
[ -n "${SIGN_IDENTITY}" ] || abort "署名 ID（Developer ID Application）が見つかりません．SIGN_IDENTITY を指定してください．"

# Keychain プロファイルの存在を簡易確認（履歴提出を試して失敗したら警告）．
xcrun notarytool history --keychain-profile "${KEYCHAIN_PROFILE}" >/dev/null 2>&1 \
  || abort "Keychain プロファイル '${KEYCHAIN_PROFILE}' が未登録です．先に store-credentials を実行してください．"

echo "対象アプリ : ${APP_PATH}"
echo "署名 ID    : ${SIGN_IDENTITY}"
echo "プロファイル: ${KEYCHAIN_PROFILE}"
echo "出力 DMG   : ${DMG_OUTPUT}"

# ---- 1. アプリを署名（Hardened Runtime 付き）-------------------------------

step "1/6 アプリを署名（Hardened Runtime + タイムスタンプ）"
codesign --force --options runtime --timestamp \
  --sign "${SIGN_IDENTITY}" \
  "${APP_PATH}"
codesign --verify --strict --verbose=2 "${APP_PATH}"

# ---- 2. 既存 DMG の削除 -----------------------------------------------------

step "2/6 既存 DMG の掃除"
if [ -f "${DMG_OUTPUT}" ]; then
  rm -f "${DMG_OUTPUT}"
  echo "既存の ${DMG_OUTPUT} を削除しました．"
fi

# ---- 3. DMG を作成 ----------------------------------------------------------

step "3/6 DMG を作成"
hdiutil create \
  -volname "${DMG_VOLNAME}" \
  -srcfolder "${APP_PATH}" \
  -ov -format UDZO \
  "${DMG_OUTPUT}"

# ---- 4. DMG を署名 ----------------------------------------------------------

step "4/6 DMG を署名"
codesign --force --timestamp \
  --sign "${SIGN_IDENTITY}" \
  "${DMG_OUTPUT}"

# ---- 5. 公証を実行（完了まで待機）------------------------------------------

step "5/6 公証を実行（完了まで待機）"
# --wait で Accepted / Invalid が確定するまで待つ．失敗時はログを表示する．
if ! xcrun notarytool submit "${DMG_OUTPUT}" \
      --keychain-profile "${KEYCHAIN_PROFILE}" \
      --wait; then
  echo "" >&2
  echo "公証に失敗しました．直近の提出ログを確認してください:" >&2
  echo "  xcrun notarytool history --keychain-profile \"${KEYCHAIN_PROFILE}\"" >&2
  echo "  xcrun notarytool log <submission-id> --keychain-profile \"${KEYCHAIN_PROFILE}\"" >&2
  abort "notarytool submit が失敗しました．"
fi

# ---- 6. チケットを添付（staple）して検証 -----------------------------------

step "6/6 チケットを添付して検証"
xcrun stapler staple "${DMG_OUTPUT}"
xcrun stapler validate "${DMG_OUTPUT}"
spctl -a -t open --context context:primary-signature -v "${DMG_OUTPUT}" || true

step "完了"
echo "公証済み DMG を出力しました: ${DMG_OUTPUT}"
