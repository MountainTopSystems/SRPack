unit CommonU;

interface

uses SysUtils, Classes, Winapi.Messages, Winapi.Windows, TypInfo, Contnrs, System.Types, json, System.IOUtils, ActiveX, System.Generics.Collections,
  zip, System.NetEncoding;

const WM_ThreadPoolUpate = WM_USER + 1;

const xdDir = 'XDNewVersion';
  // REFRESH_DB = 'DB\Refresh.db';
  // REFRESH_INI = 'INI\Refresh.ini';
  // Auth_ini = 'INI\Auth.ini';
  // AUTH_DB = 'DB\Auth.db';
  // USER_DB = 'DB\user.db';

  USERNAME_C = 'Username'; DEFUALT_UPLOAD = 'Upload'; DEFAULT_RESTORE = 'Restore'; DEFAULT_OLD_VERSION = 'RestoreFirst'; DEFAULT_UPLOAP = 'Upload';

  XDELTA_UPLOAD = 'XDUpload'; OLD_VERSION_FILE = 'OldVersion'; NEW_VERSION_FILE = 'NewVersion'; XDELTA_NEW_VERSION = 'XDNewVersion';
  ADMIN_RK = 'admin_rk'; ACCESS_GENERATE = 'ACCESS_KEY_OF_MTNBACKUP'; RT_USERNAME_DUPLICATE = '0'; RT_CANNOT_SAVE_DATA = '1';
  RT_ALL_ARE_SUCCESS = '2'; RT_SAVE_USER_AUTH_ERROR = '3'; RT_USERNAME_OR_PASSWORD_INCORRECT = '4';
  // Error messeges
  EM_DUPICATE_USERNAME = 'EM_DUPICATE_USERNAME'; EM_INVALID_USERNAME_OR_PASSWORD = 'EM_INVALID_USERNAME_OR_PASSWORD';
  C_Err_ValidateFailed = '-1:Validate Failed';

type
  TSettingsKey = (skSTDUPD, skBETAUPD, skGSCRIPT, skPachPath, skPrevPath, skCurPath, skTmpPath, skDownload, skVerStd, skVerBeta, skDLLPath);

type
  TPathTokens = (ptAPPPATH, ptSTDUPD, ptBETAUPD, ptGSCRIPT {global scripts} , ptCLSTD {clientid data path} , ptCLSCRIPT, ptCLSETTINGS);

const TPathTokensVal: array [TPathTokens] of string = ('APPPATH', 'STDUPD', 'BETAUPD', 'GSCRIPT', 'CLSTD', 'CLSCRIPT', 'CLSETTINGS');

const SettingsKeyVal: array [TSettingsKey] of string = ('ClientStdUpdatePath', 'ClientBetaUpdatePath', 'GlobalScriptPath', 'PachPath', 'PrevDataPath',
    'CurDataPath', 'TempPath', 'DownloadPath', 'Std Vertion', 'BetaVertion', 'DLLPath');

type
  TActiveFile = record
    Time: TDateTime;
    fname: string;
  end;

  TActiveClient = record
    CRTime: TDateTime;
    MDDT: TDateTime;
    CLID: string;
    RKey: string;
    ActiveFile: TList<TActiveFile>;
  end;

  summeryCli = class
    client: string;
    jsonStr: string;
  end;

  TServerStatusInfo = class
    client: string;
    fileName: string;
    size: string;
    startUpload: TDateTime;
    finishUpload: TDateTime;
  end;

  TLogInfo = class(TObject)
    typeA: Byte;
    CLID: string;
    ercode: int32;
    desc: string;
    exceptionMSG: string;
  end;

  AuthO = class
    statusCode: Integer;
    stats: string;
    client: string;
    authentication: string;
    refresh: string;
  end;

  TBackupInfo = class
    OriSize: Int64;
    PatchSize: Int64;
  end;

  TStrObj = class
    str: string;
  end;

  TClientReg = class
    username: string;
    password: string;
    pharmacyName: string;
    devicename: string;
  end;

  TSqlC = class
    // there must same colum and vlue u sve
    dbName: string;
    clumn: string;
    vlue: string;
  end;

  TStrObj2 = class
    NameA: string;
    Value: string;
  end;

  Restorelst = class
    ar: array of Int64;
  end;

  decodeStr = class
    prnt: string;
    version: Int64;
    path: string;
  end;

  svedVlue = class
    username: string;
    password: string;
    auth: string;
    rk: string;
  end;

  ReqAuth = class
    client: string;
    auth: string;
    refresh: string;
    isSuccess: Boolean;
  end;

  TPropertyBK = class
  public
    function GetProperty(cid, TopPath: string): Int64;
    function FileSize1(const aFilename: string): Int64;
    function DirSize(dir: string): Int64;
    function Filewrite(flname, vlu, path: string): Boolean;
  end;

  TAddLog = class(TThread)
  private
    lg: TLogInfo;
    procedure LogQueue(loginfo: TLogInfo);
  protected
    procedure Execute; override;
  public
    constructor Create(li: TLogInfo);
  end;

  TReqAuth = class(TThread)
  private
    rq: ReqAuth;
    procedure ReqQueue(re: ReqAuth);
  protected
    procedure Execute; override;
  public
    constructor Create(req: ReqAuth); overload;
  end;

  // Alog = TAddLog;
