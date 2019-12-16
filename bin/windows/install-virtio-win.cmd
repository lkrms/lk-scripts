@echo off

echo Running: "msiexec.exe /i D:\guest-agent\qemu-ga-x86_64.msi"
msiexec.exe /i D:\guest-agent\qemu-ga-x86_64.msi
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\amd64\w7\*.inf"
pnputil.exe -a D:\amd64\w7\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\Balloon\w7\amd64\*.inf"
pnputil.exe -a D:\Balloon\w7\amd64\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\NetKVM\w7\amd64\*.inf"
pnputil.exe -a D:\NetKVM\w7\amd64\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\pvpanic\w7\amd64\*.inf"
pnputil.exe -a D:\pvpanic\w7\amd64\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\qemupciserial\w7\amd64\*.inf"
pnputil.exe -a D:\qemupciserial\w7\amd64\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\qxl\w7\amd64\*.inf"
pnputil.exe -a D:\qxl\w7\amd64\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\smbus\2k8\amd64\*.inf"
pnputil.exe -a D:\smbus\2k8\amd64\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\vioinput\w7\amd64\*.inf"
pnputil.exe -a D:\vioinput\w7\amd64\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\viorng\w7\amd64\*.inf"
pnputil.exe -a D:\viorng\w7\amd64\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\vioscsi\w7\amd64\*.inf"
pnputil.exe -a D:\vioscsi\w7\amd64\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\vioserial\w7\amd64\*.inf"
pnputil.exe -a D:\vioserial\w7\amd64\*.inf
echo Done. Exit code: %ERRORLEVEL%

echo Running: "pnputil.exe -a D:\viostor\w7\amd64\*.inf"
pnputil.exe -a D:\viostor\w7\amd64\*.inf
echo Done. Exit code: %ERRORLEVEL%

