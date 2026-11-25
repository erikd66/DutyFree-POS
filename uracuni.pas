unit uRacuni;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLite3Conn, SQLDB, DB, Forms, Controls, Graphics, Dialogs,
  StdCtrls, DBGrids;

type

  { TForm7 }

  TForm7 = class(TForm)
    btnPrikaziStavke: TButton;
    btnOsvjeziRacune: TButton;
    btnZatvoriRacune: TButton;
    DataSourceRacuni: TDataSource;
    DataSourceStavke: TDataSource;
    DBGridRacuni: TDBGrid;
    DBGridStavke: TDBGrid;
    lblNaslovRacuni: TLabel;
    lblBrojRacuna: TLabel;
    lblUkupnaProdaja: TLabel;
    lblUkupnoPDV: TLabel;
    lblProdajaEU: TLabel;
    lblProdajaIzvanEU: TLabel;
    lblNaslovStavke: TLabel;
    SQLite3ConnectionRacuni: TSQLite3Connection;
    SQLQueryRacuni: TSQLQuery;
    SQLQueryStavke: TSQLQuery;
    SQLTransactionRacuni: TSQLTransaction;
    procedure btnOsvjeziRacuneClick(Sender: TObject);
    procedure btnPrikaziStavkeClick(Sender: TObject);
    procedure btnZatvoriRacuneClick(Sender: TObject);
  private

  public
    procedure UcitajRacune(const PutanjaBaze: string);
    procedure UcitajStavke;
  end;

var
  Form7: TForm7;

implementation

{$R *.lfm}

function CentiUDFC(IznosCenti: Int64): string;
begin
  Result :=
    FormatFloat('0.00', IznosCenti / 100.0) +
    ' DFC';
end;

procedure TForm7.UcitajStavke;
var
  RacunID: Integer;
begin
  RacunID := 0;

  if SQLQueryRacuni.Active then
  begin
    if not SQLQueryRacuni.IsEmpty then
      RacunID :=
        SQLQueryRacuni.FieldByName('ID').AsInteger;
  end;

  SQLQueryStavke.Close;

  SQLQueryStavke.SQL.Text :=
    'SELECT ' +
    's.pozicija AS Pozicija, ' +
    's.sifra_artikla AS Sifra, ' +
    's.naziv_artikla AS Artikl, ' +
    's.kolicina AS Kolicina, ' +
    'printf(''%.2f'', ' +
    's.jedinicna_neto_centi / 100.0) ' +
    'AS Neto_po_komadu_DFC, ' +
    's.primijenjeni_pdv_postotak AS PDV_posto, ' +
    'printf(''%.2f'', ' +
    's.jedinicna_ukupno_centi / 100.0) ' +
    'AS Cijena_po_komadu_DFC, ' +
    'printf(''%.2f'', ' +
    's.ukupno_stavke_centi / 100.0) ' +
    'AS Ukupno_stavke_DFC ' +
    'FROM stavke_racuna s ' +
    'WHERE s.racun_id = :racun_id ' +
    'ORDER BY s.pozicija';

  SQLQueryStavke.ParamByName('racun_id').AsInteger :=
    RacunID;

  SQLQueryStavke.Open;
end;

procedure TForm7.btnPrikaziStavkeClick(Sender: TObject);
begin
  try
    UcitajStavke;
  except
    on E: Exception do
      ShowMessage(
        'Greska pri ucitavanju stavki: ' + E.Message
      );
  end;
end;

procedure TForm7.btnZatvoriRacuneClick(Sender: TObject);
begin
  SQLQueryStavke.Close;
  SQLQueryRacuni.Close;

  if SQLTransactionRacuni.Active then
    SQLTransactionRacuni.Rollback;

  if SQLite3ConnectionRacuni.Connected then
    SQLite3ConnectionRacuni.Close;

  Close;
end;

