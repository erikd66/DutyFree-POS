unit uLetoviiPutnici;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, DB, SQLDB, SQLite3Conn, Forms, Controls, Graphics, Dialogs,
  StdCtrls, DBGrids;

type

  { TForm5 }

  TForm5 = class(TForm)
    btnDodajLet: TButton;
    btnDodajPutnika: TButton;
    btnIzdajKartu: TButton;
    btnOsvjeziLP: TButton;
    btnZatvoriLP: TButton;
    DataSourceLetovi: TDataSource;
    DataSourcePutnici: TDataSource;
    DBGridLetovi: TDBGrid;
    DBGridPutnici: TDBGrid;
    lblNaslovLetovi: TLabel;
    lblNaslovPutnici: TLabel;
    SQLite3ConnectionLP: TSQLite3Connection;
    SQLQueryLetovi: TSQLQuery;
    SQLQueryPutnici: TSQLQuery;
    SQLTransactionLP: TSQLTransaction;
    procedure btnDodajLetClick(Sender: TObject);
    procedure btnDodajPutnikaClick(Sender: TObject);
    procedure btnIzdajKartuClick(Sender: TObject);
    procedure btnOsvjeziLPClick(Sender: TObject);
    procedure btnZatvoriLPClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private

  public
    procedure UcitajLetovePutnike(const PutanjaBaze: string);
  end;

var
  Form5: TForm5;

implementation

{$R *.lfm}

 
procedure TForm5.UcitajLetovePutnike(
  const PutanjaBaze: string);
