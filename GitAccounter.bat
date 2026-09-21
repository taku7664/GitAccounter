@echo off
setlocal enabledelayedexpansion
title GitHub 계정 전환기
cd /d "%~dp0"

for /f %%E in ('echo prompt $E ^| cmd') do set "ESC=%%E"
set "LNKNAME=GitAccounter.lnk"
set "ICOPATH=%~dp0GitAccounter.ico"

where gh >nul 2>&1
if errorlevel 1 (
    echo.
    echo    GitHub CLI^(gh^)를 찾을 수 없습니다.
    echo    https://cli.github.com 에서 설치한 뒤 다시 실행해 주십시오.
    echo.
    pause
    exit /b 1
)

:main
cls
set "count=0"
set "pending="
set "pendhost="

for /f "usebackq delims=" %%L in (`gh auth status 2^>^&1`) do (
    set "line=%%L"
    if not "!line!"=="!line:Logged in to=!" (
        set "rest=!line:*Logged in to =!"
        for /f "tokens=1,3" %%H in ("!rest!") do (
            set "pendhost=%%H"
            set "pending=%%I"
        )
    ) else (
        if not "!line!"=="!line:Active account:=!" (
            if defined pending (
                set /a count+=1
                set "ACC_!count!=!pending!"
                set "HOST_!count!=!pendhost!"
                if "!line!"=="!line:true=!" (set "ACT_!count!=") else (set "ACT_!count!=1")
                set "pending="
            )
        )
    )
)

if !count! gtr 1 (
    for /l %%P in (1,1,!count!) do (
        for /l %%Q in (1,1,!count!) do (
            set /a "nx=%%Q+1"
            if !nx! leq !count! call :swapcheck %%Q !nx!
        )
    )
)

echo ============================================================
echo    GitHub 계정 전환기
echo ============================================================
echo.

if !count!==0 (
    echo    등록된 계정이 없습니다.
    echo.
    echo    login 을 입력하여 계정을 추가하십시오.
) else (
    for /l %%I in (1,1,!count!) do (
        call set "cur=%%ACC_%%I%%"
        call set "curh=%%HOST_%%I%%"
        set "tag="
        if defined ACT_%%I set "tag=   <-- 현재 사용 중"
        echo    [%%I] !cur!  ^(!curh!^)!tag!
    )
)

echo.
echo ------------------------------------------------------------
echo    번호           해당 계정으로 전환      예^) 1
echo    번호 status    해당 계정의 인증 정보   예^) 1 status
echo    번호 logout    해당 계정 인증 해제     예^) 1 logout
echo    login          새 계정 로그인
echo    link [경로]    바로 가기 생성          예^) link D:\도구
echo    r              목록 새로 고침
echo    q              종료
echo ------------------------------------------------------------
echo.

set "cmd="
set /p "cmd=입력: "
if not defined cmd goto main

set "a1="
set "arg="
for /f "tokens=1,*" %%A in ("!cmd!") do (
    set "a1=%%A"
    set "arg=%%B"
)

if /i "!a1!"=="link" goto do_link

set "a2="
set "a3="
for /f "tokens=1,2,*" %%A in ("!cmd!") do (
    set "a2=%%B"
    set "a3=%%C"
)

if defined a3 goto err_unknown
if /i "!a1!"=="q" goto bye
if /i "!a1!"=="quit" goto bye
if /i "!a1!"=="exit" goto bye
if /i "!a1!"=="r" goto main
if /i "!a1!"=="login" goto do_login
if /i "!a1!"=="logout" goto err_logout

echo "!a1!"|findstr /r /c:"^\"[0-9][0-9]*\"$" >nul
if errorlevel 1 goto err_unknown
if !a1! lss 1 goto err_range
if !a1! gtr !count! goto err_range

call set "sel=%%ACC_!a1!%%"
call set "selh=%%HOST_!a1!%%"

