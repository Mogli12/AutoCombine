setlocal
set modname=zzzAutoCombine
del %modname%.zip
cd %modname%
for %%I in (..\src\*.lua) do call :loopbody "%%~fI"
"C:\Program Files\WinRAR\winrar" A -r ..\%modname%.zip *.*
cd ..
pause
goto :EOF

:loopbody
	echo %~n1
	del %~n1.luc	
	call c:\work\luapower-all-master\luajit -bg ..\src\%~n1.lua %~n1.luc	
	goto :EOF

