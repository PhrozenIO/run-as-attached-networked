(*******************************************************************************

  Jean-Pierre LESUEUR (@DarkCoderSc)
  https://www.phrozen.io/
  jplesueur@phrozen.io

  License : MIT

*******************************************************************************)

unit UntFunctions;

interface

uses Windows, SysUtils, UntTypesDefs, shlObj;

type
  TDebugLevel = (
                  dlInfo,
                  dlSuccess,
                  dlWarning,
                  dlError
  );

function GetSystemDirectory() : string;
function GetCurrentDirectory() : string;
procedure Debug(AMessage : String; ADebugLevel : TDebugLevel = dlInfo);
procedure DumpLastError(APrefix : String = '');
function CreateProcessAsUser(AProgram : String; ACommandLine : String; AUserName, APassword : String; ADomain : String = '') : Boolean;
function GetCurrentLoggedUser() : string;
function GetCommandLineOption(AOption : String; var AValue : String; ACommandLine : String = '') : Boolean; overload;
function GetCommandLineOption(AOption : String; var AValue : String; var AOptionExists : Boolean; ACommandLine : String = '') : Boolean; overload;
function GetCommandLineOption(AOption : String; var AValue : Integer; ACommandLine : String = '') : Boolean; overload;
function CommandLineOptionExists(AOption : String; ACommandLine : String = '') : Boolean;
procedure WriteColoredWord(AString : String);
function UpdateConsoleAttributes(AConsoleAttributes : Word) : Word;
function IsMutexAssigned(AMutexName : String) : Boolean;
function GetCommonAppData() : string;
function RandomName(ALength : Integer) : String;
function CreateGlobalMutex(AMutexName : String) : THandle;
function OpenGlobalMutex(AMutexName : String) : THandle;

implementation

uses UntWinApiDefs, math, UntGlobalsDefs;

{-------------------------------------------------------------------------------
  Generate a random string
-------------------------------------------------------------------------------}
function RandomName(ALength : Integer) : String;
const ATokenChars = 'abcdefghijklmnopqrstuvwxyz';
var   i : integer;
begin
  result := '';

  randomize();
  ///

  for i := 1 to ALength do begin
      result := result + ATokenChars[random(length(ATokenChars))+1];
  end;
end;

{-------------------------------------------------------------------------------
  Get Common APPDATA Folder (Writable/Readable by all users)
-------------------------------------------------------------------------------}
function GetCommonAppData() : string;
var APath: array [0..MAX_PATH-1] of WideChar;
begin
  result := '';
  ///

  if Succeeded(SHGetFolderPath(0, CSIDL_COMMON_APPDATA, 0, SHGFP_TYPE_CURRENT, @APath[0])) then
    result := IncludeTrailingPathDelimiter(APath);
end;

{-------------------------------------------------------------------------------
  Open a Global Mutex
-------------------------------------------------------------------------------}
function OpenGlobalMutex(AMutexName : String) : THandle;
begin
  result := 0;
  ///

  if Copy(AMutexName, 1, 7) <> 'Global\' then
    AMutexName := 'Global\' + AMutexName;
  ///

  result := OpenMutexW(MUTEX_ALL_ACCESS, False, PWideChar(AMutexName));
end;

{-------------------------------------------------------------------------------
  Create a Mutex accessible accross different users
-------------------------------------------------------------------------------}
function CreateGlobalMutex(AMutexName : String) : THandle;
var ASecurityDescriptor : TSecurityDescriptor;
    ASecurityAttributes : TSecurityAttributes;
begin
  result := 0;
  ///

  if Copy(AMutexName, 1, 7) <> 'Global\' then
    AMutexName := 'Global\' + AMutexName;
  ///

  InitializeSecurityDescriptor(@ASecurityDescriptor, SECURITY_DESCRIPTOR_REVISION);

  SetSecurityDescriptorDacl(@ASecurityDescriptor, True, nil, False);

  ZeroMemory(@ASecurityAttributes, SizeOf(TSecurityAttributes));

  ASecurityAttributes.nLength := SizeOf(TSecurityAttributes);
  ASecurityAttributes.bInheritHandle := False;
  ASecurityAttributes.lpSecurityDescriptor := @ASecurityDescriptor;

  result := CreateMutexW(@ASecurityAttributes, True, PWideChar(AMutexName));
end;

{-------------------------------------------------------------------------------
  Check whether or not a Mutex is already owned
-------------------------------------------------------------------------------}
function IsMutexAssigned(AMutexName : String) : Boolean;
var AMutex : THandle;
    ARet   : Cardinal;
