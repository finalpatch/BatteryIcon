unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Menus, JwaBatClass, BatteryInfo;

type
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
  UpdateTrayIcon;
end;

procedure TForm1.UpdateTrayIcon;
var
  bs: TBatteryStatus;
  newString: string;
  watts: single = 0.0;
  fmt: string;
begin
  bs := bi.GetBatteryStatus;
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
begin
  bi := TBatteryInfo.Create;
  bm := TBitmap.Create;
  iconSize := Scale96ToFont(16);
  bm.SetSize(iconSize, iconSize);
  bm.Canvas.Font.Name:='Segoe UI';
  bm.Canvas.Font.Size:=6;
  with bm.Canvas.TextStyle do begin
    Alignment:=taCenter;
    Layout := tlCenter;
  end;
  UpdateTrayIcon;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  bi.Free;
  bm.Free;
end;

procedure TForm1.ExitMenuItemClick(Sender: TObject);
begin
  Form1.Close;
end;

end.
