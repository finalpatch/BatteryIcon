unit BatteryInfo;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Windows, JwaBatClass;

const
  DIGCF_PRESENT      = $00000002;
  DIGCF_DEVICEINTERFACE = $00000010;
  SetupApiModuleName = 'SetupApi.dll';

type
  HDEVINFO = Pointer;

  PSPDeviceInterfaceData = ^TSPDeviceInterfaceData;

  SP_DEVICE_INTERFACE_DATA = packed record
    cbSize:   DWORD;
    InterfaceClassGuid: TGUID;
    Flags:    DWORD;
    Reserved: ULONG_PTR;
  end;
  TSPDeviceInterfaceData = SP_DEVICE_INTERFACE_DATA;

  PSPDevInfoData = ^TSPDevInfoData;

  SP_DEVINFO_DATA = packed record
    cbSize:    DWORD;
    ClassGuid: TGUID;
    DevInst:   DWORD; // DEVINST handle
    Reserved:  ULONG_PTR;
  end;
  TSPDevInfoData = SP_DEVINFO_DATA;

  PSPDeviceInterfaceDetailDataA = ^TSPDeviceInterfaceDetailDataA;

  SP_DEVICE_INTERFACE_DETAIL_DATA_A = packed record
    cbSize:     DWORD;
    DevicePath: array [0..ANYSIZE_ARRAY - 1] of AnsiChar;
  end;
  TSPDeviceInterfaceDetailDataA = SP_DEVICE_INTERFACE_DETAIL_DATA_A;
  TSPDeviceInterfaceDetailData = TSPDeviceInterfaceDetailDataA;
  PSPDeviceInterfaceDetailData = PSPDeviceInterfaceDetailDataA;

  TSetupDiGetClassDevs = function(ClassGuid: PGUID; const aEnumerator: PTSTR;
    hwndParent: HWND; Flags: DWORD): HDEVINFO; stdcall;

  TSetupDiDestroyDeviceInfoList = function(DeviceInfoSet: HDEVINFO): BOOL; stdcall;

  TSetupDiEnumDeviceInterfaces = function(DeviceInfoSet: HDEVINFO;
    DeviceInfoData: PSPDevInfoData; const InterfaceClassGuid: TGUID;
    MemberIndex: DWORD; var DeviceInterfaceData: TSPDeviceInterfaceData): BOOL; stdcall;

  TSetupDiGetDeviceInterfaceDetail = function(DeviceInfoSet: HDEVINFO;
    DeviceInterfaceData: PSPDeviceInterfaceData;
    DeviceInterfaceDetailData: PSPDeviceInterfaceDetailData;
    DeviceInterfaceDetailDataSize: DWORD; var RequiredSize: DWORD;
    Device: PSPDevInfoData): BOOL; stdcall;

  { TBatteryInfo }

  TBatteryInfo = class
  private
    hBat: HANDLE;
    bws:  TBatteryWaitStatus;
  public
    constructor Create;
    destructor Destroy; override;
    function GetBatteryStatus: TBatteryStatus;
  end;

implementation

var
  SetupApiLib: HINST;
  SetupDiGetClassDevs: TSetupDiGetClassDevs;
  SetupDiDestroyDeviceInfoList: TSetupDiDestroyDeviceInfoList;
  SetupDiEnumDeviceInterfaces: TSetupDiEnumDeviceInterfaces;
  SetupDiGetDeviceInterfaceDetail: TSetupDiGetDeviceInterfaceDetail;

{ TBatteryInfo }

constructor TBatteryInfo.Create;
var
  hDev:   HDEVINFO;
  iDev:   integer;
  did:    TSPDeviceInterfaceData;
  didd:   PSPDeviceInterfaceDetailData;
  res:    BOOL;
  dwSize: DWORD;
  bqi:    TBatteryQueryInformation;
  dwWait: DWORD;
  dwOut:  DWORD;
begin
  hBat := INVALID_HANDLE_VALUE;
  hDev := SetupDiGetClassDevs(@GUID_DEVICE_BATTERY, nil, 0, DIGCF_PRESENT or
    DIGCF_DEVICEINTERFACE);
  if hDev <> pointer(INVALID_HANDLE_VALUE) then
  begin
    for iDev := 0 to 10 do
    begin
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
        didd^.cbSize := 8;
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
            if res then
            begin
              FillMemory(@bws, Sizeof(bws), 0);
              bws.BatteryTag := bqi.BatteryTag;
            end;
          end;
        end;
        FreeMem(didd);
      end;
    end;
    SetupDiDestroyDeviceInfoList(hDev);
  end;
end;

destructor TBatteryInfo.Destroy;
begin
  if (INVALID_HANDLE_VALUE <> hBat) then
  begin
    CloseHandle(hBat);
  end;
  inherited Destroy;
end;

function TBatteryInfo.GetBatteryStatus: TBatteryStatus;
var
  dwOut: DWORD;
begin
  DeviceIoControl(hBat, IOCTL_BATTERY_QUERY_STATUS, @bws, sizeof(bws), @Result,
    sizeof(TBatteryStatus), @dwOut, nil);
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
