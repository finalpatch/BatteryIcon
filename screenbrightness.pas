unit screenbrightness;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Variants, ActiveX, ComObj, LazLogger;

type
  BrightnessRange = 0..100;

  TScreenBrightness = class
  private
    objWMIService : Variant;
  public
    constructor Create; overload;
    function GetBrightness: BrightnessRange;
    procedure SetBrightness(brightness: BrightnessRange);
  end;

implementation

const
  wbemFlagForwardOnly = $00000020;

constructor TScreenBrightness.Create;
var
  FSWbemLocator : Variant;
begin
  inherited;
  FSWbemLocator   := CreateOleObject('WbemScripting.SWbemLocator');
  objWMIService   := FSWbemLocator.ConnectServer('localhost', 'root\wmi', '', '');
end;

function TScreenBrightness.GetBrightness: BrightnessRange;
var
  colWMI        : Variant;
  oEnumWMI      : IEnumvariant;
  objWMI        : OLEVariant;
  nrValue       : LongWord;
  nr            : LongWord absolute nrValue;
  prop          : Variant;
begin
  colWMI:=objWMIService.InstancesOf('WmiMonitorBrightness');
  oEnumWMI := IUnknown(colWMI._NewEnum) as IEnumVariant;
  DebugLn(['get brightness']);
  while oEnumWMI.Next(1, objWMI, nr) = 0 do
    begin
      if (objWMI.Active) then begin
        //exit(objWMI.CurrentBrightness);
        DebugLn([VarToStr(objWMI.InstanceName), ': ', Integer(objWMI.CurrentBrightness)]);
      end
    end;
  result:=90;
end;

procedure TScreenBrightness.SetBrightness(brightness: BrightnessRange);
var
  objMethods: Variant;
  oEnumWMI      : IEnumvariant;
  objWMI        : OLEVariant;
  nrValue       : LongWord;
  nr            : LongWord absolute nrValue;
begin
  objMethods:=objWMIService.InstancesOf('WmiMonitorBrightnessMethods');
  oEnumWMI := IUnknown(objMethods._NewEnum) as IEnumVariant;
  while oEnumWMI.Next(1, objWMI, nr) = 0 do
    begin
      if (objWMI.Active) then begin
        objWMI.WmiSetBrightness(Integer(1), Byte(brightness));
      end;
    end;
end;

end.

