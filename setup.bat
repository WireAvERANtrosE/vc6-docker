@echo off
REM Set up paths for Visual C++ 6.0, CMake, and Git
set PATH=Z:\opt\vc\BIN;Z:\opt\vc\LIB;Z:\opt\cmake\win32\bin;Z:\opt\cmake\win64\bin;Z:\opt\git\bin;Z:\opt\git\cmd;%PATH%
set INCLUDE=Z:\opt\vc\INCLUDE;Z:\opt\vc\MFC\INCLUDE;Z:\opt\vc\ATL\INCLUDE
set LIB=Z:\opt\vc\LIB;Z:\opt\vc\MFC\LIB

REM Set up MSVC environment variables
set MSDevDir=Z:\opt\vc
set MSVCDir=Z:\opt\vc
set VC98_ROOT=Z:\opt\vc

REM Set up common environment variables
set VCINSTALLDIR=Z:\opt\vc
set VCToolkitInstallDir=Z:\opt\vc

REM Set up Git environment variables
set GIT_INSTALL_ROOT=Z:\opt\git

REM Echo the environment for debugging
echo VC6 environment set up successfully!
echo PATH=%PATH%
echo INCLUDE=%INCLUDE%
echo LIB=%LIB%
