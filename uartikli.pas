unit uArtikli;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, SQLDB, DB, SQLite3Conn, Forms, Controls, Graphics, Dialogs,
  StdCtrls, DBGrids;

type

  { TForm3 }

  TForm3 = class(TForm)
    btnOsvjeziArtikle: TButton;
    btnZatvoriArtikle: TButton;
    btnDodajArtikl: TButton;
    btnUrediArtikl: TButton;
    btnDeaktivirajArtikl: TButton;
    DataSourceArtikli: TDataSource;
    DBGridArtikli: TDBGrid;
    lblNaslovArtikli: TLabel;
    SQLite3ConnectionArtikli: TSQLite3Connection;
    SQLQueryArtikli: TSQLQuery;
    SQLTransactionArtikli: TSQLTransaction;
    procedure btnDeaktivirajArtiklClick(Sender: TObject);
    procedure btnDodajArtiklClick(Sender: TObject);
    procedure btnOsvjeziArtikleClick(Sender: TObject);
    procedure btnUrediArtiklClick(Sender: TObject);
    procedure btnZatvoriArtikleClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private

  public
    procedure UcitajArtikle(const PutanjaBaze: string);
  end;

var
  Form3: TForm3;

implementation

{$R *.lfm}

procedure TForm3.UcitajArtikle(const PutanjaBaze: string);
begin
  if not FileExists(PutanjaBaze) then
    raise Exception.Create('SQLite baza nije pronadjena!');

  SQLQueryArtikli.Close;

  if SQLTransactionArtikli.Active then
    SQLTransactionArtikli.Rollback;

  SQLite3ConnectionArtikli.DatabaseName := PutanjaBaze;

  if not SQLite3ConnectionArtikli.Connected then
    SQLite3ConnectionArtikli.Open;

  SQLQueryArtikli.SQL.Text :=
    'SELECT ' +
    'a.artikl_id AS ID, ' +
    'a.sifra AS Sifra, ' +
    'a.naziv AS Artikl, ' +
    'k.naziv AS Kategorija, ' +
    'printf(''%.2f'', a.cijena_neto_centi / 100.0) ' +
    'AS Cijena_EUR, ' +
    'COALESCE(z.kolicina, 0) AS Zaliha, ' +
    'CASE WHEN a.aktivan = 1 THEN ''DA'' ' +
    'ELSE ''NE'' END AS Aktivan ' +
    'FROM artikli a ' +
    'JOIN kategorije k ' +
    'ON a.kategorija_id = k.kategorija_id ' +
    'LEFT JOIN zalihe z ' +
    'ON a.artikl_id = z.artikl_id ' +
    'ORDER BY a.naziv';

  SQLQueryArtikli.Open;
end;

{ TForm3 }

procedure TForm3.FormCreate(Sender: TObject);
begin

end;

procedure TForm3.btnOsvjeziArtikleClick(Sender: TObject);
begin
  try
    UcitajArtikle(
      SQLite3ConnectionArtikli.DatabaseName
    );
  except
    on E: Exception do
      ShowMessage('Greska: ' + E.Message);
  end;
end;

