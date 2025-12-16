#!/usr/bin/env python3
import os
import sys
import subprocess

# --- 설정 및 경로 ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SOURCE_APP = os.path.join(SCRIPT_DIR, "build", "DKST.app")
DEST_DIR = "/Library/Input Methods"
DEST_APP = os.path.join(DEST_DIR, "DKST.app")
PROCESS_NAME = "DKST"

# --- 함수: AppleScript 실행 (GUI 창 띄우기) ---
def run_applescript(script):
    """AppleScript를 실행하고 결과를 반환합니다."""
    try:
        result = subprocess.run(['osascript', '-e', script], capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except subprocess.CalledProcessError:
        return None

# --- 함수: 관리자 권한으로 쉘 명령 실행 (GUI 비밀번호 창) ---
def run_command_as_admin(shell_cmd):
    """
    'do shell script ... with administrator privileges'를 사용하여
    macOS 기본 인증 창을 띄우고 명령어를 실행합니다.
    """
    # AppleScript 구문에 맞게 따옴표 이스케이프 처리
    safe_cmd = shell_cmd.replace('"', '\\"')
    script = f'do shell script "{safe_cmd}" with administrator privileges'
    return run_applescript(script)

# --- 함수: 프로세스 종료 ---
def kill_dkst_process():
    # pkill 명령은 실패(프로세스 없음)할 수 있으므로 try-catch 또는 || true 처리 필요
    # 여기서는 간단히 실행만 시도
    cmd = f"pkill -9 -f '{PROCESS_NAME}' || true"
    run_command_as_admin(cmd)

# --- 함수: 알림창 표시 ---
def show_alert(message, title="알림"):
    script = f'display dialog "{message}" buttons {{"확인"}} default button "확인" with title "{title}"'
    run_applescript(script)

# --- 메인 로직 ---
def main():
    # 1. 메뉴 선택 창 띄우기
    menu_script = '''
    display dialog "DKST 한국어 입력기 설치 관리자" buttons {"종료", "제거 (Uninstall)", "설치 (Install)"} default button "설치 (Install)" with title "DKST Setup" with icon note
    '''
    choice_result = run_applescript(menu_script)

    if not choice_result:
        # 사용자가 취소를 누르거나 창을 닫음
        sys.exit(0)

    # AppleScript 결과 예: "button returned:설치 (Install)"
    
    if "설치 (Install)" in choice_result:
        # --- 설치 로직 ---
        if not os.path.exists(SOURCE_APP):
            show_alert(f"오류: 설치할 앱을 찾을 수 없습니다.\n\n경로: {SOURCE_APP}", "오류")
            sys.exit(1)
        
        # 여러 명령어를 한 번의 sudo 세션으로 묶어서 실행 (비밀번호 1번만 입력)
        # 1. 기존 삭제 -> 2. 복사 -> 3. 속성 제거 -> 4. 프로세스 킬
        cmds = [
            f"rm -rf '{DEST_APP}'",
            f"cp -R '{SOURCE_APP}' '{DEST_DIR}/'",
            f"xattr -cr '{DEST_APP}'",
            f"pkill -9 -f '{PROCESS_NAME}' || true"
        ]
        full_cmd = " ; ".join(cmds)
        
        result = run_command_as_admin(full_cmd)
        
        # AppleScript가 성공적으로 실행되면 result는 빈 문자열이거나 출력값임. None이면 취소/실패.
        if result is not None:
            show_alert("설치가 완료되었습니다.\n로그아웃 후 다시 로그인하면 적용됩니다.", "성공")

    elif "제거 (Uninstall)" in choice_result:
        # --- 제거 로직 ---
        if os.path.exists(DEST_APP):
            cmds = [
                f"rm -rf '{DEST_APP}'",
                f"pkill -9 -f '{PROCESS_NAME}' || true"
            ]
            full_cmd = " ; ".join(cmds)
            
            result = run_command_as_admin(full_cmd)
            
            if result is not None:
                show_alert("제거가 완료되었습니다.", "성공")
        else:
            show_alert("설치된 파일이 없습니다.", "알림")
            
    else:
        # 종료
        sys.exit(0)

if __name__ == "__main__":
    main()