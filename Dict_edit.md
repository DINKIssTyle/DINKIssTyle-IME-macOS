# Dictionary Editor에 관하여

**Dictionary Editor**는 본래 *한자 입력(대치) 기능*을 위해 존재하던 사전 파일을,  
한자 입력 목적이 아닌 **다른 용도의 입력 확장 기능**으로 활용하기 위해 도입되었습니다.

---

## 편집기의 사용 방법

- DKST 입력기로 전환된 **메뉴바**에서 **Dictionary Editor**를 클릭하여 실행할 수 있습니다.
<p align="center">
  <img src="docs/DKST_dict_01.png">
</p>

<p align="center">
  <img src="docs/DKST_dict_02.png">
</p>

- Dictionary Editor는 아래 경로 중 하나의 `hanja.txt` 파일을 편집합니다.
  - `/Library/Input Methods/DKST.app/Contents/Resources/hanja.txt`
  - `~/Library/Input Methods/DKST.app/Contents/Resources/hanja.txt`
- 현재 편집 중인 파일 경로는 **하단에 표시**됩니다.
- **검색 기능**을 통해 이미 등록된 트리거 글자/단어 또는 값을 빠르게 찾을 수 있습니다.
- 행 추가 및 삭제는 좌측 하단의 **+ Add**, **- Delete** 버튼을 사용합니다.
- 편집이 완료되면 **Save** 버튼을 눌러 저장합니다.
  - 파일 위치 특성상 **관리자 비밀번호 입력**이 필요합니다.
  - 사전 데이터 반영을 위해 **DKST 입력기를 강제 종료**합니다.
  - macOS는 사용 중인 IME가 종료되면 **1~2초 이내 자동으로 재활성화**됩니다.

---

## 한자 입력 기능을 이용한 활용

<p align="center">
  <img src="docs/DKST_dict_03.png">
</p>

- 트리거 글자를 입력한 뒤, **커밋되기 전에**
  **Option + Enter**  
  (우측 Shift 키 위에 위치한 Enter 키)을 눌러 **후보창**을 띄웁니다.
- 방향키로 원하는 항목을 선택한 후:
  - **Enter** 또는 **Space** 키로 입력할 수 있습니다.
- 이 과정은 **마우스 커서**를 이용해도 동일하게 사용할 수 있습니다.
- **단어 단위 트리거**의 경우:
  - 트리거 단어를 **드래그하여 선택(블록 지정)** 한 뒤
  - **Option + Enter**를 눌러 동일한 방식으로 사용할 수 있습니다.
