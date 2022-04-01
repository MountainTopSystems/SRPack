unit SRPanel;

{*******************************************************}

{       SPanel                                          }

{       Copyright (C) 2013 HKSS                         }

{*******************************************************
 Unit:    SPanel.pas
 Purpose: Search Panel VCL Component
 Author:  kranga
 Date:    3/31/2013 2:55:19 PM
 Version: 1.0
 Tips:    if .Exec(sender =nil)  then SPanel position is owner(form) center
          if Setup() _WH=point(0,0) then Default with(600) & height(400) applies
          
 Sample:
          SPanel1.Setup([80,0],'select emp_code as [CODE], emp_name as [NAME] from emp_master where emp_code like :emp_Code or emp_name like :emp_name',Point(300,300),F_Com_Data.Ado_connection_client);
          if SPanel1.Exec(Sender)<>mrok exit;    //if sender =nil  then SPanel position is owner(form) center
          l_val:=SPanel1.qy.FieldByName('name').AsString;

 sample 2 [DuplicateSearch;]
          on enter event:
            SPanel1.P_SetupDuplicateSearch(ed_supGName,Point(ed_supGName.Width,200),'SuperGroup','Super_Group_Name',l_con);

          on change event:
              SPanel1.P_ShowDuplicateSearch;
          on exit event:
            SPanel1.P_CloseDuplicateSearch;


*******************************************************}

interface

uses ComCtrls, DB, ADODB, Classes, Controls, ExtCtrls, StdCtrls, Dialogs, DBGrids, Windows, Forms, Buttons, Math, Messages;

//{$ObjExportAll On}

type
  TSPType = (SPTSearchPanel, SPTDuplicate);

  TSPanel = class(TCustomPanel)
  public
    qy:       TADOQuery;
    L_Result: integer;
    function Exec(Sender: TObject = nil): integer;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    //    procedure Setup(ColWArr: array of integer; SqlTxt: string; _Topleft: TPoint; _WH: TPoint; Con: TADOConnection = nil; def_val: string = ''); overload;
    procedure Setup(ColWArr: array of integer; SqlTxt: string; _WH: TPoint; Con: TADOConnection = nil; def_val: string = '');
    procedure P_Setup(SqlTxt: string; _Topleft: TPoint; _WH: TPoint; Con: TADOConnection = nil; def_val: string = ''; SPType: TSPType = SPTSearchPanel; obj: TWinControl = nil);
    procedure P_SetColumnWidth(arg: array of integer; BestFit: boolean = True);//arg="100,20,0,..,0,100" //0 will be ignored // -1 will hide coloumn
    procedure P_SetupDuplicateSearch(obj: TWinControl; _WH: TPoint; tbl_name, Fld_name: string; con: TADOConnection);
    procedure P_ShowDuplicateSearch();
    procedure P_CloseDuplicateSearch();
  private
    l_focused: boolean;
    l_exit:    boolean;
    l_SPType:  TSPType;
    l_editBox: TWinControl;
    ds:        TDataSource;
    bt_exit:   TSpeedButton;
    ed_search: TEdit;
    dbgrid:    TDBGrid;
    function P_SQLGen(tbl_name, fld_name, Fld_caption: string): string;
    procedure SPExit(Sender: TObject);
    procedure P_KeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure ed_searchChange(Sender: TObject);
    procedure bt_okClick(Sender: TObject);
    procedure WMDestroy(var Message: TWMDestroy); message WM_DESTROY;
    procedure WMClose(var Message: TWMClose); message WM_CLOSE;
    procedure FocusIn(Sender: TObject);
  protected
    procedure WndProc(var Msg: TMessage); override;
  end;


var
  L_SQLRecLimit: integer = 100;

procedure Register;

{---------------------------------------------------------------------------}
implementation

uses Consts, SysUtils;

procedure TSPanel.WndProc(var Msg: TMessage);
begin
  inherited;
  case Msg.Msg of
    WM_DESTROY, WM_CLOSE, WM_KILLFOCUS: l_exit := True;
    WM_SETFOCUS: l_focused := True;
  end;
end;

procedure TSPanel.FocusIn(Sender: TObject);
begin
  l_focused := True;
end;

