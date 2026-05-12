<p align="center"><br><br>
  <img src="docs/Main_img.png" alt="Icon Image" width="96">
</p>

# macOS용 DKST 한글입력기 

### 새소식
- **2026년 5월 12일 [ver.2.7.0 베타1](https://github.com/DINKIssTyle/DINKIssTyle-IME-macOS/releases/tag/v2.7.0-beta1)** 이 릴리즈 되었습니다.
- **2026년 5월 12일 [사전 데이타 업데이트](Dict.md)** 가 업데이트 되었습니다.
  
## ✅ macOS용 DKST 한글입력기를 사용하면 좋습니다. ###
- **더 이상 앱 단축키 사용을 위해 영어로 입력기를 변경하지 않아도 됩니다.**
- **모아치기**로 빠르게 타이핑 할 수 있습니다.
- **단모음/단자음에 쉬프트키**를 추가하여 원하는 **커스텀 입력**을 구성할 수 있습니다.
- **Apple 기본 특수문자**를 바로 이용할 수 있습니다.
- **Apple 기본 한자사전**을 이용해 한자를 입력할 수 있습니다.
- Apple 기본 한글 입력기보다 **병목 현상이 현저히 적습니다.**
- Apple 기본 한글 입력기보다 **CPU 점유율이 1/2수준으로 낮습니다.**
- Apple 기본 한글 입력기보다 **한/영 전환이 우수합니다.**
 
🔎 [Youtube 영상 | DKST macOS용 한글입력기 vs macOS 26 기본 한글입력기](https://www.youtube.com/watch?v=F6AHofQf0ls)
- macOS용 **DKST 한글입력기는 macOS에 Apple 스럽게 스며든 입력기**입니다.
- 영→한 변환 직후 **바로 입력해도 자소 분리**가 드뭅니다.
- 영→한 변환 직후 **바로 입력해도 로마자 출현**이 드뭅니다.



> 상세한 내용은 **아래 주요 특징**을 확인해주세요.

> **✅ 리눅스용 DKST 한글입력기**도 있습니다.
> https://github.com/DINKIssTyle/DINKIssTyle-IME-Ubuntu

---

# ⌨️ 주요 특징 소개

## 🤖 지능형 입력 엔진
사용 중인 앱의 환경을 스스로 분석하여 최적의 입력 방식을 결정합니다.
<div align="center"><img src="docs/Inline_Input.gif" alt="" width="300"/><br><br></div>  

* **스마트 자동 감지 및 전환**: 앱의 텍스트 입력 규격 준수 여부를 직접 확인하고 자동으로 판단합니다.  
    * **인라인 직접 입력**: 표준 규격을 준수하는 앱에서는 밑줄(Marked Text) 없는 매끄러운 직접 입력을 제공합니다.
    * **안전 조합 방식**: 지원이 불완전한 앱에서는 자동으로 밑줄 조합 방식으로 전환되어 안정적인 입력을 지원합니다.
* **전역 설정 및 앱별 예외 지정**: 
    * 환경설정에서 모든 앱의 입력 방식을 '밑줄 조합'으로 통일할 수 있습니다.
    * 자동 판단과 별개로 특정 앱을 예외 목록에 등록하여 항상 밑줄 방식을 사용하도록 강제할 수 있습니다.

## ✨ 입력 편의 및 커스텀 기능
단순한 입력을 넘어 사용자의 생산성을 극대화하는 기능을 포함합니다.

<div align="center"><img src="docs/Dict.gif" alt="" width="350"/><br><br></div>

* **[사전 입력 및 편집기](Dict_edit.md)**: 자주 사용하는 문구를 관리할 수 있는 전용 편집기를 제공합니다. 
* **모아치기 지원**: 직관적인 자소 조합을 지원합니다. (예: `ㅏ` + `ㄱ` = `가`)
* **단축 입력 확장**: 단모음/단자음을 `Shift` 키와 함께 입력할 때 커스텀 문구나 이모지가 출력되도록 설정 가능합니다. (예: `Shift` + `ㅇ` = `안녕하세요`)
* **세밀한 삭제 옵션**: 백스페이스 사용 시, 글자 조합이 완료되지 않은 상태에서도 자소 단위로 한 글자씩 제거하는 옵션을 제공합니다.

##  macOS 최적화 및 호환성
Mac의 고유한 사용 경험을 유지합니다.

* **시스템 테마 연동**: macOS의 다크/라이트 모드 변경에 따라 메뉴바 아이콘이 실시간으로 대응합니다.
  <div align="center"><br><img src="docs/SP_Layout.png" alt="" width="500"/></div>  

> [!NOTE]
> 옵션키 조합과 옵션+쉬프키 조합의 키보드 레이아웃

* **전통적 특수 문자 지원**: Mac 표준 방식인 `Option` 또는 `Option` + `Shift` 조합을 통한 특수 문자 입력을 완벽하게 지원합니다.
  
<div align="center"><br><img src="docs/macOS_hanja.png" alt="" width="450"/><br></div>  

* **macOS 한자 사전 지원**: 시스템의 한자 사전을 이용하여 한자 변환이 가능합니다.
  


* **단축키 간섭 방지**: 입력기가 타 앱의 한글 단축키를 가로채지 않도록 설계되어 작업 흐름을 방해하지 않습니다. (예: Final Cut Pro에서 `V(ㅍ)`, `B(ㅠ)`, `A(ㅁ)`가 작동합니다.)
* **Caps Lock 키를 사용하여 한/영 전환**: Caps Lock을 짧게 누르면 한/영이 전환되는 macOS의 기능입니다. 길게 누르면 대문자 고정(CapsLock 기능)이 됩니다. 이 기능은 시스템 설정 → 키보드 → 입력 소스에서 `Caps Lock 키로 ABC 입력 소스 전환` 을 켜야 작동합니다.

---


> [!CAUTION]
> **다음 환경에서 설치 및 사용 가능합니다.**  
> macOS 10.15 Catalina 이상   
> Universal Binary (애플실리콘맥 또는 인텔맥)

# 설치 또는 제거 방법 #
**터미널**을 열고 **아래 코드**를 붙여넣어 실행하세요.

**안정 된 버젼** 설치
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/DINKIssTyle/DINKIssTyle-IME-macOS/main/install.sh)"
```

<div><br></div>

**베타 릴리즈** 설치 (*주의 불안정할 수 있습니다.)

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/DINKIssTyle/DINKIssTyle-IME-macOS/main/install-beta.sh)"
```

<div><br></div>

설치할 파일을 내려받고 **다음 화면**이 표시됩니다.

```
==========================================
      DKST 한글 입력기 설치 도우미      
==========================================
1. DKST 한글 입력기 설치 (Install)
2. DKST 한글 입력기 아이콘 선택 설치 (Install)
3. DKST 한글 입력기 제거 (Uninstall)
4. 설치 도우미 닫기 (Exit)
==========================================
원하는 작업의 번호를 입력하세요 [1-4]: 
```
**설치**를 원하시면 **1 입력 후 엔터키** 입력,  
**제거**를 원하시면 **3 입력 후 엔터키**를 입력합니다.  

✨ **아이콘**을 변경하여 설치하려면 **2 입력 후 엔터키**를 누릅니다.
```
==========================================
      DKST 한글 입력기 설치 도우미      
      다음 중 상태 메뉴에 표시될 아이콘을 선택하세요. 
      *선택한 아이콘은 재부팅 후 표시 됩니다.
==========================================
1. 기본 아이콘 (Default 'Taegeuk symbol')
2. 아래아 '한' 아이콘 (Arae-a 'Han')
3. '한' (Han)
4. '가' (Ga)
5. '클래식' (Classic)
6. '앙' (Ang)
7. '앙' (Ang) 큰버젼
8. 뒤로 돌아가기 (Back)
==========================================
원하는 작업의 번호를 입력하세요 [1-6]: 
```

#### 1. 기본 아이콘 (Default 'Taegeuk symbol')
<div align="center">
<img src="docs/menu_icons/default.png" alt="" width="350">
</div>

#### 2. 아래아 '한' 아이콘 (Arae-a 'Han')
<div align="center">
<img src="docs/menu_icons/arae-a-han.png" alt="" width="350">
</div>

#### 3. '한' (Han)
<div align="center">
<img src="docs/menu_icons/han.png" alt="" width="350">
</div>

#### 4. '가' (Ga)
<div align="center">
<img src="docs/menu_icons/ga.png" alt="" width="350">
</div>


#### 5. '클래식' (Classic) *정식 탑재 미정
<div align="center">
<img src="docs/menu_icons/classic.png" alt="" width="350">
</div>

#### 6. '앙' (Ang)
<div align="center">
<img src="docs/menu_icons/ang.png" alt="" width="350">
</div>

#### 7. '앙' (Ang) 큰버젼
<div align="center">
<img src="docs/menu_icons/ang2.png" alt="" width="350">
</div>



> [!IMPORTANT] 
> **처음 설치하신 경우** `로그아웃` 후 다시 `로그인` 또는 `재부팅`해주세요.  
> 그렇지 않으면 `macOS용 DKST 한글입력기`가 **보이지 않습니다.**


# 사용 설정 방법

<div align="center">
  <img src="./docs/Syetem_preferences.gif" alt="" width="800">
</div>

1. **시스템 설정 열기**: 화면 왼쪽 상단의 `애플 메뉴()` > `시스템 설정`을 클릭합니다.
1. **키보드 설정 이동**: 사이드바에서 키보드를 클릭합니다.
1. **입력 소스 편집**: `텍스트 입력` 섹션에서 `편집...` 버튼을 클릭합니다.
1. **언어 추가**: 왼쪽 하단의 `+ (더하기)` 버튼을 클릭합니다.
1. **언어 및 자판 선택**: 왼쪽 목록에서 `한국어`를 선택하고, 오른쪽에서 회색조 아이콘의 `한글` 선택한 후 추가를 클릭합니다.

**[macOS용 DKST 한글입력기 환경설정 설명](Preferences.md)** 에서 상세 사용법을 확인하세요.

---

# 문제 해결 방법

1. 설치 후 **한글 입력이 작동하지 않습니다.**
    - 설치 후 재부팅 (로그아웃-로그인) 을 하고 입력기 등록을 활성화한 뒤 실행된 앱에서만 작동합니다. 켜져 있던 앱을 다시 실행하거나, 재부팅 또는 로그아웃-로그인을 한 번 더 시도해 보세요.

2. **특정 앱**에서 원하는 한글 입력이 안됩니다.
    - 다양한 앱 환경에 대응하도록 개발되었으나, 앱 자체가 다양한 커스텀 방식으로 제작되어 호환성 문제가 발생할 수 있습니다. 입력기 설정 → `밑줄 조합 방식으로 사용할 앱 Bundle ID` 에 해당 앱을 추가하면 호환성이 개선됩니다.



---

### ❗다양한 개발자들의 각양각색 서드파티 macOS용 한글입력기들을 알고 계신가요~?
* [**구름 입력기**](https://github.com/gureum/gureum): 편리하게, 가볍게, 자유롭게 라는 목표로 오랜기간 개발되어온 macOS용 한글 입력기 입니다.
* **[나빌 입력기 for 맥](https://github.com/navilera/NavilIMEforMac)**: 세별식 318, 세별식 390, 두벌식을 지원하는 가벼운 한글 입력기 입니다.
* **[속 입력기](https://github.com/kiding/SokIM)**: 빠르고 매끄러운 한영 전환을 위한 새로운 macOS 입력기
* **[Ongeul (온글)](https://github.com/hiking90/ongeul)**: macOS용 한글 입력기 — 하나의 입력 소스로 한글과 영문을 모두 처리합니다.

> Github 릴리즈 순 목록입니다.


## 응원과 후원

<div align="center">
<img src="docs/star.png" alt="" width="130"><br>
  이 프로젝트가 유용하셨다면, Star를 눌러 응원해주세요.<br><br>
</div>


<p align="center">
  <a href="https://github.com/sponsors/DINKIssTyle">
    <img src="https://img.shields.io/badge/Sponsor-EA4AAA?style=for-the-badge&logo=github-sponsors&logoColor=white" alt="Sponsor">
  </a>
  <br> 이 프로젝트가 아내 눈치 안보고 지속되길 바라신다면 위 버튼을 눌러주세요!
</p><br>


<div align="center">
  <a href="https://github.com/DINKIssTyle/DINKIssTyle-Markdown-Browser" target="_blank"><img src="https://github.com/DINKIssTyle/DINKIssTyle-Markdown-Browser/blob/main/DKST-Markdown.png?raw=true" width="150"></a><br>
이 README.md 파일은 DKST Markdown으로 작성되었습니다.<br>AI가 어시스트 하는 마크다운 에디터에 관심있으시다면 아래 배지를 클릭하세요.<br><br>
</div>

## 감사 인사. ##

AI의 시대가 도래한 덕분에 macOS용 한글 입력기를 직접 제작하게 되었습니다. 애플이 로제타2를 제거하는 시점에 다다르면서, 15년간 macOS의 열악했던 한글 입력 환경 속에서 묵묵히 저의 한글 입력을 도왔던 `한글입력기 바람` (https://baramim.blogspot.com) 을 이제는 떠나보내야 할 때가 왔기 때문입니다. 한글입력기 바람은 제 맥 라이프에서 산소처럼 소중한 동반자였습니다. 고마웠어요. 바람 입력기!

---
© 2026 DINKI'ssTyle. All rights reserved.
