# ⚖ 오늘의 판결
사소한 갈등, 거창하게 판결합니다. HTML/CSS/JavaScript + GitHub + Vercel + Supabase 기반 MVP.

## 들어 있는 기능
- 반응형 대시보드, 카테고리·제목/본문 검색, 최신순·투표순, 내가 내린 판결
- A/B 투표, 투표 이후 결과 공개, 한 줄 변론, 링크 공유
- 사연 등록: 데모는 즉시 로컬 공개, 실제 서비스는 운영자 승인 대기
- 새로고침으로 최신 데이터 조회 (실시간 구독 아님)
- 연결 설정이 없으면 로컬 데모. 데모 데이터와 실제 DB는 별개이며 자동 이전하지 않음.
- 예시 사연 4건, 가상의 기존 표나 이용자 수 없음

## 1. 먼저 체험하기
index.html과 config.js를 같은 폴더에 두고 index.html을 브라우저에서 열면 데모로 작동합니다.
별도로 제공한 오늘의판결_미리보기.html은 설정 파일도 포함한 단일 파일 데모입니다.
데모 투표·댓글·새 사연은 해당 브라우저 localStorage에 저장됩니다.

## 2. Supabase 설정
1. Supabase에서 새 프로젝트를 만듭니다.
2. SQL Editor에서 schema.sql 전체를 한 번 실행합니다. 기존 프로젝트에 중복 실행하지 마세요. 이 스크립트는 새 설치용이며 마이그레이션이 아닙니다.
3. Authentication에서 Anonymous Sign-Ins(익명 로그인)를 활성화합니다.
4. 프로젝트 Connect 또는 Settings > API Keys에서 Project URL과 Publishable key(sb_publishable_...)를 확인합니다.
5. 아래 Vercel 환경변수로 입력합니다. Secret key나 legacy service_role key는 절대 프런트엔드·저장소에 넣지 마세요. 키를 채팅으로 보낼 필요도 없습니다.

## 3. GitHub에 올리기
1. 새 저장소를 만듭니다.
2. ZIP을 풀고 프로젝트 폴더 안 파일을 저장소 최상위에 업로드합니다. index.html, config.js, build.mjs, package.json, vercel.json, schema.sql, README.md와 숨김 파일을 포함하세요.
3. 비밀번호나 비밀 키 파일은 올리지 않습니다. config.js는 비어 있는 데모 설정 그대로 유지해도 됩니다.

## 4. Vercel 배포
1. Vercel > Add New > Project에서 해당 GitHub 저장소를 Import합니다.
2. Framework Preset은 Other. Root Directory는 package.json이 위치한 폴더입니다.
3. Build Command: npm run build / Output Directory: dist. vercel.json에도 설정되어 있습니다. 별도 설치 의존성은 없습니다.
4. Environment Variables에 다음 두 값을 추가합니다.
   - SUPABASE_URL = Supabase Project URL
   - SUPABASE_PUBLISHABLE_KEY = sb_publishable_... 형태의 공개 키
5. Deploy를 누릅니다. 환경변수를 나중에 바꾸면 반드시 Redeploy합니다.
6. Supabase Authentication의 Site URL에 배포 도메인을 등록합니다. 현재 익명 로그인에는 리디렉션 흐름을 사용하지 않습니다.

둘 다 비우면 데모 배포가 됩니다. 하나만 입력하거나 Secret key를 쓰면 빌드가 실패합니다.
환경변수 값은 빌드 중 dist/config.js로 만들어져 브라우저에 전달됩니다. Publishable key는 공개용이고 접근 통제는 DB의 권한/RLS/RPC가 담당합니다.

## 5. 운영자가 사연 승인·숨기기
이 MVP는 관리자 화면 대신 Supabase Table Editor를 사용합니다. 일반 사용자는 테이블에 직접 접근할 수 없습니다.
- cases: status=pending인 사연의 제목·본문·선택지 검토 후 published로 변경
- 숨길 사연: cases.status=hidden
- 숨길 변론: comments.hidden=true
실명·개인정보·비방 등이 없는지 확인하세요. 변론은 즉시 공개이므로 초기 운영 중 모니터링이 필요합니다.