if not defined a2 goto do_switch
if /i "!a2!"=="status" goto do_status
if /i "!a2!"=="logout" goto do_logout
goto err_sub

:do_switch
cls
echo ============================================================
echo    계정 전환
echo ============================================================
echo.
echo    [!sel!] ^(!selh!^) 계정으로 전환합니다.
echo.
set "GHLOG=%TEMP%\gh-account-switcher.log"
gh auth switch --hostname !selh! --user !sel! >"!GHLOG!" 2>&1
if errorlevel 1 (
    echo    [실패] 전환하지 못했습니다. 아래 내용을 확인해 주십시오.
    echo.
    type "!GHLOG!"
) else (
    echo    현재 사용 중인 계정: !sel!
)
del "!GHLOG!" >nul 2>&1
echo.
pause
goto main

:do_status
cls
echo ============================================================
echo    !sel! 인증 정보
echo ============================================================
echo.
set "needle=account !sel!"
set "show="
for /f "usebackq delims=" %%L in (`gh auth status --hostname !selh! 2^>^&1`) do (
    set "line=%%L"
    if not "!line!"=="!line:Logged in to=!" (
        if "!line!"=="!line:%needle%=!" (set "show=") else (set "show=1")
        if defined show echo    Logged in to !line:*Logged in to =!
    ) else (
        if defined show echo !line!
    )
)
echo.
pause
goto main

:do_logout
cls
echo ============================================================
echo    인증 해제
echo ============================================================
echo.
echo    [!sel!] ^(!selh!^) 계정의 인증을 해제합니다.
echo    해제한 뒤에는 다시 로그인해야 사용할 수 있습니다.
echo.
set "yn="
set /p "yn=정말 진행하시겠습니까? ^(y/N^): "
if /i not "!yn!"=="y" (
    echo.
    echo    취소했습니다.
    echo.
    pause
    goto main
)
echo.
set "GHLOG=%TEMP%\gh-account-switcher.log"
gh auth logout --hostname !selh! --user !sel! >"!GHLOG!" 2>&1
if errorlevel 1 (
    echo    [실패] 인증을 해제하지 못했습니다. 아래 내용을 확인해 주십시오.
    echo.
    type "!GHLOG!"
) else (
    echo    [!sel!] 계정의 인증을 해제했습니다.
)
del "!GHLOG!" >nul 2>&1
echo.
pause
goto main

:do_login
cls
echo ============================================================
echo    새 계정 로그인
echo ============================================================
echo.
echo    브라우저가 열리면 추가하실 계정으로 로그인하신 뒤,
echo    화면에 표시되는 여덟 자리 코드를 입력하십시오.
echo    기존 계정의 인증은 그대로 유지됩니다.
echo.
gh auth login --hostname github.com --git-protocol https --web
echo.
echo ------------------------------------------------------------
echo    로그인 절차가 끝났습니다. 목록으로 돌아갑니다.
echo ------------------------------------------------------------
echo.
pause
goto main

:do_link
cls
echo ============================================================
echo    바로 가기 생성
echo ============================================================
echo.
set "dest=!arg!"
if defined dest set dest=!dest:"=!

:link_trim
if not defined dest goto link_default
if "!dest:~-1!"==" " (
    set "dest=!dest:~0,-1!"
    goto link_trim
)
goto link_expand

:link_default
set "dest=%~dp0"
goto link_check

:link_expand
call set "dest=%dest%"
if not defined dest goto link_default

:link_check
echo "!dest!"|findstr /r /c:"[<>|*?]" >nul
if not errorlevel 1 goto link_badchar

if /i "!dest:~-4!"==".lnk" goto link_asfile
goto link_asdir

:link_asfile
for %%F in ("!dest!") do set "target=%%~fF" & set "pdir=%%~dpF"
if not exist "!pdir!" goto link_nodir
goto link_create

:link_asdir
if "!dest:~-1!"=="\" set "dest=!dest:~0,-1!"
if exist "!dest!\" goto link_dirok
if exist "!dest!" goto link_isfile
goto link_nodir

