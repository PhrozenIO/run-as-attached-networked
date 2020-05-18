(*******************************************************************************

  Jean-Pierre LESUEUR (@DarkCoderSc)
  https://www.phrozen.io/
  jplesueur@phrozen.io

  License : MIT

*******************************************************************************)

unit UntGlobalsDefs;

interface

uses Messages;

const
  LSTDOUT_MUTEX_NAME = 'DCSC_RAS_STDOUT';
  LSTDIN_MUTEX_NAME  = 'DCSC_RAS_STDIN';

  PACKET_SIZE        = 4096; // 4KiB

  EVENT_CONNECTED    = 'OnConnected';

  WM_COMMAND         = (WM_USER + 1403);

implementation

end.
