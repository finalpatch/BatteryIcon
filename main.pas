unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Menus, JwaBatClass, BatteryInfo, screenbrightness, IniFiles, LazLogger;

type
  PowerState = (AC, DC);

  { TForm1 }

  TForm1 = class(TForm)
    Label1: TLabel;
    ExitMenuItem: TMenuItem;
    PopupMenu1: TPopupMenu;
    Timer1: TTimer;
    TrayIcon1: TTrayIcon;
    bm: TBitmap;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ExitMenuItemClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
  private
    bi: TBatteryInfo;
    //state: PowerState;
    //brightnessctl: TScreenBrightness;
    //settings : TIniFile;
    //AcBrightness: BrightnessRange;
    //DcBrightness: BrightnessRange;
    procedure PrepareBitmap;
    procedure UpdateTrayIcon;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  PrepareBitmap;
  UpdateTrayIcon;
end;

procedure TForm1.PrepareBitmap;
var
  bmWidth: Integer;
  bmHeight: Integer;
  iconSize: Integer;
begin
  bm.GetSize(bmWidth, bmHeight);
  iconSize := Scale96ToFont(32);
  if (iconSize <> bmWidth) then begin
    bm.SetSize(iconSize, iconSize);
    bm.Canvas.Font.Size:= Scale96ToFont(16);
    DebugLn('resize');
  end;
end;

procedure TForm1.UpdateTrayIcon;
var
  bs: TBatteryStatus;
  newString: string;
  watts: single = 0.0;
  fmt: string;
  //newState: PowerState;
  //saveBrightness: BrightnessRange;
begin
  bs := bi.GetBatteryStatus;

  //if (bs.PowerState and BATTERY_POWER_ON_LINE) = 0 then
  //  newState:=DC
  //else
  //  newState:=AC;
  //
  //if ((newState = DC) and (state = AC)) then begin
  //  // AC => DC
  //  Debugln('AC=>DC');
  //  state:= newState;
  //  saveBrightness := brightnessctl.GetBrightness;
  //  DebugLn(['Current AC brightness ', saveBrightness]);
  //  DebugLn(['Cached AC brightness ', AcBrightness]);
  //  if saveBrightness <> AcBrightness then begin
  //    AcBrightness:=saveBrightness;
  //    settings.WriteInteger('Brightness', 'ac', AcBrightness);
  //    DebugLn(['Update cached AC brightness to ', AcBrightness]);
  //  end;
  //  DebugLn(['Set DC brightness ', DcBrightness]);
  //  brightnessctl.SetBrightness(DcBrightness);
  //  DebugLn('Done');
  //end else if ((newState = AC) and (state = DC)) then begin
  //  // DC => AC
  //  Debugln('DC=>AC');
  //  state:= newState;
  //  saveBrightness := brightnessctl.GetBrightness;
  //  DebugLn(['Current DC brightness ', saveBrightness]);
  //  DebugLn(['Cached DC brightness ', dcBrightness]);
  //  if saveBrightness <> DcBrightness then begin
  //    DcBrightness:=saveBrightness;
  //    settings.WriteInteger('Brightness', 'dc', DcBrightness);
  //    DebugLn(['Update cached DC brightness to ', DcBrightness]);
  //  end;
  //  DebugLn(['Set AC brightness ', AcBrightness]);
  //  brightnessctl.SetBrightness(AcBrightness);
  //  DebugLn('Done');
  //end;

  if (bs.PowerState and BATTERY_CHARGING) <> 0 then begin
    newString := '>>';
  end else if (bs.PowerState and BATTERY_POWER_ON_LINE) <> 0 then begin
    newString := 'AC';
  end else begin
    watts:=bs.Rate/1000.0;
    if watts < 0 then
      watts:=-watts;
    if watts >= 10.0 then
      fmt:='%-.1f'
    else
      fmt:='%-.2f';
    newString := format(fmt,[watts]);
  end;
  if Label1.Caption<>newString then begin
    if (bs.PowerState and BATTERY_POWER_ON_LINE) <> 0 then begin
      bm.Canvas.Brush.Color:=clLime;
      bm.Canvas.Font.Color:=clBlack;
    end else if watts < 7.0 then begin
      bm.Canvas.Brush.Color:=clBlue;
      bm.Canvas.Font.Color:=clWhite;
    end else if watts < 9.0 then begin
      bm.Canvas.Brush.Color:=clTeal;
      bm.Canvas.Font.Color:=clWhite;
    end else if watts < 12.0 then begin
      bm.Canvas.Brush.Color:=clYellow;
      bm.Canvas.Font.Color:=clBlack;
    end else if watts < 15.0 then begin
      bm.Canvas.Brush.Color:=TColor($0080FF);
      bm.Canvas.Font.Color:=clWhite;
    end else begin
      bm.Canvas.Brush.Color:=TColor($0000FF);
      bm.Canvas.Font.Color:=clWhite;
    end;
    Label1.Caption:=newString;
    bm.Canvas.FillRect(0, 0, bm.Width, bm.Height);
    bm.Canvas.Font.Bold:=True;
    bm.Canvas.TextRect(TRect.Create(0,0,bm.Width,bm.Height), 0, 0, newString);
    TrayIcon1.Icon.Assign(bm);
  end
end;

procedure TForm1.FormCreate(Sender: TObject);
var
  iconSize: Integer;
  //iniPath: string;
begin
  bi := TBatteryInfo.Create;
  bm := TBitmap.Create;
  iconSize := Scale96ToFont(32);
  bm.SetSize(iconSize, iconSize);
  bm.Canvas.Font.Name:='Segoe UI';
  bm.Canvas.Font.Size:= Scale96ToFont(16);
  with bm.Canvas.TextStyle do begin
    Alignment:=taCenter;
    Layout := tlCenter;
  end;
  //brightnessctl:=TScreenBrightness.Create;
  //if (bi.GetBatteryStatus.PowerState and BATTERY_POWER_ON_LINE) = 0 then
  //  state:=DC
  //else
  //  state:=AC;
  //iniPath:=ExtractFilePath(Application.ExeName) + 'battery.ini';
  //settings:=TIniFile.Create(iniPath);
  //if state = AC then begin
  //  AcBrightness:= brightnessctl.GetBrightness;
  //  settings.WriteInteger('Brightness', 'ac', AcBrightness);
  //  DcBrightness:= settings.ReadInteger('Brightness', 'dc', 50);
  //end else begin
  //  AcBrightness:= settings.ReadInteger('Brightness', 'ac', 90);
  //  DcBrightness:= brightnessctl.GetBrightness;
  //  settings.WriteInteger('Brightness', 'dc', DcBrightness);
  //end;
  UpdateTrayIcon;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  bi.Free;
  bm.Free;
  //brightnessctl.Free;
  //settings.Free;
end;

procedure TForm1.ExitMenuItemClick(Sender: TObject);
begin
  Form1.Close;
end;

end.
