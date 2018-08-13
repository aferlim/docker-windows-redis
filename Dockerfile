# The MSI installs a service which is hard to override, so let's use a zip file.

FROM microsoft/windowsservercore

ENV chocolateyUseWindowsCompression false
RUN @powershell -NoProfile -ExecutionPolicy unrestricted -Command "(iex ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))) >$null 2>&1" && SET PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# PATH isn't actually set in the Docker image, so we have to set it from within the container
RUN $newPath = ('C:\ProgramData\chocolatey\lib\redis-64;{0}' -f $env:PATH); \
	Write-Host ('Updating PATH: {0}' -f $newPath); \
# Nano Server does not have "[Environment]::SetEnvironmentVariable()"
	setx /M PATH $newPath;
# doing this first to share cache across versions more aggressively

RUN choco install redis-64 -y

# disable Redis protected mode [1] as it is unnecessary in context of Docker
# (ports are not automatically exposed when running inside Docker, but rather explicitly by specifying -p / -P)
# [1]: https://github.com/antirez/redis/commit/edd4d555df57dc84265fdfb4ef59a4678832f6da
RUN (Get-Content C:\ProgramData\chocolatey\lib\redis-64\redis.windows.conf) \
	-Replace '^(bind)\s+.*$', '$1 0.0.0.0' \
	-Replace '^(protected-mode)\s+.*$', '$1 no' \
	| Set-Content C:\ProgramData\chocolatey\lib\redis-64\redis.docker.conf

VOLUME C:\\data
WORKDIR C:\\data

EXPOSE 6379
CMD ["redis-server.exe", "C:\\ProgramData\\chocolatey\\lib\\redis-64\\redis.docker.conf"]