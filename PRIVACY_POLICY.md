# 개인정보처리방침 (Privacy Policy) — musicdm

**시행일:** 2026-11-21  
**앱 이름:** musicdm (`com.realdm99.musicdm`)  
**개발자:** realdm99

## 1. 개인정보 수집 및 전송 여부
`musicdm`은 기기 내 로컬 오디오(MP3) 파일을 재생하는 **오프라인 음악 플레이어**입니다.
- 회원가입, 로그인, 서버 통신, 광고 SDK, 분석(Analytics) SDK를 사용하지 않습니다.
- 사용자의 개인정보나 기기 내 오디오 파일, 재생 목록 데이터를 외부 서버로 수집·전송·공유하지 않습니다.

## 2. 앱 권한 사용 안내
- **오디오 파일 읽기 (`READ_MEDIA_AUDIO` / `READ_EXTERNAL_STORAGE`)**: 기기에 저장된 MP3 파일을 스캔하여 목록에 표시하고 재생하기 위해서만 사용됩니다.
- **포그라운드 서비스 및 미디어 재생 (`FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `WAKE_LOCK`)**: 화면이 꺼지거나 다른 앱을 사용하는 동안에도 백그라운드에서 음악을 끊김 없이 재생하고 상단 알림창 미디어 컨트롤을 제공하기 위해 사용됩니다.

## 3. 기기 내 로컬 저장 데이터
아래 정보는 오직 사용자 기기 내부(SQLite 및 SharedPreferences)에만 저장되며 앱 삭제 시 함께 제거됩니다.
- 사용자가 생성한 플레이리스트 및 수록곡 순서
- 마지막 재생 곡 및 재생 위치 (이어서 재생 기능용)
- 사용자가 선택한 테마(라이트/다크 모드 및 강조 색상) 및 직접 불러온 로컬 MP3 경로

## 4. 문의
개인정보처리방침과 관련한 문의는 GitHub 저장소 이슈([https://github.com/realdm99-1/musicdm/issues](https://github.com/realdm99-1/musicdm/issues))를 통해 연락해 주세요.