constructor TSPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Self.Caption := '';
  Self.Visible := False;
  Self.OnExit := SPExit;
  bt_exit := TSpeedButton.Create(Self);
  Parent  := TWinControl(AOwner);
  with bt_exit do
  begin
    SetBounds(Self.Width - 18, 0, 18, 21);
    Caption := 'X';
    Font.Color := $00FA8A8A;
    Flat := True;
    Layout := blGlyphRight;
    ParentFont := False;
    Font.Name := 'Arial Black';
    OnClick := SPExit;
    Parent := Self;
    Anchors := [akTop, akRight];
  end;
  ed_search := TEdit.Create(Self);
  with ed_search do
  begin
    SetBounds(0, 0, Self.Width - 19, 21);
    Anchors := [akLeft, akTop, akRight];
    BevelInner := bvNone;
    BevelKind := bkFlat;
    BorderStyle := bsNone;
    CharCase := ecUpperCase;
    TabOrder := 0;
    OnChange := ed_searchChange;
    OnKeyUp := P_KeyUp;
    Parent := Self;
    Font.Name := 'Arial';
    Font.Size := 12;
  end;
  qy := TADOQuery.Create(Self);
  with qy do
  begin
    LockType := ltReadOnly;
  end;
  ds := TDataSource.Create(Self);
  with ds do
  begin
    AutoEdit := False;
    DataSet  := qY;
  end;

  dbgrid := TDBGrid.Create(Self);
  with dbgrid do
  begin
    SetBounds(1, 22, Self.Width - 2, Self.Height - 24);
    Parent  := Self;
    DataSource := ds;
    BorderStyle := bsNone;
    Options := [dgTitles, dgColumnResize, dgColLines, dgRowLines, dgRowSelect, dgConfirmDelete, dgCancelOnExit];
    ReadOnly := True;
    FixedColor := $00FAFAFA;
    Anchors := [akLeft, akTop, akRight, akBottom];
    OnKeyUp := P_KeyUp;
    OnDblClick := bt_okClick;
    OnEnter := FocusIn;
  end;
end;

destructor TSPanel.Destroy;
begin
  L_result := mrAbort;
  qy.Close;
  FreeAndNil(qy);
  FreeAndNil(dbgrid);

  inherited Destroy;
end;

procedure TSPanel.WMClose(var Message: TWMClose);
begin
  if L_result = 0 then
    L_result := mrCancel;
end;

procedure TSPanel.WMDestroy(var Message: TWMDestroy);
begin
  if L_result = 0 then
    L_result := mrCancel;
end;

procedure TSPanel.SPExit(Sender: TObject);
begin
  if L_result = 0 then
    L_result := mrCancel;
end;