var APPPath: string; PatchDPath: WideString; PreDPath: string; NewDPath: string; TmpPath: string; DLLPath: string; DownloadPath: string; LogLvl: Byte;

var loglist: TStrings; authObj: TObjectList<ReqAuth>; ServerStatusList: TObjectList<TServerStatusInfo>;
  // function UItoStr(ui: TFileSlotInfo): string;
procedure LM(s: string; lvl: Byte = 0; CLID: string = '');
function OpenFileEx(path: TFileName): TFileStream;
function CreateZip(ZipPath, fileS, Root: string): tzipfile;
function strToJsn(s: string): TJSONObject;
function fileSize(const aFilename: string): Int64;

implementation

procedure LM(s: string; lvl: Byte; CLID: string);
begin
  if loglist = nil then exit;
  TThread.Queue(nil, procedure
    begin
      if loglist.Count > 1500 then loglist.Text := 'Auto cleared log @ ' + FormatDateTime('yyyy-mm-dd hh:mn:ss', Now());
      if LogLvl <= lvl then
      begin
        if CLID <> '' then CLID := '[' + CLID + '] ';
        loglist.Add(FormatDateTime('mm/dd hh:mn:ss', Now()) + CLID + s);
      end;
    end);
end;

function CreateZip(ZipPath, fileS, Root: string): tzipfile;
var s, rp, LFn: string;
  procedure AddDirectory(path: string);
  var LFile: string;
  begin
    for LFile in TDirectory.GetFiles(path, '*', TSearchOption.soAllDirectories) do
    begin
      LFn := StringReplace(LFile, Root, '', [rfReplaceAll]);
      LFn := StringReplace(LFn, '\', '/', [rfReplaceAll]);
      result.Add(LFile, LFn);
    end;
  end;
begin
  result := tzipfile.Create();
  Root := IncludeTrailingPathDelimiter(Root);
  try
    if not(FileExists(ZipPath)) then tfile.Create(ZipPath).free;
    result.Open(ZipPath, zmReadWrite);
    for s in fileS.Split([',']) do
    begin
      if s = '' then Continue;
      if DirectoryExists(s) then
      begin
        AddDirectory(s);
      end
      else
      begin
        if FileExists(s) then
        begin
          LFn := StringReplace(s, Root, '', [rfReplaceAll]);
          LFn := StringReplace(LFn, '\', '/', [rfReplaceAll]);
          LFn := StringReplace(LFn, '.send', '', [rfReplaceAll, rfIgnoreCase]);
          result.Add(s, LFn);
        end
        else LM('createZip()= file not exist :' + s)
      end;
    end;
  finally
    if result.FileCount < 1 then
    begin
      result.close;
      result.free;
    end;
  end;
end;

function strToJsn(s: string): TJSONObject;
begin
  result := nil;
  try
    result := TJSONObject.ParseJSONValue(s) as TJSONObject;
  except
    on e: exception do LM('Invalid JSON :' + s, 4);
  end;
end;

function OpenFileEx(path: TFileName): TFileStream;
begin
  // Result := nil;
  try
    ForceDirectories(ExtractFilePath(path));
    result := TFileStream.Create(path, fmOpenReadWrite + fmCreate);
  except
    // if GetLastError = ERROR_PATH_NOT_FOUND then
    begin

      ForceDirectories(ExtractFilePath(path));
      result := TFileStream.Create(path, fmOpenReadWrite or fmCreate);
    end;
  end;
end;

function fileSize(const aFilename: string): Int64;
var info: TWin32FileAttributeData;
begin
  result := -1;
  if not GetFileAttributesEx(PWideChar(aFilename), GetFileExInfoStandard, @info) then exit;
  result := Int64(info.nFileSizeLow) or Int64(info.nFileSizeHigh shl 32);
end;

// function UItoStr(ui: TFileSlotInfo): string;
// begin
// Result := Format('CID: %s , File: "%s" , Status: %s', [ui.FCLID, ui.fileName, ui.StatusMSG]);
// end;

{TAddLog}

constructor TAddLog.Create(li: TLogInfo);
begin
  inherited Create(false);
  lg := li;
end;

procedure TAddLog.Execute;
begin
  LogQueue(lg);
end;

procedure TAddLog.LogQueue(loginfo: TLogInfo);
begin
  // Synchronize(procedure
  // begin
  // loglist.Add(loginfo);
  // end);
end;

{TPropertyBK}

function TPropertyBK.DirSize(dir: string): Int64;
var s: Int64; fl: TStringDynArray; I: Integer;
begin
  s := 0;
  fl := TDirectory.GetFiles(dir, '*.*', TSearchOption.soAllDirectories);
  for I := 0 to Length(fl) - 1 do
  begin
    s := s + FileSize1(fl[I]);
  end;
  result := s;
end;

function TPropertyBK.FileSize1(const aFilename: string): Int64;
var info: TWin32FileAttributeData;
begin
  result := -1;
  if not GetFileAttributesEx(PWideChar(aFilename), GetFileExInfoStandard, @info) then exit;
  result := Int64(info.nFileSizeLow) or Int64(info.nFileSizeHigh shl 32);
end;

function TPropertyBK.Filewrite(flname, vlu, path: string): Boolean;
var
  // lgfl: TextFile;
  // path: string;
    ts: TStrings;
begin
  result := false;
  ts := TStringList.Create;
  try
    if FileExists(path) then ts.LoadFromFile(path);
    ts.Add(vlu);
    ts.SaveToFile(path);
  finally
    FreeAndNil(ts);
  end;
end;

function TPropertyBK.GetProperty(cid, TopPath: string): Int64;
var fl, ds: TStringDynArray; I, J: Integer; path: string;
begin
  result := 0;
  path := ExtractFilePath(ParamStr(0)) + xdDir + PathDelim + cid + PathDelim + cid + '.txt';
  if FileExists(path) then DeleteFile(PChar(path));
  ds := TDirectory.GetDirectories(TopPath, '*.*', TSearchOption.soTopDirectoryOnly);
  for I := 0 to Length(ds) - 1 do
  begin
    Filewrite(cid, ds[I] + ',' + IntToStr(DirSize(ds[I])), path);
    fl := TDirectory.GetDirectories(ds[I], '*.*', TSearchOption.soTopDirectoryOnly);
    for J := 0 to Length(fl) - 1 do Filewrite(cid, fl[J] + ',' + IntToStr(DirSize(fl[J])), path);
  end;
end;

{
  function FileSize(const aFilename: String): Int64;
  var
  info: TWin32FileAttributeData;
  begin
  result := -1;
  if NOT GetFileAttributesEx(PWideChar(aFilename), GetFileExInfoStandard, @info)
  then
  EXIT;
  result := Int64(info.nFileSizeLow) or Int64(info.nFileSizeHigh shl 32);
  end;
}

{TReqAuth}

constructor TReqAuth.Create(req: ReqAuth);
begin
  inherited Create(false);
  rq := req;
end;

procedure TReqAuth.Execute;
begin
  ReqQueue(rq);
end;

procedure TReqAuth.ReqQueue(re: ReqAuth);
begin
  Synchronize(procedure
    begin
      // loglist.Add(loginfo);

    end);
end;

end.
