unit BatteryInfo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Windows, JwaBatClass;

const
  DIGCF_PRESENT         = $00000002; 
  DIGCF_DEVICEINTERFACE = $00000010;
  SetupApiModuleName    = 'SetupApi.dll';

type
  HDEVINFO                          = Pointer;
                                    
  PSPDeviceInterfaceData            = ^TSPDeviceInterfaceData;
                                    
  SP_DEVICE_INTERFACE_DATA          = packed record
                                        cbSize             : DWORD;
                                        InterfaceClassGuid : TGUID;
                                        Flags              : DWORD;
                                        Reserved           : ULONG_PTR;
                                      end;                 
  TSPDeviceInterfaceData            = SP_DEVICE_INTERFACE_DATA;
                                    
  PSPDevInfoData                    = ^TSPDevInfoData;
                                    
  SP_DEVINFO_DATA                   = packed record
                                        cbSize    : DWORD;
                                        ClassGuid : TGUID;
                                        DevInst   : DWORD; // DEVINST handle
                                        Reserved  : ULONG_PTR;
                                      end;        
  TSPDevInfoData                    = SP_DEVINFO_DATA;
                                    
  PSPDeviceInterfaceDetailDataA     = ^TSPDeviceInterfaceDetailDataA;
                                    
  SP_DEVICE_INTERFACE_DETAIL_DATA_A = packed record
                                        cbSize     : DWORD;
                                        DevicePath : array [0..ANYSIZE_ARRAY - 1] of AnsiChar;
                                      end;         
  TSPDeviceInterfaceDetailDataA     = SP_DEVICE_INTERFACE_DETAIL_DATA_A;
  TSPDeviceInterfaceDetailData      = TSPDeviceInterfaceDetailDataA;
  PSPDeviceInterfaceDetailData      = PSPDeviceInterfaceDetailDataA;
                                    
  TSetupDiGetClassDevs              = function(ClassGuid: PGUID; const aEnumerator: PTSTR;
    hwndParent: HWND; Flags: DWORD): HDEVINFO; stdcall;
                                    
  TSetupDiDestroyDeviceInfoList     = function(DeviceInfoSet: HDEVINFO): BOOL; stdcall;
                                    
  TSetupDiEnumDeviceInterfaces      = function(DeviceInfoSet: HDEVINFO;
    DeviceInfoData: PSPDevInfoData; const InterfaceClassGuid: TGUID;
    MemberIndex: DWORD; var DeviceInterfaceData: TSPDeviceInterfaceData): BOOL; stdcall;
                                    
  TSetupDiGetDeviceInterfaceDetail  = function(DeviceInfoSet: HDEVINFO;
    DeviceInterfaceData: PSPDeviceInterfaceData;
    DeviceInterfaceDetailData: PSPDeviceInterfaceDetailData;
    DeviceInterfaceDetailDataSize: DWORD; var RequiredSize: DWORD;
    Device: PSPDevInfoData): BOOL; stdcall;
                                    
  { TBatteryInfo }                  
                                    
  TBatteryInfo                      = class
   private
    hBat : HANDLE;
    bws  : TBatteryWaitStatus;
    procedure OpenBattery;
    function QueryStatus(out Status: TBatteryStatus): Boolean;
   public
    constructor Create;
    destructor Destroy; override;
    procedure Reset;
    function TryGetBatteryStatus(out Status: TBatteryStatus): Boolean;
    function GetBatteryStatus: TBatteryStatus;
  end;   

implementation

var
  SetupApiLib                     : HINST;
  SetupDiGetClassDevs             : TSetupDiGetClassDevs;
  SetupDiDestroyDeviceInfoList    : TSetupDiDestroyDeviceInfoList;
  SetupDiEnumDeviceInterfaces     : TSetupDiEnumDeviceInterfaces;
  SetupDiGetDeviceInterfaceDetail : TSetupDiGetDeviceInterfaceDetail;
                                  
{ TBatteryInfo }                  

constructor TBatteryInfo.Create;
begin
  inherited Create;
  hBat := INVALID_HANDLE_VALUE;
end;

procedure TBatteryInfo.Reset;
begin
  if hBat <> INVALID_HANDLE_VALUE then
    CloseHandle(hBat);
  hBat := INVALID_HANDLE_VALUE;
  FillChar(bws, SizeOf(bws), 0);
end;

procedure TBatteryInfo.OpenBattery;
var
  hDev   : HDEVINFO;
  iDev   : integer;
  did    : TSPDeviceInterfaceData;
  didd   : PSPDeviceInterfaceDetailData;
  res    : BOOL;
  dwSize : DWORD;
  bqi    : TBatteryQueryInformation;
  dwWait : DWORD;
  dwOut  : DWORD;
