@echo off
rem Compile l installeur Windows avec le compilateur C# livre avec Windows.
set F=%SystemRoot%\Microsoft.NET\Framework644.0.30319
"%F%\csc.exe" -nologo -target:winexe -codepage:65001 -optimize "-out:Installer Tour de controle.exe" -win32icon:icon.ico -r:System.Net.Http.dll -r:System.Web.Extensions.dll -r:System.Windows.Forms.dll -r:System.Drawing.dll Installeur.cs
