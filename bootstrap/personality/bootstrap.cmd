rem Add local admin
net user /add {{ node_username }} {{ node_password }}
net localgroup administrators {{ node_username }} /add

rem Run PowerShell
ren C:\cloud-automation\run.txt run.ps1
ren C:\cloud-automation\setup-shim.txt setup-shim.ps1
powershell -ExecutionPolicy RemoteSigned -File c:\cloud-automation\run.ps1