procedure TForm7.btnOsvjeziRacuneClick(Sender: TObject);
begin
  try
    UcitajRacune(
      SQLite3ConnectionRacuni.DatabaseName
    );
  except
    on E: Exception do
      ShowMessage('Greska: ' + E.Message);
  end;
end;

procedure TForm7.UcitajRacune(
  const PutanjaBaze: string);
var
  Q: TSQLQuery;
begin
  if not FileExists(PutanjaBaze) then
    raise Exception.Create('SQLite baza nije pronadjena!');

  SQLQueryStavke.Close;
  SQLQueryRacuni.Close;

  if SQLTransactionRacuni.Active then
    SQLTransactionRacuni.Rollback;

  SQLite3ConnectionRacuni.DatabaseName := PutanjaBaze;

  if not SQLite3ConnectionRacuni.Connected then
    SQLite3ConnectionRacuni.Open;

  { 1. POPIS RACUNA }
  SQLQueryRacuni.SQL.Text :=
    'SELECT ' +
    'r.racun_id AS ID, ' +
    'r.broj_racuna AS Broj_racuna, ' +
    'r.datum_izdavanja AS Datum, ' +
    'p.ime || '' '' || p.prezime AS Putnik, ' +
    'l.broj_leta AS Let, ' +
    'r.porezni_rezim AS Rezim, ' +
    'printf(''%.2f'', r.iznos_neto_centi / 100.0) ' +
    'AS Neto_DFC, ' +
    'printf(''%.2f'', r.iznos_pdv_centi / 100.0) ' +
    'AS PDV_DFC, ' +
    'printf(''%.2f'', r.ukupno_centi / 100.0) ' +
    'AS Ukupno_DFC ' +
    'FROM racuni r ' +
    'JOIN avionske_karte ak ON ak.karta_id = r.karta_id ' +
    'JOIN putnici p ON p.putnik_id = ak.putnik_id ' +
    'JOIN letovi l ON l.let_id = ak.let_id ' +
    'ORDER BY r.datum_izdavanja DESC, r.racun_id DESC';

  SQLQueryRacuni.Open;

  { 2. STAVKE PRVOG RACUNA }
  UcitajStavke;

  { 3. STATISTIKA PRODAJE }
  Q := TSQLQuery.Create(nil);
  try
    Q.Database := SQLite3ConnectionRacuni;
    Q.Transaction := SQLTransactionRacuni;

    Q.SQL.Text :=
      'SELECT ' +
      'COUNT(*) AS broj, ' +
      'COALESCE(SUM(ukupno_centi), 0) AS ukupno, ' +
      'COALESCE(SUM(iznos_pdv_centi), 0) AS pdv, ' +
      'COALESCE(SUM(CASE WHEN porezni_rezim = ''EU'' ' +
      'THEN ukupno_centi ELSE 0 END), 0) AS eu, ' +
      'COALESCE(SUM(CASE WHEN ' +
      'porezni_rezim = ''IZVAN_EU'' ' +
      'THEN ukupno_centi ELSE 0 END), 0) AS izvan_eu ' +
      'FROM racuni';

    Q.Open;

    lblBrojRacuna.Caption :=
      'Broj racuna: ' +
      Q.FieldByName('broj').AsString;

    lblUkupnaProdaja.Caption :=
      'Ukupna prodaja: ' +
      CentiUDFC(Q.FieldByName('ukupno').AsLargeInt);

    lblUkupnoPDV.Caption :=
      'Ukupni PDV: ' +
      CentiUDFC(Q.FieldByName('pdv').AsLargeInt);

    lblProdajaEU.Caption :=
      'Prodaja EU: ' +
      CentiUDFC(Q.FieldByName('eu').AsLargeInt);

    lblProdajaIzvanEU.Caption :=
      'Prodaja izvan EU: ' +
      CentiUDFC(Q.FieldByName('izvan_eu').AsLargeInt);

    Q.Close;
  finally
    Q.Free;
  end;
end;

end.