procedure TForm3.btnUrediArtiklClick(Sender: TObject);
var
  ID, Cijena: Integer;
  P: array[0..1] of string;
  PromijeniCijenu: Boolean;
  Q: TSQLQuery;
  begin
    { Provjera odabranog artikla }
    if not SQLQueryArtikli.Active then
    begin
      ShowMessage('Podaci nisu ucitani!');
      Exit;
    end;

    if SQLQueryArtikli.IsEmpty then
    begin
      ShowMessage('Prvo odaberi artikl!');
      Exit;
    end;

    ID := SQLQueryArtikli.FieldByName('ID').AsInteger;

    P[0] := SQLQueryArtikli.FieldByName('Artikl').AsString;
    P[1] := '';

    { Unos novih podataka }
    if not InputQuery(
      'Uredi artikl',
      ['Naziv artikla',
       'Nova neto cijena u centima (prazno = bez promjene)'],
      P
    ) then
      Exit;

    if Trim(P[0]) = '' then
    begin
      ShowMessage('Naziv artikla ne smije biti prazan!');
      Exit;
    end;

    PromijeniCijenu := Trim(P[1]) <> '';

    if PromijeniCijenu then
    begin
      if not TryStrToInt(Trim(P[1]), Cijena) then
      begin
        ShowMessage('Cijena mora biti cijeli broj centi!');
        Exit;
      end;

      if Cijena < 0 then
      begin
        ShowMessage('Cijena ne smije biti negativna!');
        Exit;
      end;
    end;

    try
      SQLQueryArtikli.Close;

      if SQLTransactionArtikli.Active then
        SQLTransactionArtikli.Rollback;

      SQLTransactionArtikli.StartTransaction;

      Q := TSQLQuery.Create(nil);
      try
        Q.Database := SQLite3ConnectionArtikli;
        Q.Transaction := SQLTransactionArtikli;

        if PromijeniCijenu then
          Q.SQL.Text :=
            'UPDATE artikli SET naziv = :naziv, ' +
            'cijena_neto_centi = :cijena ' +
            'WHERE artikl_id = :id'
        else
          Q.SQL.Text :=
            'UPDATE artikli SET naziv = :naziv ' +
            'WHERE artikl_id = :id';

        Q.ParamByName('naziv').AsString := Trim(P[0]);
        Q.ParamByName('id').AsInteger := ID;

        if PromijeniCijenu then
          Q.ParamByName('cijena').AsInteger := Cijena;

        Q.ExecSQL;

        if Q.RowsAffected <> 1 then
          raise Exception.Create('Artikl nije pronadjen.');

      finally
        Q.Free;
      end;

      SQLTransactionArtikli.Commit;

      ShowMessage('Artikl je uspjesno uredjen!');

    except
      on E: Exception do
      begin
        if SQLTransactionArtikli.Active then
          SQLTransactionArtikli.Rollback;

        ShowMessage('Greska: ' + E.Message);
      end;
    end;

    { Osvjezavanje tablice }
    try
      UcitajArtikle(SQLite3ConnectionArtikli.DatabaseName);
    except
      on E: Exception do
        ShowMessage('Greska pri osvjezavanju: ' + E.Message);
    end;
end;

procedure TForm3.btnDodajArtiklClick(Sender: TObject);
var
  P: array[0..6] of string;
  Cijena, PDV, Kolicina, Minimum: Integer;
  Q: TSQLQuery;
begin
  P[0] := '';
  P[1] := '';
  P[2] := '';
  P[3] := '500';
  P[4] := '25';
  P[5] := '10';
  P[6] := '3';

  if not InputQuery(
    'Novi artikl',
    ['Sifra artikla',
     'Naziv artikla',
     'Naziv postojece kategorije',
     'Neto cijena u centima',
     'PDV (%)',
     'Pocetna kolicina',
     'Minimalna kolicina'],
    P
  ) then
    Exit;

  if (Trim(P[0]) = '') or
     (Trim(P[1]) = '') or
     (Trim(P[2]) = '') then
  begin
    ShowMessage('Sifra, naziv i kategorija su obavezni!');
    Exit;
  end;

  if (not TryStrToInt(P[3], Cijena)) or
     (not TryStrToInt(P[4], PDV)) or
     (not TryStrToInt(P[5], Kolicina)) or
     (not TryStrToInt(P[6], Minimum)) then
  begin
    ShowMessage('Unesi ispravne brojeve!');
    Exit;
  end;

  if (Cijena < 0) or
     (PDV < 0) or (PDV > 100) or
     (Kolicina < 0) or (Minimum < 0) then
  begin
    ShowMessage('Brojevi ne smiju biti negativni!');
    Exit;
  end;

  try
    SQLQueryArtikli.Close;

    if SQLTransactionArtikli.Active then
      SQLTransactionArtikli.Rollback;

    SQLTransactionArtikli.StartTransaction;

    Q := TSQLQuery.Create(nil);
    try
      Q.Database := SQLite3ConnectionArtikli;
      Q.Transaction := SQLTransactionArtikli;

      Q.SQL.Text :=
        'INSERT INTO artikli ' +
        '(sifra, naziv, kategorija_id, ' +
        'cijena_neto_centi, pdv_postotak, aktivan) ' +
        'SELECT :sifra, :naziv, kategorija_id, ' +
        ':cijena, :pdv, 1 ' +
        'FROM kategorije ' +
        'WHERE naziv = :kat COLLATE NOCASE ' +
        'AND aktivna = 1';

      Q.ParamByName('sifra').AsString := Trim(P[0]);
      Q.ParamByName('naziv').AsString := Trim(P[1]);
      Q.ParamByName('kat').AsString := Trim(P[2]);
      Q.ParamByName('cijena').AsInteger := Cijena;
      Q.ParamByName('pdv').AsInteger := PDV;

      Q.ExecSQL;

      if Q.RowsAffected <> 1 then
        raise Exception.Create(
          'Kategorija nije pronadjena ili nije aktivna.'
        );

      Q.SQL.Text :=
        'INSERT INTO zalihe ' +
        '(artikl_id, kolicina, minimalna_kolicina) ' +
        'VALUES (last_insert_rowid(), :kol, :min)';

      Q.ParamByName('kol').AsInteger := Kolicina;
      Q.ParamByName('min').AsInteger := Minimum;

      Q.ExecSQL;

      SQLTransactionArtikli.Commit;

    finally
      Q.Free;
    end;

    ShowMessage('Artikl uspjesno dodan!');

  except
    on E: Exception do
    begin
      if SQLTransactionArtikli.Active then
        SQLTransactionArtikli.Rollback;

      ShowMessage('Greska: ' + E.Message);
    end;
  end;

  try
    UcitajArtikle(SQLite3ConnectionArtikli.DatabaseName);
  except
    on E: Exception do
      ShowMessage('Greska pri osvjezavanju: ' + E.Message);
  end;
