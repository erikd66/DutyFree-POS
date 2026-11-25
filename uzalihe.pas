unit uZalihe;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, DB, SQLite3Conn, Forms, Controls, Graphics, Dialogs,
  StdCtrls, DBGrids;

type

  { TForm4 }

  TForm4 = class(TForm)
    btnOsvjeziZalihe: TButton;
    btnZatvoriZalihe: TButton;
    btnNaruciRobu: TButton;
    btnZaprimiNarudzbu: TButton;
    DataSourceZalihe: TDataSource;
    DBGridZalihe: TDBGrid;
    lblNaslovZalihe: TLabel;
    SQLite3ConnectionZalihe: TSQLite3Connection;
    SQLQueryZalihe: TSQLQuery;
    SQLTransactionZalihe: TSQLTransaction;
    procedure btnNaruciRobuClick(Sender: TObject);
    procedure btnOsvjeziZaliheClick(Sender: TObject);
    procedure btnZaprimiNarudzbuClick(Sender: TObject);
    procedure btnZatvoriZaliheClick(Sender: TObject);
  private

  public
   procedure UcitajZalihe(const PutanjaBaze: string);
  end;

var
  Form4: TForm4;

implementation

{$R *.lfm}

procedure TForm4.btnOsvjeziZaliheClick(Sender: TObject);
begin
  try
    UcitajZalihe(
      SQLite3ConnectionZalihe.DatabaseName
    );
  except
    on E: Exception do
      ShowMessage('Greska: ' + E.Message);
  end;
end;

procedure TForm4.btnZaprimiNarudzbuClick(Sender: TObject);
var
  Oznaka: string;
  NarudzbaID, BrojStavki: Integer;
  Q: TSQLQuery;
begin
  Oznaka := '';

  if not InputQuery(
    'Zaprimi narudzbu',
    'Unesi oznaku narudzbe:',
    Oznaka
  ) then
    Exit;

  Oznaka := UpperCase(Trim(Oznaka));

  if Oznaka = '' then
  begin
    ShowMessage('Oznaka je obavezna!');
    Exit;
  end;

  try
    SQLQueryZalihe.Close;

    if SQLTransactionZalihe.Active then
      SQLTransactionZalihe.Rollback;

    SQLTransactionZalihe.StartTransaction;

    Q := TSQLQuery.Create(nil);
    try
      Q.Database := SQLite3ConnectionZalihe;
      Q.Transaction := SQLTransactionZalihe;

      { Pronalazak narudzbe koja ceka zaprimanje }
      Q.SQL.Text :=
        'SELECT narudzba_id FROM narudzbe ' +
        'WHERE oznaka = :oznaka AND status = ''NARUCENO''';

      Q.ParamByName('oznaka').AsString := Oznaka;
      Q.Open;

      if Q.IsEmpty then
        raise Exception.Create(
          'Narudzba ne postoji ili je vec obradjena.'
        );

      NarudzbaID :=
        Q.FieldByName('narudzba_id').AsInteger;

      Q.Close;

      { Broj stavki narudzbe }
      Q.SQL.Text :=
        'SELECT COUNT(*) AS broj FROM stavke_narudzbe ' +
        'WHERE narudzba_id = :id';

      Q.ParamByName('id').AsInteger := NarudzbaID;
      Q.Open;

      BrojStavki := Q.FieldByName('broj').AsInteger;
      Q.Close;

      if BrojStavki = 0 then
        raise Exception.Create('Narudzba nema stavki.');

      { Povecavanje zaliha svih stavki narudzbe }
      Q.SQL.Text :=
        'UPDATE zalihe SET kolicina = kolicina + ' +
        '(SELECT s.kolicina FROM stavke_narudzbe s ' +
        'WHERE s.narudzba_id = :id1 ' +
        'AND s.artikl_id = zalihe.artikl_id) ' +
        'WHERE artikl_id IN ' +
        '(SELECT artikl_id FROM stavke_narudzbe ' +
        'WHERE narudzba_id = :id2)';

      Q.ParamByName('id1').AsInteger := NarudzbaID;
      Q.ParamByName('id2').AsInteger := NarudzbaID;

      Q.ExecSQL;

      if Q.RowsAffected <> BrojStavki then
        raise Exception.Create(
          'Nedostaje zapis zaliha za neki artikl.'
        );

      { Promjena statusa narudzbe }
      Q.SQL.Text :=
        'UPDATE narudzbe SET ' +
        'status = ''ZAPRIMLJENO'', ' +
        'datum_zaprimanja = datetime(''now'') ' +
        'WHERE narudzba_id = :id ' +
        'AND status = ''NARUCENO''';

      Q.ParamByName('id').AsInteger := NarudzbaID;

      Q.ExecSQL;

      if Q.RowsAffected <> 1 then
        raise Exception.Create(
          'Narudzba se ne moze zaprimiti.'
        );

    finally
      Q.Free;
    end;

    SQLTransactionZalihe.Commit;

    ShowMessage(
      'Narudzba ' + Oznaka +
      ' je uspjesno zaprimljena!'
    );

  except
    on E: Exception do
    begin
      if SQLTransactionZalihe.Active then
        SQLTransactionZalihe.Rollback;

      ShowMessage('Greska: ' + E.Message);
    end;
  end;

  try
    UcitajZalihe(SQLite3ConnectionZalihe.DatabaseName);
  except
    on E: Exception do
      ShowMessage('Greska pri osvjezavanju: ' + E.Message);
  end;
end;

procedure TForm4.btnNaruciRobuClick(Sender: TObject);
var
  ArtiklID, Kolicina, NarudzbaID: Integer;
  Unos, Sifra, Oznaka: string;
  Q: TSQLQuery;