## 보안과 한계 — 외부 공개 전 필독
- 모든 테이블에 RLS 활성화, anon/authenticated의 직접 테이블 권한 제거. authenticated에 get_board/participate RPC만 허용합니다.
- SECURITY DEFINER 함수는 빈 search_path와 명시적 스키마를 사용합니다. 사용자 ID는 클라이언트가 아닌 auth.uid()에서 가져옵니다.
- 투표 PK(case_id,user_id)로 한 세션당 한 표. 투표 전 결과를 DOM뿐 아니라 서버 응답에서도 숨깁니다. 전체 투표수는 공개합니다.
- 댓글은 투표 후 작성 가능, 사용자별 30초 간격. 사연은 사용자별 24시간에 최대 3건. 같은 사용자의 요청은 DB 잠금으로 직렬화합니다.
- 익명 인증은 '한 사람 한 표'를 보증하지 않습니다. 브라우저 데이터 삭제/기기 변경/새 익명 계정으로 우회 가능하므로 공신력 있는 여론조사에 사용하지 마세요.
- Supabase는 익명 가입에 CAPTCHA/Turnstile 사용을 강력 권장합니다. 현재 CAPTCHA 위젯/토큰 전송은 미구현입니다. 공개 홍보 전 위젯 추가 및 signInAnonymously({options:{captchaToken}}) 연결, Auth 속도 제한 조정, 악성 사용자 차단, 신고 기능을 추가하세요. CAPTCHA만 켜면 이 버전의 신규 익명 로그인은 실패할 수 있습니다.
- 자동 금칙어 필터, 댓글 신고 UI, 별도 관리자 UI, 계정 복구/정식 로그인, 보존기간·삭제 자동화, 트래픽 규모별 페이징은 미구현입니다. 익명 계정 데이터 보존·삭제 운영 정책을 별도로 정하세요.
- 게시판은 최신 공개 사연 최대 100건, 댓글은 사연별 최근 30건. KPI도 표시된 사연 범위입니다. 댓글 표시는 최근 댓글 수이며 전체 누적 댓글 수가 아닙니다.
- SDK는 실제 연결 모드에서 jsDelivr의 @supabase/supabase-js@2를 동적 로드합니다. 인터넷이 필요합니다. 정식 운영 시 정확한 SDK 버전을 고정·번들링하는 것을 권장합니다.
- DB 연결 오류를 데모로 숨기지 않고 화면에 표시합니다.
- SQL Editor/Table Editor는 운영자 권한이므로 접근 계정을 보호하세요.
- 이 결과물은 소규모 테스트용 MVP이며, 외부 대규모 오픈 전 보안·운영 검토가 필요합니다.

## 연결 후 직접 점검
- 첫 접속에서 LIVE 표시. 표가 0인 예시 사연에 투표하고 1표로 바뀌는지 확인
- 새로고침 후 내 투표 유지 및 중복 투표 불가
- 다른 브라우저에서 반대쪽 투표 → 새로고침 시 합계 2표
- 댓글에 <script> 같은 문자열을 넣어도 텍스트로만 표시되는지 확인
- 투표 전 get_board 응답에서 a/b가 null인지 확인
- 새 사연 제출 → Table Editor에서 pending 확인 → 승인 후 목록 반영
- 댓글 숨김 및 사연 숨김 반영
- 모바일 화면, 검색·분류·정렬·공유 확인

## 검증 범위
Node 빌드와 JavaScript 구문 검사, 데모 로직의 모의 DOM 테스트 및 정적 HTML 구조 검사를 수행했습니다.
실제 브라우저 렌더링과 Supabase SQL 실행/인증·동시성 통합 테스트는 수행하지 못했습니다. 위 점검표로 프로젝트 연결 후 확인하세요.
실제 GitHub 저장소 생성·Vercel 배포·Supabase 프로젝트 생성은 수행되지 않았습니다.

공식 문서:
- https://supabase.com/docs/guides/auth/auth-anonymous
- https://supabase.com/docs/guides/api/api-keys