begin
  if not FileExists(PutanjaBaze) then
    raise Exception.Create('SQLite baza nije pronadjena!');

  SQLQueryLetovi.Close;
  SQLQueryPutnici.Close;

  if SQLTransactionLP.Active then
    SQLTransactionLP.Rollback;

  SQLite3ConnectionLP.DatabaseName := PutanjaBaze;

  if not SQLite3ConnectionLP.Connected then
    SQLite3ConnectionLP.Open;

  { LETOVI }
  SQLQueryLetovi.SQL.Text :=
    'SELECT ' +
    'l.let_id AS ID, ' +
    'l.broj_leta AS Let, ' +
    'l.polaziste AS Polaziste, ' +
    'l.odrediste AS Odrediste, ' +
    'd.naziv AS Drzava, ' +
    'l.datum_polaska AS Datum, ' +
    'l.vrijeme_polaska AS Vrijeme, ' +
    'CASE WHEN d.je_eu = 1 THEN ''EU'' ' +
    'ELSE ''IZVAN EU'' END AS Rezim ' +
    'FROM letovi l ' +
    'JOIN drzave d ON d.sifra = l.drzava_odredista ' +
    'ORDER BY l.datum_polaska DESC, l.vrijeme_polaska';

  SQLQueryLetovi.Open;

  { PUTNICI I NJIHOVE AKTIVNE KARTE }
  SQLQueryPutnici.SQL.Text :=
    'SELECT ' +
    'p.putnik_id AS ID, ' +
    'p.ime AS Ime, ' +
    'p.prezime AS Prezime, ' +
    'COALESCE((SELECT group_concat(' +
    'l.broj_leta || '' ['' || ak.barkod || '']'', '', '') ' +
    'FROM avionske_karte ak ' +
    'JOIN letovi l ON l.let_id = ak.let_id ' +
    'WHERE ak.putnik_id = p.putnik_id ' +
    'AND ak.status = ''AKTIVNA''), ' +
    '''Nema dodijeljenog leta'') AS Karte ' +
    'FROM putnici p ' +
    'ORDER BY p.prezime, p.ime';

  SQLQueryPutnici.Open;
end;


{ TForm5 }

procedure TForm5.FormCreate(Sender: TObject);
begin

end;

procedure TForm5.btnDodajPutnikaClick(Sender: TObject);
var
  P: array[0..1] of string;
  Q: TSQLQuery;
begin
  P[0] := '';
  P[1] := '';

  if not InputQuery(
    'Dodaj putnika',
    ['Ime', 'Prezime'],
    P
  ) then Exit;

  if (Trim(P[0]) = '') or (Trim(P[1]) = '') then
  begin
    ShowMessage('Ime i prezime su obavezni!');
    Exit;
  end;

  try
    SQLQueryLetovi.Close;
    SQLQueryPutnici.Close;

    if SQLTransactionLP.Active then
      SQLTransactionLP.Rollback;

    SQLTransactionLP.StartTransaction;

    Q := TSQLQuery.Create(nil);
    try
      Q.Database := SQLite3ConnectionLP;
      Q.Transaction := SQLTransactionLP;

      Q.SQL.Text :=
        'INSERT INTO putnici (ime, prezime) ' +
        'VALUES (:ime, :prezime)';

      Q.ParamByName('ime').AsString := Trim(P[0]);
      Q.ParamByName('prezime').AsString := Trim(P[1]);

      Q.ExecSQL;
    finally
      Q.Free;
    end;

    SQLTransactionLP.Commit;

    ShowMessage('Putnik je uspjesno dodan!');

  except
    on E: Exception do
    begin
      if SQLTransactionLP.Active then
        SQLTransactionLP.Rollback;

      ShowMessage('Greska: ' + E.Message);
    end;
  end;

  UcitajLetovePutnike(SQLite3ConnectionLP.DatabaseName);
end;

procedure TForm5.btnIzdajKartuClick(Sender: TObject);
var
  PutnikID, LetID: Integer;
  Putnik, Let, Barkod: string;
  Q: TSQLQuery;
begin
  if not SQLQueryPutnici.Active or
     not SQLQueryLetovi.Active then
  begin
    ShowMessage('Prvo ucitaj podatke!');
    Exit;
  end;

  if SQLQueryPutnici.IsEmpty or SQLQueryLetovi.IsEmpty then
  begin
    ShowMessage('Odaberi putnika i let!');
    Exit;
  end;

  PutnikID := SQLQueryPutnici.FieldByName('ID').AsInteger;
  LetID := SQLQueryLetovi.FieldByName('ID').AsInteger;

  Putnik :=
    SQLQueryPutnici.FieldByName('Ime').AsString + ' ' +
    SQLQueryPutnici.FieldByName('Prezime').AsString;

  Let := SQLQueryLetovi.FieldByName('Let').AsString;

  if MessageDlg(
    'Izdati kartu?' + LineEnding +
    'Putnik: ' + Putnik + LineEnding +
    'Let: ' + Let,
    mtConfirmation,
    [mbYes, mbNo],
    0
  ) <> mrYes then Exit;

  try
    SQLQueryLetovi.Close;
    SQLQueryPutnici.Close;

    if SQLTransactionLP.Active then
      SQLTransactionLP.Rollback;

    SQLTransactionLP.StartTransaction;

    Q := TSQLQuery.Create(nil);
    try
      Q.Database := SQLite3ConnectionLP;
      Q.Transaction := SQLTransactionLP;

      { Provjera postoji li vec karta za taj let }
      Q.SQL.Text :=
        'SELECT COUNT(*) AS broj FROM avionske_karte ' +
        'WHERE putnik_id = :putnik AND let_id = :let';

      Q.ParamByName('putnik').AsInteger := PutnikID;
      Q.ParamByName('let').AsInteger := LetID;

      Q.Open;

      if Q.FieldByName('broj').AsInteger > 0 then
        raise Exception.Create(
          'Ovaj putnik vec ima kartu za odabrani let.'
        );

      Q.Close;

      { Generiranje i spremanje barkoda }
      Q.SQL.Text :=
        'INSERT INTO avionske_karte ' +
        '(barkod, putnik_id, let_id, status) ' +
        'VALUES (' +
        'printf(''%014d'', ' +
        'abs(random() % 100000000000000)), ' +
        ':putnik, :let, ''AKTIVNA'')';

      Q.ParamByName('putnik').AsInteger := PutnikID;
      Q.ParamByName('let').AsInteger := LetID;

      Q.ExecSQL;

      { Procitaj upravo kreirani barkod }
      Q.SQL.Text :=
        'SELECT barkod FROM avionske_karte ' +
        'WHERE karta_id = last_insert_rowid()';

      Q.Open;

      if Q.IsEmpty then
        raise Exception.Create('Karta nije pronadjena.');

      Barkod := Q.FieldByName('barkod').AsString;

      Q.Close;

    finally
      Q.Free;
    end;

    SQLTransactionLP.Commit;

    ShowMessage(
      'Avionska karta uspjesno izdana!' + LineEnding +
      'Putnik: ' + Putnik + LineEnding +
      'Let: ' + Let + LineEnding +
      'Barkod: ' + Barkod
    );

  except
    on E: Exception do
    begin
      if SQLTransactionLP.Active then
        SQLTransactionLP.Rollback;

      ShowMessage('Greska: ' + E.Message);
    end;
  end;

  UcitajLetovePutnike(SQLite3ConnectionLP.DatabaseName);
end;

procedure TForm5.btnOsvjeziLPClick(Sender: TObject);
begin
  try
    UcitajLetovePutnike(SQLite3ConnectionLP.DatabaseName);
  except
    on E: Exception do
      ShowMessage('Greska: ' + E.Message);
  end;
end;

procedure TForm5.btnZatvoriLPClick(Sender: TObject);
begin
  SQLQueryLetovi.Close;
  SQLQueryPutnici.Close;

  if SQLTransactionLP.Active then
    SQLTransactionLP.Rollback;

  if SQLite3ConnectionLP.Connected then
    SQLite3ConnectionLP.Close;

  Close;
end;

procedure TForm5.btnDodajLetClick(Sender: TObject);
var
  P: array[0..5] of string;
  Q: TSQLQuery;
  Godina, Mjesec, Dan, Sat, Minuta: Integer;
  ProvjeraDatuma, ProvjeraVremena: TDateTime;
begin
  P[0] := '';
  P[1] := 'ZAG';
  P[2] := '';
  P[3] := '';
  P[4] := FormatDateTime('yyyy-mm-dd', Date + 7);
  P[5] := '10:00';

  if not InputQuery(
    'Dodaj let',
    ['Broj leta',
     'Polaziste (3 slova)',
     'Odrediste (3 slova)',
     'Sifra drzave (2 slova)',
     'Datum (YYYY-MM-DD)',
     'Vrijeme (HH:MM)'],
    P
  ) then Exit;

  if (Trim(P[0]) = '') or
     (Length(Trim(P[1])) <> 3) or
     (Length(Trim(P[2])) <> 3) or
     (Length(Trim(P[3])) <> 2) then
  begin
    ShowMessage('Provjeri broj leta i oznake aerodroma/drzave!');
    Exit;
  end;

  if (Length(P[4]) <> 10) or
     (Length(P[5]) <> 5) then
  begin
    ShowMessage('Neispravan format datuma ili vremena!');
    Exit;
  end;

  if (P[4][5] <> '-') or (P[4][8] <> '-') or
     (P[5][3] <> ':') then
  begin
    ShowMessage('Koristi YYYY-MM-DD i HH:MM!');
    Exit;
  end;

  if not TryStrToInt(Copy(P[4], 1, 4), Godina) or
     not TryStrToInt(Copy(P[4], 6, 2), Mjesec) or
     not TryStrToInt(Copy(P[4], 9, 2), Dan) or
     not TryStrToInt(Copy(P[5], 1, 2), Sat) or
     not TryStrToInt(Copy(P[5], 4, 2), Minuta) then
  begin
    ShowMessage('Datum i vrijeme moraju biti brojcani!');
    Exit;
  end;

  if (Godina < 2000) or (Godina > 2100) or
     (Mjesec < 1) or (Mjesec > 12) or
     (Dan < 1) or (Dan > 31) or
     (Sat < 0) or (Sat > 23) or
     (Minuta < 0) or (Minuta > 59) then
  begin
    ShowMessage('Neispravan datum ili vrijeme!');
    Exit;
  end;

  if not TryEncodeDate(
    Word(Godina), Word(Mjesec), Word(Dan), ProvjeraDatuma
  ) then
  begin
    ShowMessage('Datum ne postoji!');
    Exit;
  end;

  if not TryEncodeTime(
    Word(Sat), Word(Minuta), 0, 0, ProvjeraVremena
  ) then
  begin
    ShowMessage('Vrijeme nije ispravno!');
    Exit;
  end;

  try
    SQLQueryLetovi.Close;
    SQLQueryPutnici.Close;

    if SQLTransactionLP.Active then
      SQLTransactionLP.Rollback;

    SQLTransactionLP.StartTransaction;

    Q := TSQLQuery.Create(nil);
    try
      Q.Database := SQLite3ConnectionLP;
      Q.Transaction := SQLTransactionLP;

      Q.SQL.Text :=
        'INSERT INTO letovi ' +
        '(broj_leta, polaziste, odrediste, ' +
        'drzava_odredista, datum_polaska, vrijeme_polaska) ' +
        'SELECT :broj, :pol, :odr, sifra, :datum, :vrijeme ' +
        'FROM drzave WHERE sifra = :drzava';

      Q.ParamByName('broj').AsString :=
        UpperCase(Trim(P[0]));
      Q.ParamByName('pol').AsString :=
        UpperCase(Trim(P[1]));
      Q.ParamByName('odr').AsString :=
        UpperCase(Trim(P[2]));
      Q.ParamByName('drzava').AsString :=
        UpperCase(Trim(P[3]));
      Q.ParamByName('datum').AsString := P[4];
      Q.ParamByName('vrijeme').AsString := P[5];

      Q.ExecSQL;

      if Q.RowsAffected <> 1 then
        raise Exception.Create(
          'Sifra drzave ne postoji u tablici drzave.'
        );

    finally
      Q.Free;
    end;

    SQLTransactionLP.Commit;

    ShowMessage('Let je uspjesno dodan!');

  except
    on E: Exception do
    begin
      if SQLTransactionLP.Active then
        SQLTransactionLP.Rollback;

      ShowMessage('Greska: ' + E.Message);
    end;
  end;

  UcitajLetovePutnike(SQLite3ConnectionLP.DatabaseName);
end;

end.

