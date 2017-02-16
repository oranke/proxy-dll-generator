unit MainUnit;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  //Windows, ShellAPI,

  VirtualTrees,

  LCLIntf,

  PE.Common,
  PE.Image,
  PE.ExportSym

  ;

type

  { TMainForm }

  TMainForm = class(TForm)
    CodeGenButton: TButton;
    CodeMemo: TMemo;
    FuncsVST: TVirtualStringTree;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    OpenDialog1: TOpenDialog;
    OrgDllFileNameBtn: TButton;
    OrgDllFileNameEdit: TEdit;
    PointDllNameEdit: TEdit;
    SaveDialog1: TSaveDialog;
    procedure CodeGenButtonClick(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of String);
    procedure FuncsVSTGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: String);
    procedure Label3Click(Sender: TObject);
    procedure Label3MouseEnter(Sender: TObject);
    procedure Label3MouseLeave(Sender: TObject);
    procedure OrgDllFileNameBtnClick(Sender: TObject);
  private
    { private declarations }
    fPEImage: TPEImage;
    procedure LoadDLL(const aDLLFileName: String);
  public
    { public declarations }
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

function ExtractJustName(const FileName: String): String;
begin
  Result := ExtractFileName(FileName);
  SetLength(Result, Length(Result) - Length(ExtractFileExt(FileName)));
end;

{ TMainForm }


constructor TMainForm.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  fPEImage:= TPEImage.Create;
end;

destructor TMainForm.Destroy;
begin
  fPEImage.Free;
  inherited Destroy;
end;

procedure TMainForm.LoadDLL(const aDLLFileName: String);
begin
  FuncsVST.Clear;

  OrgDllFileNameEdit.Text := '';
  PointDllNameEdit.Text := '';

  if not fPEImage.LoadFromFile(aDLLFileName, [PF_EXPORT]) then
  begin
    MessageDlg('Failed to load dll', mtError, [mbOK], 0);
    Exit;
  end;

  //ShowMessage(IntToStr(fPEImage.ExportSyms.Count));

  OrgDllFileNameEdit.Text := aDLLFileName;
  PointDllNameEdit.Text := ExtractJustName(aDLLFileName) + '_.dll';

  FuncsVST.ChildCount[nil] := fPEImage.ExportSyms.Count;
end;

procedure TMainForm.OrgDllFileNameBtnClick(Sender: TObject);
begin
  if not OpenDialog1.Execute then Exit;

  LoadDLL(OpenDialog1.FileName);
end;

procedure TMainForm.FuncsVSTGetText(Sender: TBaseVirtualTree;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType;
  var CellText: String);
begin
  if Node^.Index >= Cardinal(fPEImage.ExportSyms.Count) then Exit;

  case Column of
    0: CellText := IntToStr(Node^.Index + 1);
    1: CellText := IntToHex(fPEImage.ExportSyms.Items[Node^.Index].RVA, 8);
    2: CellText := IntToStr(fPEImage.ExportSyms.Items[Node^.Index].Ordinal);
    3: CellText := fPEImage.ExportSyms.Items[Node^.Index].Name;
  end;
end;

procedure TMainForm.Label3Click(Sender: TObject);
//var
  //URL: String;
begin
  //URL:= 'http://oranke.tistory.com';
  //ShellExecute(0, 'open', PChar(URL), nil, nil, SW_SHOWNORMAL);
  OpenURL('http://oranke.tistory.com');
end;

procedure TMainForm.Label3MouseEnter(Sender: TObject);
begin
  TLabel(Sender).Font.Style := TLabel(Sender).Font.Style + [fsUnderline];
  TLabel(Sender).Font.Color := clBlue;
end;

procedure TMainForm.Label3MouseLeave(Sender: TObject);
begin
  TLabel(Sender).Font.Style := TLabel(Sender).Font.Style - [fsUnderline];
  TLabel(Sender).Font.Color := clDefault;
end;

procedure TMainForm.CodeGenButtonClick(Sender: TObject);
var
  LibName: String;

  i: Integer;

  MainCodeList,
  FuncCodeList,
  ProxyCodeList,
  ExportCodeList: TStringList;

  LineEndStr: String;
begin
  if not FileExists(OrgDllFileNameEdit.Text) then
  begin
    MessageDlg('Check original dll file first', mtError, [mbOK], 0);
    Exit;
  end;

  if Length(PointDllNameEdit.Text) = 0 then
  begin
    MessageDlg('Point dll name is Empty', mtError, [mbOK], 0);
    Exit;
  end;

  if fPEImage.ExportSyms.Count = 0 then
  begin
    MessageDlg('There''re no functions to generate', mtError, [mbOK], 0);
    Exit;
  end;

  LibName:= ExtractJustName(OrgDllFileNameEdit.Text);

  SaveDialog1.FileName := LibName + '.dpr';
  if not SaveDialog1.Execute then Exit;

  LibName:= ExtractJustName(SaveDialog1.FileName);

  MainCodeList := TStringList.Create;
  FuncCodeList := TStringList.Create;
  ProxyCodeList:= TStringList.Create;
  ExportCodeList:= TStringList.Create;
  try
    LineEndStr:= ',';

    for i := 0 to fPEImage.ExportSyms.Count-1 do
    with fPEImage.ExportSyms.Items[i] do
    begin
      FuncCodeList.Add(
        Format(
          '      OrgFuncs.Arr[%d] :=  GetProcAddress(hl, ''%s'');',
          [i, Name]
        )
      );

      ProxyCodeList.Add(
        Format(
          '// %s'#13#10 +
          'procedure __E__%d__();'#13#10 +
          'asm'#13#10 +
          '  jmp [OrgFuncs.Base + SIZE_OF_FUNC * %d]'#13#10 +
          'end;'#13#10#13#10
          ,
          [Name, i, i]
        )
      );

      if i = fPEImage.ExportSyms.Count-1 then LineEndStr := ';';

      ExportCodeList.Add(
        Format(
          '  __E__%d__ index %u name ''%s''%s',
          [i, Ordinal, Name, LineEndStr]
        )
      );
    end;


    MainCodeList.Text :=
      Format(
        CodeMemo.Text,
        [
          LibName,
          fPEImage.ExportSyms.Count-1,
          PointDllNameEdit.Text,
          FuncCodeList.Text,
          ProxyCodeList.Text,
          ExportCodeList.Text

        ]


      );


    //MainCodeList.WriteBOM := false;
    MainCodeList.SaveToFile(SaveDialog1.FileName);//, TEncoding.UTF8);

    MessageDlg(
      Format(
      'Code generated!'+#13+#10+''+#13+#10+
      '1. Rename "%s" to "%s"'+#13+#10+
      '2. Build "%s"'+#13+#10+
      '3. and Rock''n ROLL!',
      [
        ExtractFileName(OrgDllFileNameEdit.Text),
        PointDllNameEdit.Text,
        ExtractFileName(SaveDialog1.FileName)
      ]),
      mtInformation, [mbOK], 0
    );
  finally
    MainCodeList.Free;
    FuncCodeList.Free;
    ProxyCodeList.Free;
    ExportCodeList.Free;
  end;
end;

procedure TMainForm.FormDropFiles(Sender: TObject;
  const FileNames: array of String);
begin
  if Length(FileNames) = 0 then Exit;
  //ShowMessage(UpperCase(ExtractFileExt(FileNames[0])));
  if UpperCase(ExtractFileExt(FileNames[0])) <> '.DLL' then Exit;

  LoadDLL(FileNames[0]);
end;

end.