begin
  result := False;
  ///

  SetLastError(0);

  AMutex := OpenGlobalMutex(AMutexName);

  if (AMutex = 0) then
    Exit();
  ///

  ARet := WaitForSingleObject(AMutex, 1);
  case ARet of
    WAIT_ABANDONED, WAIT_FAILED : begin

    end;

    else begin
      result := True;

      CloseHandle(AMutex);
    end;
  end;
end;

{-------------------------------------------------------------------------------
  Update Console Attributes (Changing color for example)

  Returns previous attributes.
-------------------------------------------------------------------------------}
function UpdateConsoleAttributes(AConsoleAttributes : Word) : Word;
var AConsoleHandle        : THandle;
    AConsoleScreenBufInfo : TConsoleScreenBufferInfo;
    b                     : Boolean;
begin
  result := 0;
  ///

  AConsoleHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if (AConsoleHandle = INVALID_HANDLE_VALUE) then
    Exit();
  ///

  b := GetConsoleScreenBufferInfo(AConsoleHandle, AConsoleScreenBufInfo);

  if b then begin
    SetConsoleTextAttribute(AConsoleHandle, AConsoleAttributes);

    ///
    result := AConsoleScreenBufInfo.wAttributes;
  end;
end;

{-------------------------------------------------------------------------------
  Write colored word(s) on current console
-------------------------------------------------------------------------------}
procedure WriteColoredWord(AString : String);
var AOldAttributes : Word;
begin
  AOldAttributes := UpdateConsoleAttributes(FOREGROUND_INTENSITY or FOREGROUND_GREEN);

  Write(AString);

  UpdateConsoleAttributes(AOldAttributes);
end;

{-------------------------------------------------------------------------------
  Command Line Parser

  AOption       : Search for specific option Ex: -c.
  AValue        : Next argument string if option is found.
  AOptionExists : Set to true if option is found in command line string.
  ACommandLine  : Command Line String to parse, by default, actual program command line.
-------------------------------------------------------------------------------}
function GetCommandLineOption(AOption : String; var AValue : String; var AOptionExists : Boolean; ACommandLine : String = '') : Boolean;
var ACount    : Integer;
    pElements : Pointer;
    I         : Integer;
    ACurArg   : String;
type
  TArgv = array[0..0] of PWideChar;
begin
  result := False;
  ///

  AOptionExists := False;

  if NOT Assigned(CommandLineToArgvW) then
    Exit();

  if (ACommandLine = '') then begin
    ACommandLine := GetCommandLineW();
  end;

  pElements := CommandLineToArgvW(PWideChar(ACommandLine), ACount);

  if NOT Assigned(pElements) then
    Exit();

  AOption := '-' + AOption;

  if (Length(AOption) > 2) then
    AOption := '-' + AOption;

  for I := 0 to ACount -1 do begin
    ACurArg := UnicodeString((TArgv(pElements^)[I]));
    ///

    if (ACurArg <> AOption) then
      continue;

    AOptionExists := True;

    // Retrieve Next Arg
    if I <> (ACount -1) then begin
      AValue := UnicodeString((TArgv(pElements^)[I+1]));

      ///
      result := True;
    end;
  end;
end;

function GetCommandLineOption(AOption : String; var AValue : String; ACommandLine : String = '') : Boolean;
var AExists : Boolean;
begin
  result := GetCommandLineOption(AOption, AValue, AExists, ACommandLine);
end;

function GetCommandLineOption(AOption : String; var AValue : Integer; ACommandLine : String = '') : Boolean;
var AStrValue : String;
begin
  result := False;
  ///

  AStrValue := '';
  if NOT GetCommandLineOption(AOption, AStrValue, ACommandLine) then
    Exit();
  ///

  if NOT TryStrToInt(AStrValue, AValue) then
    Exit();
  ///

  result := True;
end;

{-------------------------------------------------------------------------------
  Check if commandline option is set
-------------------------------------------------------------------------------}
function CommandLineOptionExists(AOption : String; ACommandLine : String = '') : Boolean;
var ADummy : String;
begin
  GetCommandLineOption(AOption, ADummy, result, ACommandLine);
end;

{-------------------------------------------------------------------------------
  Get the current logged username
-------------------------------------------------------------------------------}
function GetCurrentLoggedUser() : string;
var buffer : Array[0..MAX_PATH -1] of char;
    ALen   : cardinal;

begin
  result := '';

  ALen := MAX_PATH;
  if NOT GetUserName(@buffer, ALen) then
    Exit();

  result := StrPas(buffer);
end;

{-------------------------------------------------------------------------------
  Create Process as Another User
-------------------------------------------------------------------------------}
function CreateProcessAsUser(AProgram : String; ACommandLine : String; AUserName, APassword : String; ADomain : String = '') : Boolean;
var AStartupInfo : TStartupInfo;
    AProcessInfo : TProcessInformation;