end;

procedure TForm3.btnDeaktivirajArtiklClick(Sender: TObject);
var
  ID: Integer;
  Naziv: string;
  Q: TSQLQuery;
  begin
    { Provjera odabranog artikla }
    if not SQLQueryArtikli.Active then
    begin
      ShowMessage('Podaci nisu ucitani!');
      Exit;
    end;

    if SQLQueryArtikli.IsEmpty then
    begin
      ShowMessage('Prvo odaberi artikl!');
      Exit;
    end;

    if SQLQueryArtikli.FieldByName('Aktivan').AsString = 'NE' then
    begin
      ShowMessage('Ovaj artikl je vec deaktiviran!');
      Exit;
    end;

    ID := SQLQueryArtikli.FieldByName('ID').AsInteger;
    Naziv := SQLQueryArtikli.FieldByName('Artikl').AsString;

    { Potvrda administratora }
    if MessageDlg(
      'Zelis li deaktivirati artikl "' + Naziv + '"?',
      mtConfirmation,
      [mbYes, mbNo],
      0
    ) <> mrYes then
      Exit;

    try
      SQLQueryArtikli.Close;

      if SQLTransactionArtikli.Active then
        SQLTransactionArtikli.Rollback;

      SQLTransactionArtikli.StartTransaction;

      Q := TSQLQuery.Create(nil);
      try
        Q.Database := SQLite3ConnectionArtikli;
        Q.Transaction := SQLTransactionArtikli;

        Q.SQL.Text :=
          'UPDATE artikli ' +
          'SET aktivan = 0 ' +
          'WHERE artikl_id = :id AND aktivan = 1';

        Q.ParamByName('id').AsInteger := ID;

        Q.ExecSQL;

        if Q.RowsAffected <> 1 then
          raise Exception.Create(
            'Artikl nije pronadjen ili je vec deaktiviran.'
          );

      finally
        Q.Free;
      end;

      SQLTransactionArtikli.Commit;

      ShowMessage('Artikl je uspjesno deaktiviran!');

    except
      on E: Exception do
      begin
        if SQLTransactionArtikli.Active then
          SQLTransactionArtikli.Rollback;

        ShowMessage('Greska: ' + E.Message);
      end;
    end;

    { Osvjezavanje tablice }
    try
      UcitajArtikle(SQLite3ConnectionArtikli.DatabaseName);
    except
      on E: Exception do
        ShowMessage('Greska pri osvjezavanju: ' + E.Message);
    end;
end;

procedure TForm3.btnZatvoriArtikleClick(Sender: TObject);
begin
   Close;
end;

end.