begin
  if not SQLQueryZalihe.Active then Exit;

  if SQLQueryZalihe.IsEmpty then
  begin
    ShowMessage('Prvo odaberi artikl!');
    Exit;
  end;

  ArtiklID := SQLQueryZalihe.FieldByName('ID').AsInteger;
  Sifra := SQLQueryZalihe.FieldByName('Sifra').AsString;

  Unos := '20';

  if not InputQuery(
    'Naruci robu',
    'Artikl: ' + Sifra + ' - koliko komada narucujes?',
    Unos
  ) then
    Exit;

  if not TryStrToInt(Trim(Unos), Kolicina) then
  begin
    ShowMessage('Unesi cijeli broj!');
    Exit;
  end;

  if Kolicina <= 0 then
  begin
    ShowMessage('Kolicina mora biti veca od nule!');
    Exit;
  end;

  try
    SQLQueryZalihe.Close;

    if SQLTransactionZalihe.Active then
      SQLTransactionZalihe.Rollback;

    SQLTransactionZalihe.StartTransaction;

    Q := TSQLQuery.Create(nil);
    try
      Q.Database := SQLite3ConnectionZalihe;
      Q.Transaction := SQLTransactionZalihe;

      { Stvaranje narudzbe }
      Q.SQL.Text :=
        'INSERT INTO narudzbe ' +
        '(oznaka, admin_id, status) ' +
        'SELECT ''NAR-'' || upper(hex(randomblob(5))), ' +
        'admin_id, ''NARUCENO'' ' +
        'FROM administratori ' +
        'WHERE aktivan = 1 ' +
        'ORDER BY admin_id LIMIT 1';

      Q.ExecSQL;

      if Q.RowsAffected <> 1 then
        raise Exception.Create(
          'Nije pronadjen aktivan administrator.'
        );

      { Dohvat ID-a i oznake nove narudzbe }
      Q.SQL.Text :=
        'SELECT narudzba_id, oznaka FROM narudzbe ' +
        'WHERE narudzba_id = last_insert_rowid()';

      Q.Open;

      NarudzbaID :=
        Q.FieldByName('narudzba_id').AsInteger;

      Oznaka :=
        Q.FieldByName('oznaka').AsString;

      Q.Close;

      { Dodavanje artikla u narudzbu }
      Q.SQL.Text :=
        'INSERT INTO stavke_narudzbe ' +
        '(narudzba_id, artikl_id, kolicina) ' +
        'VALUES (:narudzba, :artikl, :kolicina)';

      Q.ParamByName('narudzba').AsInteger := NarudzbaID;
      Q.ParamByName('artikl').AsInteger := ArtiklID;
      Q.ParamByName('kolicina').AsInteger := Kolicina;

      Q.ExecSQL;

    finally
      Q.Free;
    end;

    SQLTransactionZalihe.Commit;

    ShowMessage(
      'Narudzba je kreirana!' + LineEnding +
      'Oznaka: ' + Oznaka + LineEnding +
      'Kolicina: ' + IntToStr(Kolicina) +
      LineEnding + 'Status: NARUCENO'
    );

  except
    on E: Exception do
    begin
      if SQLTransactionZalihe.Active then
        SQLTransactionZalihe.Rollback;

      ShowMessage('Greska: ' + E.Message);
    end;
  end;

  { Ponovno ucitaj zalihe nakon narucivanja }
  try
    UcitajZalihe(SQLite3ConnectionZalihe.DatabaseName);
  except
    on E: Exception do
      ShowMessage('Greska pri osvjezavanju: ' + E.Message);
  end;
end;

procedure TForm4.btnZatvoriZaliheClick(Sender: TObject);
begin
  SQLQueryZalihe.Close;

  if SQLTransactionZalihe.Active then
    SQLTransactionZalihe.Rollback;

  if SQLite3ConnectionZalihe.Connected then
    SQLite3ConnectionZalihe.Close;

  Close;
end;

procedure TForm4.UcitajZalihe(const PutanjaBaze: string);
begin
  if not FileExists(PutanjaBaze) then
    raise Exception.Create('SQLite baza nije pronadjena!');

  SQLQueryZalihe.Close;

  if SQLTransactionZalihe.Active then
    SQLTransactionZalihe.Rollback;

  SQLite3ConnectionZalihe.DatabaseName := PutanjaBaze;

  if not SQLite3ConnectionZalihe.Connected then
    SQLite3ConnectionZalihe.Open;

  SQLQueryZalihe.SQL.Text :=
    'SELECT ' +
    'a.artikl_id AS ID, ' +
    'a.sifra AS Sifra, ' +
    'a.naziv AS Artikl, ' +
    'COALESCE(z.kolicina, 0) AS Kolicina, ' +
    'COALESCE(z.minimalna_kolicina, 0) AS Minimum, ' +
    'CASE ' +
    'WHEN z.artikl_id IS NULL THEN ''NEMA ZAPISE'' ' +
    'WHEN z.kolicina <= z.minimalna_kolicina ' +
    'THEN ''NISKA ZALIHA'' ' +
    'ELSE ''OK'' END AS Status ' +
    'FROM artikli a ' +
    'LEFT JOIN zalihe z ON a.artikl_id = z.artikl_id ' +
    'WHERE a.aktivan = 1 ' +
    'ORDER BY ' +
    'CASE WHEN z.artikl_id IS NULL OR ' +
    'z.kolicina <= z.minimalna_kolicina ' +
    'THEN 0 ELSE 1 END, a.naziv';

  SQLQueryZalihe.Open;
end;

end.

