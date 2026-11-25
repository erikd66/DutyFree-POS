unit uAdmin;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLite3Conn, SQLDB, Forms, Controls, Graphics, Dialogs,
  StdCtrls;

type

  { TForm2 }

  TForm2 = class(TForm)
    btnOsvjezi: TButton;
    btnOdjava: TButton;
    btnArtikli: TButton;
    btnZalihe: TButton;
    btnLetoviPutnici: TButton;
    btnDFC: TButton;
    btnRacuni: TButton;
    lblNaslovAdmin: TLabel;
    lblUkupnoPutnika: TLabel;
    lblUkupnoLetova: TLabel;
    lblUkupnoArtikala: TLabel;
    lblNiskeZaliheAdmin: TLabel;
    lblOpisAdmin: TLabel;
    SQLite3ConnectionAdmin: TSQLite3Connection;
    SQLQueryAdmin: TSQLQuery;
    SQLTransactionAdmin: TSQLTransaction;
    procedure btnArtikliClick(Sender: TObject);
    procedure btnDFCClick(Sender: TObject);
    procedure btnLetoviPutniciClick(Sender: TObject);
    procedure btnOdjavaClick(Sender: TObject);
    procedure btnOsvjeziClick(Sender: TObject);
    procedure btnRacuniClick(Sender: TObject);
    procedure btnZaliheClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private

  public
    procedure UcitajPregled(const PutanjaBaze: string);
  end;

var
  Form2: TForm2;

implementation

uses
  uArtikli, uZalihe, uLetoviiPutnici, uDFC, uRacuni;

{$R *.lfm}


procedure TForm2.UcitajPregled(const PutanjaBaze: string);
begin
  SQLite3ConnectionAdmin.DatabaseName := PutanjaBaze;

  try
    if not FileExists(PutanjaBaze) then
      raise Exception.Create('Baza nije pronadjena!');

    if not SQLite3ConnectionAdmin.Connected then
      SQLite3ConnectionAdmin.Open;

    SQLQueryAdmin.Close;

    SQLQueryAdmin.SQL.Text :=
      'SELECT ' +
      '(SELECT COUNT(*) FROM putnici) AS broj_putnika, ' +
      '(SELECT COUNT(*) FROM letovi) AS broj_letova, ' +
      '(SELECT COUNT(*) FROM artikli WHERE aktivan = 1) ' +
      'AS broj_artikala, ' +
      '(SELECT COUNT(*) FROM v_niske_zalihe) ' +
      'AS broj_niskih_zaliha';

    SQLQueryAdmin.Open;

    lblUkupnoPutnika.Caption :=
      'Putnici: ' +
      SQLQueryAdmin.FieldByName('broj_putnika').AsString;

    lblUkupnoLetova.Caption :=
      'Letovi: ' +
      SQLQueryAdmin.FieldByName('broj_letova').AsString;

    lblUkupnoArtikala.Caption :=
      'Aktivni artikli: ' +
      SQLQueryAdmin.FieldByName('broj_artikala').AsString;

    lblNiskeZaliheAdmin.Caption :=
      'Niske zalihe: ' +
      SQLQueryAdmin.FieldByName('broj_niskih_zaliha').AsString;

  finally
    SQLQueryAdmin.Close;

    if SQLTransactionAdmin.Active then
      SQLTransactionAdmin.Rollback;

    if SQLite3ConnectionAdmin.Connected then
      SQLite3ConnectionAdmin.Close;
  end;
end;


{ TForm2 }

procedure TForm2.FormCreate(Sender: TObject);
begin

end;

procedure TForm2.btnOsvjeziClick(Sender: TObject);
begin
  try
    UcitajPregled(SQLite3ConnectionAdmin.DatabaseName);
  except
    on E: Exception do
      ShowMessage('Greska pri osvjezavanju: ' + E.Message);
  end;
end;

procedure TForm2.btnRacuniClick(Sender: TObject);
var
  ProzorRacuni: TForm7;
begin
  ProzorRacuni := TForm7.Create(Self);

  try
    try
      ProzorRacuni.UcitajRacune(
        SQLite3ConnectionAdmin.DatabaseName
      );

      ProzorRacuni.ShowModal;
    except
      on E: Exception do
        ShowMessage(
          'Greska pri otvaranju racuna: ' + E.Message
        );
    end;
  finally
    ProzorRacuni.Free;
  end;
end;

procedure TForm2.btnZaliheClick(Sender: TObject);
var
  ProzorZalihe: TForm4;
begin
  try
    ProzorZalihe := TForm4.Create(Self);

    try
      ProzorZalihe.UcitajZalihe(
        SQLite3ConnectionAdmin.DatabaseName
      );

      ProzorZalihe.ShowModal;
    finally
      ProzorZalihe.Free;
    end;

  except
    on E: Exception do
      ShowMessage('Greska pri otvaranju zaliha: ' +
        E.Message);
  end;
end;

procedure TForm2.btnOdjavaClick(Sender: TObject);
begin
  Close;
end;

procedure TForm2.btnArtikliClick(Sender: TObject);
var
  ProzorArtikli: TForm3;
  begin
    ProzorArtikli := TForm3.Create(Self);

    try
      try
        ProzorArtikli.UcitajArtikle(
          SQLite3ConnectionAdmin.DatabaseName
        );

        ProzorArtikli.ShowModal;

      except
        on E: Exception do
          ShowMessage(
            'Greska pri otvaranju artikala: ' +
            E.Message
          );
      end;

    finally
      ProzorArtikli.Free;
    end;
end;

procedure TForm2.btnDFCClick(Sender: TObject);
var
  ProzorDFC: TForm6;
begin
  ProzorDFC := TForm6.Create(Self);

  try
    ProzorDFC.UcitajDFC(
      SQLite3ConnectionAdmin.DatabaseName
    );

    ProzorDFC.ShowModal;

  finally
    ProzorDFC.Free;
  end;
end;

procedure TForm2.btnLetoviPutniciClick(Sender: TObject);
var
  ProzorLP: TForm5;
begin
  ProzorLP := TForm5.Create(Self);

  try
    ProzorLP.UcitajLetovePutnike(
      SQLite3ConnectionAdmin.DatabaseName
    );

    ProzorLP.ShowModal;

  finally
    ProzorLP.Free;
  end;
end;

end.