begin
  if (ADomain = '') then
    ADomain := GetEnvironmentVariable('USERDOMAIN');
  ///

  UniqueString(AProgram);
  UniqueString(ACommandLine);
  UniqueString(AUserName);
  UniqueString(APassword);
  UniqueString(ADomain);
  ///

  ZeroMemory(@AProcessInfo, SizeOf(TProcessInformation));
  ZeroMemory(@AStartupInfo, Sizeof(TStartupInfo));

  AStartupInfo.cb          := SizeOf(TStartupInfo);
  AStartupInfo.wShowWindow := SW_HIDE;
  AStartupInfo.dwFlags     := (STARTF_USESHOWWINDOW);

  result := CreateProcessWithLogonW(
                                     PWideChar(AUserName),
                                     PWideChar(ADomain),
                                     PWideChar(APassword),
                                     0,
                                     PWideChar(AProgram),
                                     PWideChar(ACommandLine),
                                     0,
                                     nil,
                                     nil,
                                     AStartupInfo,
                                     AProcessInfo
  );

  if (NOT result) then
    DumpLastError('CreateProcessWithLogonW')
  else
    Debug(Format('Process spawned as user=[%s], ProcessId=[%d], ProcessHandle=[%d].', [AUserName, AProcessInfo.dwProcessId, AProcessInfo.hProcess]), dlSuccess);
end;

{-------------------------------------------------------------------------------
  Debug Defs
-------------------------------------------------------------------------------}
procedure Debug(AMessage : String; ADebugLevel : TDebugLevel = dlInfo);
var AConsoleHandle        : THandle;
    AConsoleScreenBufInfo : TConsoleScreenBufferInfo;
    b                     : Boolean;
    AStatus               : String;
    AColor                : Integer;
begin
  AConsoleHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if (AConsoleHandle = INVALID_HANDLE_VALUE) then
    Exit();
  ///

  b := GetConsoleScreenBufferInfo(AConsoleHandle, AConsoleScreenBufInfo);

  case ADebugLevel of
    dlSuccess : begin
      AStatus := #32 + 'OK' + #32;
      AColor  := FOREGROUND_GREEN;
    end;

    dlWarning : begin
      AStatus := #32 + '!!' + #32;
      AColor  := (FOREGROUND_RED or FOREGROUND_GREEN);
    end;

    dlError : begin
      AStatus := #32 + 'KO' + #32;
      AColor  := FOREGROUND_RED;
    end;

    else begin
      AStatus := 'INFO';
      AColor  := FOREGROUND_BLUE;
    end;
  end;

  Write('[');
  if b then
    b := SetConsoleTextAttribute(AConsoleHandle, FOREGROUND_INTENSITY or (AColor));
  try
    Write(AStatus);
  finally
    if b then
      SetConsoleTextAttribute(AConsoleHandle, AConsoleScreenBufInfo.wAttributes);
  end;
  Write(']' + #32);

  ///
  WriteLn(AMessage);
end;

procedure DumpLastError(APrefix : String = '');
var ACode         : Integer;
    AFinalMessage : String;
begin
  ACode := GetLastError();

  AFinalMessage := '';

  if (ACode <> 0) then begin
    AFinalMessage := Format('Error_Msg=[%s], Error_Code=[%d]', [SysErrorMessage(ACode), ACode]);

    if (APrefix <> '') then
      AFinalMessage := Format('%s: %s', [APrefix, AFinalMessage]);

    ///
    Debug(AFinalMessage, dlError);
  end;
end;

{-------------------------------------------------------------------------------
   Retrieve \Windows\System32\ Location
-------------------------------------------------------------------------------}
function GetSystemDirectory() : string;
var ALen  : Cardinal;
begin
  SetLength(result, MAX_PATH);

  ALen := Windows.GetSystemDirectory(@result[1], MAX_PATH);

  if (ALen > 0) then begin
    SetLength(result, ALen);

    result := IncludeTrailingPathDelimiter(result);
  end else
    result := '';
end;

{-------------------------------------------------------------------------------
   Retrieve Current Process Directory (eq ExtractFilePath(GetModuleName(0)))
-------------------------------------------------------------------------------}
function GetCurrentDirectory() : string;
var ALen  : Cardinal;
begin
  SetLength(result, MAX_PATH);

  ALen := Windows.GetCurrentDirectory(MAX_PATH, @result[1]);

  if (ALen > 0) then begin
    SetLength(result, ALen);

    result := IncludeTrailingPathDelimiter(result);
  end else
    result := '';
end;

end.
