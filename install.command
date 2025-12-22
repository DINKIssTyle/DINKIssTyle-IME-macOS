#!/bin/bash

# --- 설정 및 경로 ---
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE_APP="${SCRIPT_DIR}/build/DKST.app"
DEST_DIR="/Library/Input Methods"
DEST_APP="${DEST_DIR}/DKST.app"
PROCESS_NAME="DKST"

# --- 함수: 프로세스 종료 ---
function kill_dkst_process() {
    echo "🔄 변경 사항 적용을 위해 $PROCESS_NAME 프로세스를 종료합니다..."
    # pkill로 이름이 포함된 프로세스 강제 종료 (-9)
    # 2>/dev/null: 에러 메시지 숨김 / || true: 프로세스가 없어도 계속 진행
    sudo pkill -9 -f "$PROCESS_NAME" 2>/dev/null || true
}

# --- 화면 출력 및 메뉴 ---
clear
echo "=========================================="
echo "      DKST 한국어 입력기 설치 도우미      "
echo "=========================================="
echo "1. DKST 한국어 입력기 설치 (Install)"
echo "2. DKST 한국어 입력기 제거 (Uninstall)"
echo "3. 설치 도우미 닫기 (Exit)"
echo "=========================================="
read -p "원하는 작업의 번호를 입력하세요 [1-3]: " CHOICE

# --- 로직 처리 ---
case $CHOICE in
    1)
        echo ""
        echo "[설치 시작]"
        
        # 소스 파일 존재 여부 확인
        if [ ! -d "$SOURCE_APP" ]; then
            echo "오류: 설치할 앱을 찾을 수 없습니다."
            echo "경로 확인: $SOURCE_APP"
            echo "먼저 프로젝트를 빌드했는지 확인해주세요."
            exit 1
        fi

        echo "관리자 권한이 필요합니다. 비밀번호를 입력해주세요."
        
        # 1. 기존 파일 정리 및 새 파일 복사
        echo "기존 앱 파일 제거 및 새 파일 복사 중..."
        sudo rm -rf "$DEST_APP"
        sudo cp -R "$SOURCE_APP" "$DEST_DIR/"
        
        # 2. xattr 실행 (격리 해제)
        echo "확장 속성(quarantine) 제거 중..."
        sudo xattr -cr "$DEST_APP"
        
        # 3. [순서 변경됨] 설치 완료 후 프로세스 종료
        kill_dkst_process
        
        echo "[설치 완료]"
        SHOW_MESSAGE=true
        ;;
        
    2)
        echo ""
        echo "[제거 시작]"
        echo "관리자 권한이 필요합니다. 비밀번호를 입력해주세요."
        
        # 1. 파일 제거 수행
        if [ -d "$DEST_APP" ]; then
            sudo rm -rf "$DEST_APP"
            echo "파일이 제거되었습니다."
        else
            echo "설치된 입력기 파일이 없습니다."
        fi
        
        # 2. [순서 변경됨] 제거 완료 후 프로세스 종료
        kill_dkst_process
        
        echo "[제거 완료]"
        SHOW_MESSAGE=true
        ;;
        
    3)
        echo "프로그램을 종료합니다."
        exit 0
        ;;
        
    *)
        echo "잘못된 입력입니다. 스크립트를 종료합니다."
        exit 1
        ;;
esac

# --- 마무리 메시지 ---
if [ "$SHOW_MESSAGE" = true ]; then
    echo ""
    echo "******************************************************"
    echo " 작업이 완료되었습니다."
    echo " 프로세스가 종료되었습니다. 시스템이 자동으로 재실행하거나"
    echo " [로그아웃 후 다시 로그인]하면 적용됩니다."
    echo "******************************************************"
fi