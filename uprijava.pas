unit uPrijava;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SQLite3Conn, SQLDB, Forms, Controls, Graphics, Dialogs,
  StdCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnPrijava: TButton;
    btnProvjeriBazu: TButton;
    edtLozinka: TEdit;
    edtKorisnik: TEdit;
    lblStatusBaze: TLabel;
    lblLozinka: TLabel;
    lblPrijava: TLabel;
    lblKorisnik: TLabel;
    lblNaslov: TLabel;
    SQLite3Connection1: TSQLite3Connection;
    SQLQuery1: TSQLQuery;
    SQLTransaction1: TSQLTransaction;
    procedure btnPrijavaClick(Sender: TObject);
    procedure btnProvjeriBazuClick(Sender: TObject);
    procedure lblNaslovClick(Sender: TObject);
  private

  public

  end;

var
  Form1: TForm1;

implementation

uses
  uAdmin;

{$R *.lfm}

{ TForm1 }

procedure TForm1.lblNaslovClick(Sender: TObject);
begin

end;

procedure TForm1.btnProvjeriBazuClick(Sender: TObject);
var
  BrojTablica: Integer;
  NiskeZalihe: Integer;
begin
  lblStatusBaze.Caption := 'Provjeravam bazu...';

  try
    { 1. Provjera datoteke }
    if not FileExists(SQLite3Connection1.DatabaseName) then
      raise Exception.Create(
        'SQLite baza nije pronadjena!'
      );

    { 2. Otvaranje veze }
    if not SQLite3Connection1.Connected then
      SQLite3Connection1.Open;

    { 3. Brojanje tablica }
    SQLQuery1.Close;
    SQLQuery1.SQL.Text :=
      'SELECT COUNT(*) AS broj ' +
      'FROM sqlite_master ' +
      'WHERE type = ''table'' ' +
      'AND name NOT LIKE ''sqlite_%''';

    SQLQuery1.Open;

    BrojTablica :=
      SQLQuery1.FieldByName('broj').AsInteger;

    SQLQuery1.Close;

    { 4. Provjera niskih zaliha }
    SQLQuery1.SQL.Text :=
      'SELECT COUNT(*) AS broj ' +
      'FROM v_niske_zalihe';

    SQLQuery1.Open;

    NiskeZalihe :=
      SQLQuery1.FieldByName('broj').AsInteger;

    { 5. Prikaz rezultata }
    lblStatusBaze.Caption :=
      Format('Baza povezana! Tablice: %d, ' +
      'Niske zalihe: %d',
      [BrojTablica, NiskeZalihe]);

  except
    on E: Exception do
      lblStatusBaze.Caption :=
        'GRESKA: ' + E.Message;
  end;

  { Zatvaranje upita i transakcije }
  if SQLQuery1.Active then
    SQLQuery1.Close;

  if SQLTransaction1.Active then
    SQLTransaction1.Rollback;

  if SQLite3Connection1.Connected then
    SQLite3Connection1.Close;
end;

procedure TForm1.btnPrijavaClick(Sender: TObject);
var
  UspjesnaPrijava: Boolean;
  AdminProzor: TForm2;
begin
  if (Trim(edtKorisnik.Text) = '') or
     (edtLozinka.Text = '') then
  begin
    ShowMessage('Unesi korisnicko ime i lozinku!');
    Exit;
  end;

  try
    if not FileExists(SQLite3Connection1.DatabaseName) then
      raise Exception.Create('Baza podataka nije pronadjena!');

    if not SQLite3Connection1.Connected then
      SQLite3Connection1.Open;

    try
      SQLQuery1.Close;

      SQLQuery1.SQL.Text :=
        'SELECT admin_id FROM administratori ' +
        'WHERE korisnicko_ime = :korisnik ' +
        'AND lozinka = :lozinka ' +
        'AND aktivan = 1';

      SQLQuery1.ParamByName('korisnik').AsString :=
        Trim(edtKorisnik.Text);

      SQLQuery1.ParamByName('lozinka').AsString :=
        edtLozinka.Text;

      SQLQuery1.Open;

      UspjesnaPrijava := not SQLQuery1.IsEmpty;

    finally
      SQLQuery1.Close;

      if SQLTransaction1.Active then
        SQLTransaction1.Rollback;

      if SQLite3Connection1.Connected then
        SQLite3Connection1.Close;
    end;

    if UspjesnaPrijava then
    begin
    edtLozinka.Clear;

    AdminProzor := TForm2.Create(Self);

    try
       AdminProzor.UcitajPregled(
       SQLite3Connection1.DatabaseName
       );

       Hide;

    try
      AdminProzor.ShowModal;
    finally
      Show;
    end;

  finally
    AdminProzor.Free;
  end;
end

    else
    begin
      ShowMessage('Pogresno korisnicko ime ili lozinka!');
      edtLozinka.Clear;
      edtLozinka.SetFocus;
    end;

  except
    on E: Exception do
      ShowMessage('Greska: ' + E.Message);
    end;
  end;
end.

