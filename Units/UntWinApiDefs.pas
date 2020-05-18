(*******************************************************************************

  Jean-Pierre LESUEUR (@DarkCoderSc)
  https://www.phrozen.io/
  jplesueur@phrozen.io

  License : MIT

*******************************************************************************)

unit UntWinApiDefs;

interface

uses Windows;

var hShell32  : THandle;
    hAdvapi32 : THandle;

    {
      API's Definitions
    }
    CommandLineToArgvW      : function(lpCmdLine : LPCWSTR; var pNumArgs : Integer) : LPWSTR; stdcall;
    CreateProcessWithLogonW : function(lpUsername, lpDomain, lpPassword: LPCWSTR; dwLogonFlags: DWORD; lpApplicationName: LPCWSTR; lpCommandLine: LPWSTR; dwCreationFlags: DWORD; lpEnvironment: LPVOID; lpCurrentDirectory: LPCWSTR; const lpStartupInfo: STARTUPINFOW; var lpProcessInformation: PROCESS_INFORMATION): BOOL; stdcall;

const LOGON_WITH_PROFILE      = $00000001;
      LOGON_LOGON_INTERACTIVE = $00000002;
      LOGON_PROVIDER_DEFAULT  = $00000000;

implementation

initialization
  {
    Shell32.dll API's Loading
  }
  CommandLineToArgvW := nil;

  hShell32 := LoadLibrary('SHELL32.DLL');
  if (hShell32 <> 0) then begin
    @CommandLineToArgvW := GetProcAddress(hShell32, 'CommandLineToArgvW');
  end;

  {
    hAdvapi32.DLL API's Loading
  }
  CreateProcessWithLogonW := nil;

  hAdvapi32 := LoadLibrary('ADVAPI32.DLL');
  if (hAdvapi32 <> 0) then begin
    @CreateProcessWithLogonW := GetProcAddress(hAdvapi32, 'CreateProcessWithLogonW');
  end;


finalization
  if (hShell32 <> 0) then
    FreeLibrary(hShell32);

  if (hAdvapi32 <> 0) then
    FreeLibrary(hAdvapi32);

end.
