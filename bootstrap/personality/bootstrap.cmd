rem Add local admin
net user /add {{ node_username }} {{ node_password }}
net localgroup administrators {{ node_username }} /add

rem Run PowerShell
ren c:\cloud-automation\run.txt run.ps1
powershell -ExecutionPolicy RemoteSigned -File c:\cloud-automation\run.ps1
