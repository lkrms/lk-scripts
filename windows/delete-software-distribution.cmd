@echo off

if not exist %SystemRoot%\SoftwareDistribution goto :empty

net stop wuauserv || goto :error

echo Deleting folder: %SystemRoot%\SoftwareDistribution
rmdir /S /Q %SystemRoot%\SoftwareDistribution || goto :error

net start wuauserv || goto :error

goto :EOF

:error
echo Failed with error #%errorlevel%
exit /b %errorlevel%

:empty
echo %SystemRoot%\SoftwareDistribution doesn't exist
exit /b 1

