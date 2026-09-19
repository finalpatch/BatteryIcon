unit main;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Menus, JwaBatClass, BatteryInfo, screenbrightness, IniFiles, LazLogger,
  LCLIntf, LMessages;

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
    NotificationWindow: HWND;
    IconDpi: Integer;
    IconDirty: Boolean;
    procedure NotificationWndProc(var Message: TLMessage);
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

const
  WM_REFRESH_TRAY = WM_USER + 1;
  // These power-event constants are absent from FPC 3.2.2's Windows unit.
  PBT_APMRESUMECRITICAL = $0006;
  PBT_APMRESUMESUSPEND = $0007;
  PBT_APMPOWERSTATUSCHANGE = $000A;
  PBT_APMRESUMEAUTOMATIC = $0012;

type
  TGetDpiForWindow = function(Wnd: HWND): UINT; stdcall;

var
  GetWindowDpi: TGetDpiForWindow;

{ TForm1 }

procedure TForm1.NotificationWndProc(var Message: TLMessage);
begin
  case Message.Msg of
    WM_POWERBROADCAST:
      begin
        case Message.WParam of
          PBT_APMRESUMEAUTOMATIC, PBT_APMRESUMESUSPEND,
          PBT_APMRESUMECRITICAL, PBT_APMPOWERSTATUSCHANGE:
            begin
              bi.Reset;
              PostMessage(NotificationWindow, WM_REFRESH_TRAY, 0, 0);
            end;
        end;
        Message.Result := 1;
      end;
    WM_DPICHANGED, WM_DISPLAYCHANGE, WM_SETTINGCHANGE:
      begin
        IconDpi := 0;
        PostMessage(NotificationWindow, WM_REFRESH_TRAY, 0, 0);
        Message.Result := 0;
      end;
    WM_REFRESH_TRAY:
      begin
        IconDirty := True;
        Timer1Timer(nil);
        Message.Result := 0;
      end;
  else
    Message.Result := DefWindowProc(NotificationWindow, Message.Msg,
      Message.WParam, Message.LParam);
  end;
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
  PrepareBitmap;
  UpdateTrayIcon;
end;

procedure TForm1.PrepareBitmap;
var
  dpi, iconSize: Integer;
  trayWindow: HWND;
begin
  // The hidden form can remain on a different monitor from the taskbar.
  // Poll as well as handling broadcasts: taskbar DPI can change independently.
  dpi := Screen.PixelsPerInch;
  trayWindow := FindWindow('Shell_TrayWnd', nil);
  if Assigned(GetWindowDpi) and (trayWindow <> 0) then
    dpi := GetWindowDpi(trayWindow);
  if dpi <= 0 then dpi := 96;
  iconSize := MulDiv(32, dpi, 96);
  if (IconDpi <> dpi) or (bm.Width <> iconSize) then begin
    IconDpi := dpi;
    bm.SetSize(iconSize, iconSize);
    // Pixel height avoids scaling points a second time using the screen DPI.
    bm.Canvas.Font.Height := -MulDiv(12, dpi, 72);
    IconDirty := True;
  end;
end;

procedure TForm1.UpdateTrayIcon;
var
  bs: TBatteryStatus;
  newString: string;
  watts: single = 0.0;
  fmt: string;
  power: TSystemPowerStatus;
  onAC, charging, statusValid, powerKnown: Boolean;
  //newState: PowerState;
  //saveBrightness: BrightnessRange;
begin
  statusValid := bi.TryGetBatteryStatus(bs);
  powerKnown := GetSystemPowerStatus(power) and (power.ACLineStatus <> 255);
  if powerKnown then begin
    onAC := power.ACLineStatus = 1;
    charging := onAC and (power.BatteryFlag <> 255) and
      ((power.BatteryFlag and 8) <> 0);
  end else begin
    onAC := statusValid and ((bs.PowerState and BATTERY_POWER_ON_LINE) <> 0);
    charging := onAC and ((bs.PowerState and BATTERY_CHARGING) <> 0);
  end;

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

  if charging then begin
    newString := '>>';
  end else if onAC then begin
    newString := 'AC';
  end else if (not statusValid) or (DWORD(bs.Rate) = BATTERY_UNKNOWN_RATE) or
    ((bs.PowerState and BATTERY_DISCHARGING) = 0) then begin
    newString := '--';
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
  if IconDirty or (Label1.Caption<>newString) then begin
    if onAC then begin
      bm.Canvas.Brush.Color:=clLime;
      bm.Canvas.Font.Color:=clBlack;
    end else if newString = '--' then begin
      bm.Canvas.Brush.Color:=clGray;
      bm.Canvas.Font.Color:=clWhite;
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
    IconDirty := False;
  end
end;

procedure TForm1.FormCreate(Sender: TObject);
  //iniPath: string;
begin
  bi := TBatteryInfo.Create;
  bm := TBitmap.Create;
  Pointer(GetWindowDpi) := GetProcAddress(GetModuleHandle('user32.dll'),
    'GetDpiForWindow');
  bm.Canvas.Font.Name:='Segoe UI';
  PrepareBitmap;
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
  NotificationWindow := LCLIntf.AllocateHWnd(@NotificationWndProc);
  UpdateTrayIcon;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  Timer1.Enabled := False;
  if NotificationWindow <> 0 then
    LCLIntf.DeallocateHWnd(NotificationWindow);
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
