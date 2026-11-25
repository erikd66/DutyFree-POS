unit uDFC;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, DB, SQLite3Conn, Forms, Controls, Graphics, Dialogs,
  ComCtrls, DBGrids, StdCtrls;

type

  { TForm6 }

  TForm6 = class(TForm)
    btnIzdajBon: TButton;
    btnOsvjeziDFC: TButton;
    btnZatvoriDFC: TButton;
    DataSourceNovcanici: TDataSource;
    DataSourceTransakcije: TDataSource;
    DataSourceBonovi: TDataSource;
    DBGridBonovi: TDBGrid;
    DBGridNovcanici: TDBGrid;
    DBGridTransakcije: TDBGrid;
    PageControlDFC: TPageControl;
    SQLite3ConnectionDFC: TSQLite3Connection;
    SQLQueryNovcanici: TSQLQuery;
    SQLQueryTransakcije: TSQLQuery;
    SQLQueryBonovi: TSQLQuery;
    SQLTransactionDFC: TSQLTransaction;
    tabNovcanici: TTabSheet;
    tabBonovi: TTabSheet;
    procedure btnIzdajBonClick(Sender: TObject);
    procedure btnOsvjeziDFCClick(Sender: TObject);
    procedure btnZatvoriDFCClick(Sender: TObject);
  private

  public
    procedure UcitajDFC(const PutanjaBaze: string);
  end;

var
  Form6: TForm6;

implementation

{$R *.lfm}

procedure TForm6.btnIzdajBonClick(Sender: TObject);
var
  P: array[0..1] of string;
  Iznos: Integer;
  Placanje, KodBona: string;
  Q: TSQLQuery;
begin
  P[0] := '20';
  P[1] := 'GOTOVINA';

  if not InputQuery(
    'Izdavanje DFC bona',
    ['Vrijednost bona (5, 10, 20, 50, 100, 200)',
     'Nacin placanja (GOTOVINA, KARTICA, MOBILNO)'],
    P
  ) then
    Exit;

  if not TryStrToInt(Trim(P[0]), Iznos) then
  begin
    ShowMessage('Vrijednost mora biti broj!');
    Exit;
  end;

  if not (Iznos in [5, 10, 20, 50, 100, 200]) then
  begin
    ShowMessage('Nedozvoljena vrijednost bona!');
    Exit;
  end;

  Placanje := UpperCase(Trim(P[1]));

  if (Placanje <> 'GOTOVINA') and
     (Placanje <> 'KARTICA') and
     (Placanje <> 'MOBILNO') then
  begin
    ShowMessage('Neispravan nacin placanja!');
    Exit;
  end;

  try
    SQLQueryNovcanici.Close;
    SQLQueryTransakcije.Close;
    SQLQueryBonovi.Close;

    if SQLTransactionDFC.Active then
      SQLTransactionDFC.Rollback;

    SQLTransactionDFC.StartTransaction;

    Q := TSQLQuery.Create(nil);
    try
      Q.Database := SQLite3ConnectionDFC;
      Q.Transaction := SQLTransactionDFC;

      { Kreiranje bona }
      Q.SQL.Text :=
        'INSERT INTO vauceri ' +
        '(kod, vrsta_bona_id, izdao_admin_id, ' +
        'nacin_placanja, status) ' +
        'SELECT ' +
        'printf(''%014d'', ' +
        'abs(random() % 100000000000000)), ' +
        'vb.vrsta_bona_id, a.admin_id, ' +
        ':placanje, ''NEISKORISTEN'' ' +
        'FROM vrste_bonova vb ' +
        'CROSS JOIN administratori a ' +
        'WHERE vb.vrijednost_centi = :vrijednost ' +
        'AND vb.aktivna = 1 ' +
        'AND a.aktivan = 1 ' +
        'ORDER BY a.admin_id LIMIT 1';

      Q.ParamByName('placanje').AsString := Placanje;
      Q.ParamByName('vrijednost').AsInteger := Iznos * 100;

      Q.ExecSQL;

      if Q.RowsAffected <> 1 then
        raise Exception.Create(
          'Bon nije kreiran. Provjeri vrste bonova i administratora.'
        );

      { Dohvat upravo kreiranog koda }
      Q.SQL.Text :=
        'SELECT kod FROM vauceri ' +
        'WHERE vaucer_id = last_insert_rowid()';

      Q.Open;

      if Q.IsEmpty then
        raise Exception.Create('Novi bon nije pronadjen.');

      KodBona := Q.FieldByName('kod').AsString;

      Q.Close;

    finally
      Q.Free;
    end;

    SQLTransactionDFC.Commit;

    ShowMessage(
      'DFC bon je uspjesno izdan!' + LineEnding +
      'Vrijednost: ' + IntToStr(Iznos) + ' DFC' +
      LineEnding +
      'Placanje: ' + Placanje + LineEnding +
      'Kod bona: ' + KodBona
    );

  except
    on E: Exception do
    begin
      if SQLTransactionDFC.Active then
        SQLTransactionDFC.Rollback;

      ShowMessage('Greska: ' + E.Message);
    end;
  end;

  try
    UcitajDFC(SQLite3ConnectionDFC.DatabaseName);
  except
    on E: Exception do
      ShowMessage('Greska pri osvjezavanju: ' + E.Message);
  end;
