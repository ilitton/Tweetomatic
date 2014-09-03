@ECHO OFF

:start
choice /m "Do you want to continue to download tweets" /t:10 /d:Y
if ERRORLEVEL 2 goto :NO
if ERRORLEVEL 1 goto :YES
goto :start

:YES
EXIT

:NO
copy nul C:\Users\Administrator\Documents\Macro Test\exittest.txt