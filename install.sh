#!/bin/bash

# --- 설정 및 경로 ---
# 스크립트가 있는 현재 폴더 경로를 절대 경로로 가져옵니다.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# [수정됨] 스크립트 위치 하위의 build 폴더 안의 앱을 바라보도록 설정
SOURCE_APP="${SCRIPT_DIR}/build/DKST.app"

DEST_DIR="/Library/Input Methods"
DEST_APP="${DEST_DIR}/DKST.app"

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
        
        # 1. 기존 파일 정리 및 복사
        sudo rm -rf "$DEST_APP"
        
        # build 폴더에서 복사
        sudo cp -R "$SOURCE_APP" "$DEST_DIR/"
        
        # 2. xattr 실행 (격리 해제)
        echo "확장 속성(quarantine) 제거 중..."
        sudo xattr -cr "$DEST_APP"
        
        echo "[설치 완료]"
        SHOW_MESSAGE=true
        ;;
        
    2)
        echo ""
        echo "[제거 시작]"
        echo "관리자 권한이 필요합니다. 비밀번호를 입력해주세요."
        
        # 1. 제거 수행
        if [ -d "$DEST_APP" ]; then
            sudo rm -rf "$DEST_APP"
            echo "제거되었습니다."
        else
            echo "설치된 입력기가 없습니다."
        fi
        
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
    echo " 변경 사항을 완벽하게 적용하려면 반드시"
    echo " [로그아웃 후 다시 로그인]하거나 [재부팅] 해주세요."
    echo "******************************************************"
fi