begin
  Reset;
  hDev := SetupDiGetClassDevs(@GUID_DEVICE_BATTERY, nil, 0, DIGCF_PRESENT or
    DIGCF_DEVICEINTERFACE);
  if hDev <> pointer(INVALID_HANDLE_VALUE) then
  begin
    for iDev := 0 to 10 do
    begin
      FillChar(did, SizeOf(did), 0);
      did.cbSize := SizeOf(did);
      res := SetupDiEnumDeviceInterfaces(hDev, nil,
        GUID_DEVICE_BATTERY, iDev, did);
      if not res then
        break;
      dwSize := 0;
      SetupDiGetDeviceInterfaceDetail(hDev, @did, nil, 0, dwSize, nil);
      if (dwSize <> 0) then
      begin
        didd := AllocMem(dwSize);
        FillMemory(didd, dwSize, 0);
        {$IFDEF WIN64}
        didd^.cbSize := 8;
        {$ELSE}
        didd^.cbSize := 5;
        {$ENDIF}
        res := SetupDiGetDeviceInterfaceDetail(hDev, @did,
          didd, dwSize, dwSize, nil);
        if res then
        begin
          // got a battery, open it
          hBat := CreateFile(didd^.DevicePath, GENERIC_READ or
            GENERIC_WRITE, FILE_SHARE_READ or FILE_SHARE_WRITE, nil,
            OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
          if (INVALID_HANDLE_VALUE <> hBat) then
          begin
            // Ask the battery for its tag
            dwWait := 0;
            FillMemory(@bqi, Sizeof(bqi), 0);
            res := DeviceIoControl(hBat, IOCTL_BATTERY_QUERY_TAG,
              @dwWait, sizeof(dwWait), @bqi.BatteryTag,
              sizeof(bqi.BatteryTag), @dwOut, nil);
            if res and (dwOut = SizeOf(bqi.BatteryTag)) and
              (bqi.BatteryTag <> 0) then
            begin
              FillMemory(@bws, Sizeof(bws), 0);
              bws.BatteryTag := bqi.BatteryTag;
            end else
              Reset;
          end;
        end;
        FreeMem(didd);
        // Keep the first usable battery; do not overwrite/leak its handle.
        if hBat <> INVALID_HANDLE_VALUE then
          Break;
      end;
    end;
    SetupDiDestroyDeviceInfoList(hDev);
  end;
end;

destructor TBatteryInfo.Destroy;
begin
  Reset;
  inherited Destroy;
end;

function TBatteryInfo.QueryStatus(out Status: TBatteryStatus): Boolean;
var
  dwOut : DWORD;
begin
  FillChar(Status, SizeOf(Status), 0);
  Result := (hBat <> INVALID_HANDLE_VALUE) and
    DeviceIoControl(hBat, IOCTL_BATTERY_QUERY_STATUS, @bws, SizeOf(bws),
      @Status, SizeOf(Status), @dwOut, nil) and (dwOut = SizeOf(Status));
end;

function TBatteryInfo.TryGetBatteryStatus(out Status: TBatteryStatus): Boolean;
begin
  if hBat = INVALID_HANDLE_VALUE then
    OpenBattery;
  Result := QueryStatus(Status);
  if not Result then begin
    // Battery tags and device handles can become invalid across suspend.
    OpenBattery;
    Result := QueryStatus(Status);
  end;
  if not Result then begin
    Reset;
    FillChar(Status, SizeOf(Status), 0);
    Status.Rate := LongInt(BATTERY_UNKNOWN_RATE);
  end;
end;

function TBatteryInfo.GetBatteryStatus: TBatteryStatus;
begin
  TryGetBatteryStatus(Result);
end;

initialization
  SetupApiLib := LoadLibrary(SetupApiModuleName);
  pointer(SetupDiGetClassDevs) :=
    GetProcedureAddress(SetupApiLib, 'SetupDiGetClassDevsA');
  pointer(SetupDiDestroyDeviceInfoList) :=
    GetProcAddress(SetupApiLib, 'SetupDiDestroyDeviceInfoList');
  pointer(SetupDiEnumDeviceInterfaces) :=
    GetProcAddress(SetupApiLib, 'SetupDiEnumDeviceInterfaces');
  pointer(SetupDiGetDeviceInterfaceDetail) :=
    GetProcAddress(SetupApiLib, 'SetupDiGetDeviceInterfaceDetailA');
end.