:link_dirok
for %%F in ("!dest!\!LNKNAME!") do set "target=%%~fF"
goto link_create

:link_create
if exist "!target!" goto link_exists
set "GHLOG=%TEMP%\gh-account-switcher.log"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$w = New-Object -ComObject WScript.Shell; $s = $w.CreateShortcut('!target!'); $s.TargetPath = '%~f0'; $s.WorkingDirectory = '%~dp0'; $s.IconLocation = '!ICOPATH!,0'; $s.Description = 'GitHub CLI 계정 목록 확인 및 전환'; $s.WindowStyle = 1; $s.Save()" >"!GHLOG!" 2>&1
if not exist "!target!" goto link_fail
del "!GHLOG!" >nul 2>&1

for %%F in ("!target!") do set "lnkdir=%%~dpF"
if "!lnkdir:~-1!"=="\" set "lnkdir=!lnkdir:~0,-1!"
set "URL=file:///!lnkdir:\=/!"
set "URL=!URL: =%%20!"

echo    바로 가기를 만들었습니다.
echo.
if defined WT_SESSION (
    echo    !ESC!]8;;!URL!!ESC!\!target!!ESC!]8;;!ESC!\
    echo.
    echo    ^(Ctrl 키를 누른 채 경로를 누르면 폴더가 열립니다.^)
) else (
    echo    !target!
)
echo.
pause
goto main

:link_badchar
echo    [오류] 경로에 사용할 수 없는 문자가 들어 있습니다: !dest!
echo           ^< ^> ^| * ? 는 경로에 쓸 수 없습니다.
echo.
pause
goto main

:link_nodir
echo    [오류] 폴더를 찾을 수 없습니다: !dest!
echo           존재하는 폴더의 경로를 입력해 주십시오.
echo.
pause
goto main

:link_isfile
echo    [오류] 폴더가 아니라 파일입니다: !dest!
echo           폴더 경로나 .lnk 로 끝나는 경로를 입력해 주십시오.
echo.
pause
goto main

:link_exists
echo    [건너뜀] 같은 이름의 바로 가기가 이미 있습니다.
echo.
echo    !target!
echo.
echo    덮어쓰지 않았습니다. 다시 만들려면 기존 파일을 먼저 지워 주십시오.
echo.
pause
goto main

:link_fail
echo    [실패] 바로 가기를 만들지 못했습니다. 아래 내용을 확인해 주십시오.
echo.
type "!GHLOG!"
del "!GHLOG!" >nul 2>&1
echo.
pause
goto main

:err_unknown
echo.
echo    [오류] 인식할 수 없는 입력입니다: !cmd!
echo           번호, 번호 status, 번호 logout, login, link, r, q 만 사용할 수 있습니다.
echo.
pause
goto main

:err_logout
echo.
echo    [오류] logout 앞에는 계정 번호가 필요합니다.  예^) 1 logout
echo.
pause
goto main

:err_range
echo.
echo    [오류] !a1! 번 계정은 목록에 없습니다. 1 부터 !count! 사이의 번호를 입력해 주십시오.
echo.
pause
goto main

:err_sub
echo.
echo    [오류] !a2! 는 사용할 수 없는 명령입니다. status 또는 logout 만 사용할 수 있습니다.
echo.
pause
goto main

:bye
endlocal
exit /b 0

:swapcheck
call set "x=%%ACC_%1%%"
call set "y=%%ACC_%2%%"
if /i "!x!" leq "!y!" exit /b
call set "xh=%%HOST_%1%%"
call set "yh=%%HOST_%2%%"
call set "xa=%%ACT_%1%%"
call set "ya=%%ACT_%2%%"
set "ACC_%1=!y!"
set "ACC_%2=!x!"
set "HOST_%1=!yh!"
set "HOST_%2=!xh!"
set "ACT_%1=!ya!"
set "ACT_%2=!xa!"
exit /b
