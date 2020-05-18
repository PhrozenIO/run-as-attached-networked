(*******************************************************************************

  Jean-Pierre LESUEUR (@DarkCoderSc)
  https://www.phrozen.io/
  jplesueur@phrozen.io

  License : MIT

*******************************************************************************)

unit UntTypesDefs;

interface

type
  TShellKind = (
                  skDefault,
                  skCmd,
                  skPowerShell
  );

  TEntryKind = (
                  ekUnknown,
                  ekStdin,
                  ekStdout
  );

implementation

end.
