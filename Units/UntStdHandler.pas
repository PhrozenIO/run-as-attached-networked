(*******************************************************************************

  Jean-Pierre LESUEUR (@DarkCoderSc)
  https://www.phrozen.io/
  jplesueur@phrozen.io

  License : MIT

*******************************************************************************)

unit UntStdHandler;

interface

uses Windows, Classes, Winsock2;

type
  TStdHandler = class(TThread)
  private
    FPort   : Word;
    FSocket : TSocket;

    {@M}
    procedure Close(ASocket : TSocket);
    function SendBuffer(ASocket : TSocket; ABuffer : Pointer; ABufferSize : Int64) : Boolean;
  protected
    {@M}
    procedure Execute(); override;
  public
    {@C}
    constructor Create(APort : Word); overload;
  end;

implementation

uses UntGlobalsDefs, UntFunctions;

{-------------------------------------------------------------------------------
  Send data by chunk of N Bytes to target server
-------------------------------------------------------------------------------}
function TStdHandler.SendBuffer(ASocket : TSocket; ABuffer : Pointer; ABufferSize : Int64) : Boolean;
var ABytesWritten  : Integer;
    ARet           : Integer;
    APacketSize    : Integer;
begin
  result := False;
  ///

  if (ABufferSize <= 0) then
    Exit();

  if (ASocket = INVALID_SOCKET) then
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

      ARet := send(ASocket, PByte(NativeUInt(ABuffer) + ABytesWritten)^, APacketSize, 0);
      if (ARet <= 0) then
        Break;

      Inc(ABytesWritten, ARet);
    until (ABytesWritten >= ABufferSize);
  end else
    ARet := send(ASocket, PByte(ABuffer)^, ABufferSize, 0);

  ///
  result := (ARet > 0);
end;

{-------------------------------------------------------------------------------
  Gracefully Close Socket
-------------------------------------------------------------------------------}
procedure TStdHandler.Close(ASocket : TSocket);
begin
  if (ASocket = INVALID_SOCKET) then
    Exit();
  ///

  Shutdown(SD_BOTH, ASocket);

  CloseSocket(ASocket);
end;

{-------------------------------------------------------------------------------
  ___constructor
-------------------------------------------------------------------------------}
constructor TStdHandler.Create(APort : Word);
begin
  inherited Create(True);
  ///

  FPort := APort;

  self.FreeOnTerminate := True;
  self.Priority        := tpHighest;

  FSocket := INVALID_SOCKET;

  ///
  self.Resume();
end;

{-------------------------------------------------------------------------------
  ___process
-------------------------------------------------------------------------------}
procedure TStdHandler.Execute();
var ASockAddrIn     : TSockAddrIn;
    ARet            : Integer;
    AClient         : TSocket;
    b               : LongBool;
    dw              : DWORD;
    ABytesAvailable : Cardinal;
    pRecvBuffer     : Pointer;
    ATotalRecvdSize : Cardinal;
    AOnConnectEvent : THandle;
    AMessage        : tagMsg;
    AConsoleOutput  : THandle;
    ABytesWritten   : Cardinal;
begin
  try
    {
      Create Socket
    }
    FSocket := Socket(AF_INET, SOCK_STREAM, 0);
    if (FSocket = INVALID_SOCKET) then
      Exit();
    ///
    try
      {
        Bind and Configure Socket
      }
      ASockAddrIn.sin_port        := htons(FPort);
      ASockAddrIn.sin_family      := AF_INET;
      ASockAddrIn.sin_addr.S_addr := 16777343; // 127.0.0.1

      ARet := Bind(FSocket, TSockAddr(ASockAddrIn), SizeOf(TSockAddrIn));
      if (ARet = SOCKET_ERROR) then
        Exit();

      b := True;
      if (setsockopt(FSocket, IPPROTO_TCP, TCP_NODELAY, @b, SizeOf(LongBool)) = SOCKET_ERROR) then
        Exit();

      dw := PACKET_SIZE;
      if (setsockopt(FSocket, SOL_SOCKET, SO_RCVBUF, @dw, SizeOf(DWORD)) = SOCKET_ERROR) then
        Exit();

      {
        Listen for ONE client.
      }
      if (listen(FSocket, 1) = SOCKET_ERROR) then
        Exit();

      {
        Waiting for our client to connect
      }
      AClient := accept(FSocket, nil, nil);
      if (AClient <= 0) then
        Exit();
      ///
      try
        {
          Trigger OnConnected Event
        }
        AOnConnectEvent := OpenEvent(EVENT_ALL_ACCESS, false, PWideChar(EVENT_CONNECTED));
        if (AOnConnectEvent = 0) then
          Exit();
        ///

        SetEvent(AOnConnectEvent);

        AConsoleOutput := GetStdHandle(STD_OUTPUT_HANDLE);
        if (AConsoleOutput = 0) or (AConsoleOutput = INVALID_HANDLE_VALUE) then
          Exit();
        ///

        while NOT Terminated do begin
          if NOT IsMutexAssigned(LSTDOUT_MUTEX_NAME) then
            break;
          ///

          {
            Receive Commands from main thread and write to stdin.
          }
          if PeekMessage(AMessage, 0, 0, 0, PM_REMOVE) then begin
            case AMessage.message of
              {
                Write command to attached console.
              }
              WM_COMMAND : begin
                if NOT SendBuffer(AClient, Pointer(AMessage.wParam), AMessage.lParam) then
                  Exit();
              end;
            end;
          end;

          pRecvBuffer := nil;
          ATotalRecvdSize := 0;

          {
            Read Incomming Data
          }
          try
            while NOT Terminated do begin
              if (ioctlsocket(AClient, FIONREAD, ABytesAvailable) = SOCKET_ERROR) then
                Exit();

              if (ABytesAvailable = 0) then
                break;
              ///

              Inc(ATotalRecvdSize, ABytesAvailable);

              ReallocMem(pRecvBuffer, ATotalRecvdSize);

              if (Recv(
                        AClient,
                        PByte(NativeUInt(pRecvBuffer) + (ATotalRecvdSize - ABytesAvailable))^,
                        ABytesAvailable,
                        0
                  ) <= 0) then
                    Exit();
            end;

            {
              If we received some data, we display to our console
            }
            if (ATotalRecvdSize > 0) then begin
              WriteFile(AConsoleOutput, PByte(pRecvBuffer)^, ATotalRecvdSize, ABytesWritten, nil);
            end;
          finally
            if (ATotalRecvdSize > 0) then
              FreeMem(pRecvBuffer, ATotalRecvdSize);
          end;
        end;
      finally
        self.Close(AClient);
      end;
    finally
      self.Close(FSocket);
    end;
  finally
    ExitThread(0);
  end;
end;

end.