function TSPanel.Exec(Sender: TObject = nil): integer;
begin
  Result := mrCancel;
  if Sender is TControl then
  begin
    Self.Top  := TControl(Sender).ClientOrigin.y - TControl(Owner).ClientOrigin.y;
    Self.Left := TControl(Sender).ClientOrigin.X - TControl(Owner).ClientOrigin.X;
  end
  else
  begin
    Self.Top  := ((TWinControl(Owner).Height - self.Height) div 2) - 20;
    Self.Left := (TWinControl(Owner).Width - self.Width) div 2;
  end;
  if (qy.Connection = nil) or (qy.SQL.Text = '') then
  begin
    MessageDlg('Not configured.' + #13#10 + 'Call "Setup" method before calling "Exec" method', mtError, [mbOK], 0);
  end;
  L_result := 0;
  AnimateWindow(self.Handle, 200, AW_VER_POSITIVE or AW_SLIDE or AW_ACTIVATE);
  Self.Show;
  Application.ProcessMessages;
  ed_search.SelectAll;
  ed_search.SetFocus;
  repeat
    begin
      Application.HandleMessage;
      if TForm(Owner).Visible = False then
        L_result := mrAbort;
    end
  until (L_result <> 0);
  if L_result = mrAbort then
    Exit;
  AnimateWindow(self.Handle, 150, AW_VER_NEGATIVE or AW_SLIDE or AW_HIDE);
  Self.Hide;
  Application.ProcessMessages;
  Result := L_result;
  if TForm(Owner).ActiveControl <> nil then
    TForm(Owner).ActiveControl.SetFocus
  else if Sender is TWinControl then
    TWinControl(Sender).SetFocus;
end;

procedure TSPanel.P_KeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  if key = vK_Down then
  begin
    if qy.RecordCount > 0 then
      dbgrid.SetFocus;
  end
  else
  if (key = vK_up) then
  begin
    if (qy.RecNo = 1) then
      ed_search.SetFocus;
  end else
  if (key = VK_ESCAPE) then
  begin
    SPExit(nil);
  end
  else if (key = VK_RETURN) then
    bt_okClick(nil);
end;

procedure TSPanel.bt_okClick(Sender: TObject);
begin
  l_result := mrOk;
  if qy.RecordCount < 1 then
  begin
    l_result := mrCancel;
  end;
end;

procedure TSPanel.ed_searchChange(Sender: TObject);
var
  i: integer;
begin
  Application.ProcessMessages;
  with  qY do
  begin
    Close;
    for i := 0 to (Parameters.Count - 1) do
      Parameters[i].Value := '%' + tedit(l_editBox).Text + '%';
    Open;
  end;
end;

 //procedure TSPanel.Setup(ColWArr: array of integer; SqlTxt: string; _Topleft: TPoint; _WH: TPoint; Con: TADOConnection = nil; def_val: string = '');
 //begin
 //  P_Setup(SqlTxt, _Topleft, _WH, Con, def_val);
 //  if High(ColWArr) > 0 then
 //    P_SetColumnWidth(ColWArr);
 //end;

procedure TSPanel.Setup(ColWArr: array of integer; SqlTxt: string; _WH: TPoint; Con: TADOConnection = nil; def_val: string = '');
begin
  P_Setup(SqlTxt, POINT(0, 0), _WH, Con, def_val);
  if High(ColWArr) > 0 then
    P_SetColumnWidth(ColWArr);
end;

procedure TSPanel.P_Setup(SqlTxt: string; _Topleft: TPoint; _WH: TPoint; Con: TADOConnection = nil; def_val: string = ''; SPType: TSPType = SPTSearchPanel; obj: TWinControl = nil);
var
  i: integer;
begin
  qy.Close;
  l_SPType := SPType;
  if not (con = nil) and (con <> qy.Connection) then
    qy.Connection := con;
  if (SPType = SPTDuplicate) then
    _Topleft := Point(obj.ClientOrigin.X - TControl(Owner).ClientOrigin.X, obj.ClientOrigin.y - TControl(Owner).ClientOrigin.y + obj.Height);
  if (_WH.X = 0) and (_WH.Y = 0) then
    _WH := point(600, 400);
  Self.BoundsRect := Bounds(_Topleft.X - 1, _Topleft.Y - 1, _WH.X - 4, _WH.Y);
  if SqlTxt = '' then
    exit;
  SqlTxt := UpperCase(SqlTxt);
  SqlTxt := StringReplace(SqlTxt, '{TOP}', 'TOP ' + IntToStr(100), [rfIgnoreCase]);
  if POS(' TOP ', SqlTxt) < 1 then
    SqlTxt := StringReplace(SqlTxt, 'SELECT', 'SELECT TOP ' + IntToStr(L_SQLRecLimit), [rfIgnoreCase]);
  qy.SQL.Text := SqlTxt;
  for i := 0 to (qy.Parameters.Count - 1) do
    qy.Parameters[i].Value := '%' + trim(def_val) + '%';
  try
    ed_search.Text := def_val;
    qy.Open;
  except

  end;
  ed_search.Visible := not (SPType = SPTDuplicate);
  bt_exit.Visible := not (SPType = SPTDuplicate);
  if (SPType = SPTDuplicate) then
  begin
    dbgrid.SetBounds(1, 1, Self.Width - 2, Self.Height - 2);
    dbgrid.Options := [dgRowLines, dgTabs];
    l_editBox := obj;
  end
  else
  begin
    dbgrid.SetBounds(1, 22, Self.Width - 2, Self.Height - 24);
    dbgrid.Options := [dgTitles, dgIndicator, dgColLines, dgRowLines, dgTabs, dgConfirmDelete, dgCancelOnExit];
    l_editBox := ed_search;
  end;

end;

procedure TSPanel.P_SetColumnWidth(arg: array of integer; BestFit: boolean = True);//arg="100,20,0,..,0,100" //0 will be ignored // -1 will hide coloumn
var
  i, _dta, _sum, _vW: integer;                                                      // call this after p_setup and befor showmodel
  _dtW: real;

begin
  _dta := 0;
  _vW  := 0;
  _sum := 0;
  for i := 0 to High(arg) do
  begin
    if arg[i] = 0 then
      Inc(_dta)
    else if arg[i] > 0 then
      _sum := _sum + arg[i];
  end;
  _dta := _dta + (dbgrid.Columns.Count - (i));
  _dtW := (Self.Width - 22) / _sum;
  if _dta > 0 then // variable width field exist
    _vW := ((Self.Width - 22) - _sum) div _dta;
  for i := 0 to High(arg) do
    if (arg[i] > 0) and (_dta = 0) then
      arg[i] := Round(arg[i] * _dtw)
    else if (arg[i] = 0) then
      arg[i] := _vW;

  for i := 0 to High(arg) do
  begin
    if arg[i] < 0 then
      dbgrid.Columns[i].Visible := False
    else
      dbgrid.Columns[i].Width := arg[i];
  end;
  if i < (dbgrid.Columns.Count) then
    while i <> (dbgrid.Columns.Count - 1) do
      dbgrid.Columns[i].Width := _vW;

  //----------------------------------
  //  _i := 0;
  //  _dta := 0;
  //  _vW:=0;
  //  for i := Low(arg) to High(arg) do
  //  begin
  //    if arg[i] = -1 then
  //    begin
  //      dbgrid.Columns[i].Visible := False;
  //      Inc(_i);
  //    end
  //    else if arg[i] = 0 then
  //      Inc(_dta);

  //  end;

  //  _sum := Round(SumInt(arg)) - _i;
  //  if _dta > 0 then
  //  begin
  //    _dtW := 1;
  //    _vW  :=((Self.Width - 22) - _Sum) DIV _dta;
  //  end
  //  else
  //    _dtW := (Self.Width - 22) / _sum;
  //_i:=0;
  //  for i := Low(arg) to High(arg) do
  //  begin
  //    if arg[i] >-1 then
  //    begin
  //    if arg[i] > 0 then
  //      dbgrid.Columns[i].Width := Round(arg[i] * _dtW)
  //      else
  //    dbgrid.Columns[i].Width := _vw;
  //    _i:=_i+dbgrid.Columns[i].Width
  //  end;
  //  end;
  //if _i>(dbgrid.Width-20) then
  //array
  //  MaxIntValue()
end;

procedure TSPanel.P_SetupDuplicateSearch(obj: TWinControl; _WH: TPoint; tbl_name, Fld_name: string; con: TADOConnection);
begin
  if (Self.Showing) then
    Exit;
  P_Setup(P_SQLGen(tbl_name, Fld_name, ''), point(0, 0), _wh, con, '', SPTDuplicate, obj);
end;

function TSPanel.P_SQLGen(tbl_name, fld_name, Fld_caption: string): string;
  //var
  //  _sql: string;
begin
  if (Fld_caption <> '') then
    Fld_caption := ' as ' + Fld_caption;
  Result := 'select ' + fld_name + Fld_caption + ' from ' + tbl_name + ' where ' + fld_name + ' like :' + fld_name;
end;

procedure TSPanel.P_ShowDuplicateSearch();
begin
  try
    if not (Self.Showing) then
    begin
      Self.BringToFront;
      AnimateWindow(self.Handle, 200, AW_VER_POSITIVE or AW_SLIDE or AW_ACTIVATE);
      Self.Show;
    end;
    if qy.Connection <> nil then
    begin
      ed_searchChange(l_editBox);
      dbgrid.Columns[0].Width := dbgrid.ClientWidth - 2;
      L_Result := 0;
      l_exit := False;
    end;

  except

  end;

end;

procedure TSPanel.P_CloseDuplicateSearch();
var
  x: HWND;
begin
  try
    while (TForm(Owner).ActiveControl.Name = '') and (L_result = 0) and not (l_focused) and not (l_exit) and (TForm(Owner).Showing) do
    begin
      Application.ProcessMessages;
      Sleep(100);
    end;

    if (TForm(Owner).ActiveControl <> Self) and (TForm(Owner).ActiveControl <> l_editBox) then
      Self.Hide;
  except

  end;
end;

{---------------------------------------------------------------------------}

procedure Register;
begin
  RegisterComponents('HKSS', [TSPanel]);
end;

{---------------------------------------------------------------------------}

end.