end;

procedure TForm6.btnOsvjeziDFCClick(Sender: TObject);
begin
  try
    UcitajDFC(SQLite3ConnectionDFC.DatabaseName);
  except
    on E: Exception do
      ShowMessage('Greska: ' + E.Message);
  end;
end;

procedure TForm6.btnZatvoriDFCClick(Sender: TObject);
begin
  SQLQueryNovcanici.Close;
  SQLQueryTransakcije.Close;
  SQLQueryBonovi.Close;

  if SQLTransactionDFC.Active then
    SQLTransactionDFC.Rollback;

  if SQLite3ConnectionDFC.Connected then
    SQLite3ConnectionDFC.Close;

  Close;
end;

 procedure TForm6.UcitajDFC(const PutanjaBaze: string);
begin
  if not FileExists(PutanjaBaze) then
    raise Exception.Create('SQLite baza nije pronadjena!');

  SQLQueryNovcanici.Close;
  SQLQueryTransakcije.Close;
  SQLQueryBonovi.Close;

  if SQLTransactionDFC.Active then
    SQLTransactionDFC.Rollback;

  SQLite3ConnectionDFC.DatabaseName := PutanjaBaze;

  if not SQLite3ConnectionDFC.Connected then
  begin
    SQLite3ConnectionDFC.Params.Values['foreign_keys'] := 'ON';
    SQLite3ConnectionDFC.Open;
  end;

  { 1. NOVCANICI }
  SQLQueryNovcanici.SQL.Text :=
    'SELECT ' +
    'p.putnik_id AS ID, ' +
    'p.ime AS Ime, ' +
    'p.prezime AS Prezime, ' +
    'printf(''%.2f'', n.saldo_centi / 100.0) ' +
    'AS Saldo_DFC ' +
    'FROM putnici p ' +
    'JOIN novcanici n ON n.putnik_id = p.putnik_id ' +
    'ORDER BY p.prezime, p.ime';

  SQLQueryNovcanici.Open;

  { 2. TRANSAKCIJE }
  SQLQueryTransakcije.SQL.Text :=
    'SELECT ' +
    'p.ime || '' '' || p.prezime AS Putnik, ' +
    't.tip AS Vrsta, ' +
    'printf(''%.2f'', t.iznos_centi / 100.0) ' +
    'AS Iznos_DFC, ' +
    'printf(''%.2f'', t.saldo_nakon_centi / 100.0) ' +
    'AS Saldo_nakon, ' +
    't.datum_transakcije AS Datum, ' +
    'COALESCE(v.kod, r.broj_racuna, ''-'') ' +
    'AS Referenca ' +
    'FROM transakcije_kredita t ' +
    'JOIN novcanici n ON n.novcanik_id = t.novcanik_id ' +
    'JOIN putnici p ON p.putnik_id = n.putnik_id ' +
    'LEFT JOIN vauceri v ON v.vaucer_id = t.vaucer_id ' +
    'LEFT JOIN racuni r ON r.racun_id = t.racun_id ' +
    'ORDER BY t.transakcija_id DESC';

  SQLQueryTransakcije.Open;

  { 3. BONOVI }
  SQLQueryBonovi.SQL.Text :=
    'SELECT ' +
    'v.kod AS Kod, ' +
    'printf(''%.2f'', vb.vrijednost_centi / 100.0) ' +
    'AS Vrijednost_DFC, ' +
    'v.nacin_placanja AS Placanje, ' +
    'v.status AS Status, ' +
    'v.izdan_u AS Datum_izdavanja, ' +
    'COALESCE(p.ime || '' '' || p.prezime, ''-'') ' +
    'AS Iskoristio ' +
    'FROM vauceri v ' +
    'JOIN vrste_bonova vb ' +
    'ON vb.vrsta_bona_id = v.vrsta_bona_id ' +
    'LEFT JOIN putnici p ' +
    'ON p.putnik_id = v.iskoristio_putnik_id ' +
    'ORDER BY v.vaucer_id DESC';

  SQLQueryBonovi.Open;
end;

end.

