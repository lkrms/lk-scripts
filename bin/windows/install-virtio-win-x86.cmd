@echo off

echo Running: "msiexec.exe /i D:\guest-agent\qemu-ga-i386.msi"
msiexec.exe /i D:\guest-agent\qemu-ga-i386.msi
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\i386\w7\*.inf"
pnputil.exe -a D:\i386\w7\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\Balloon\w7\x86\*.inf"
pnputil.exe -a D:\Balloon\w7\x86\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\NetKVM\w7\x86\*.inf"
pnputil.exe -a D:\NetKVM\w7\x86\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\pvpanic\w7\x86\*.inf"
pnputil.exe -a D:\pvpanic\w7\x86\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\qemupciserial\w7\x86\*.inf"
pnputil.exe -a D:\qemupciserial\w7\x86\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\qxl\w7\x86\*.inf"
pnputil.exe -a D:\qxl\w7\x86\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\smbus\2k8\x86\*.inf"
pnputil.exe -a D:\smbus\2k8\x86\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\vioinput\w7\x86\*.inf"
pnputil.exe -a D:\vioinput\w7\x86\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\viorng\w7\x86\*.inf"
pnputil.exe -a D:\viorng\w7\x86\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\vioscsi\w7\x86\*.inf"
pnputil.exe -a D:\vioscsi\w7\x86\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\vioserial\w7\x86\*.inf"
pnputil.exe -a D:\vioserial\w7\x86\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\viostor\w7\x86\*.inf"
pnputil.exe -a D:\viostor\w7\x86\*.inf
echo Done. Exit code: %ERRORLEVEL%

