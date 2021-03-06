Attribute VB_Name = "DbManagerITests"
'@Folder "SecureADODB.DbManager"
'@TestModule
'@IgnoreModule
Option Explicit
Option Private Module

#Const LateBind = LateBindTests

#If LateBind Then
    Private Assert As Object
#Else
    Private Assert As Rubberduck.PermissiveAssertClass
#End If


'@ModuleInitialize
Private Sub ModuleInitialize()
    #If LateBind Then
        Set Assert = CreateObject("Rubberduck.PermissiveAssertClass")
    #Else
        Set Assert = New Rubberduck.PermissiveAssertClass
    #End If
End Sub


'@ModuleCleanup
Private Sub ModuleCleanup()
    Set Assert = Nothing
End Sub


'===================================================='
'===================== FIXTURES ====================='
'===================================================='


Private Function zfxGetConnectionString(ByVal TypeOrConnString As String) As String
    Dim fileExt As String: fileExt = IIf(TypeOrConnString = "csv", "csv", "db")
    Dim fso As Scripting.FileSystemObject: Set fso = New Scripting.FileSystemObject
    Dim FileName As String: FileName = fso.GetBaseName(ThisWorkbook.Name) & "." & fileExt
    
    zfxGetConnectionString = DbManager.BuildConnectionString(TypeOrConnString, ThisWorkbook.Path, FileName, vbNullString)
End Function


Private Function zfxGetDbManagerFromConnectionParameters(ByVal TypeOrConnString As String) As IDbManager
    Dim fileExt As String: fileExt = IIf(TypeOrConnString = "csv", "csv", "db")
    Dim fso As Scripting.FileSystemObject: Set fso = New Scripting.FileSystemObject
    Dim FileName As String: FileName = fso.GetBaseName(ThisWorkbook.Name) & "." & fileExt

    Dim dbm As IDbManager
    Set dbm = DbManager.FromConnectionParameters(TypeOrConnString, ThisWorkbook.Path, FileName, vbNullString, True, LoggerTypeEnum.logPrivate)
    Set zfxGetDbManagerFromConnectionParameters = dbm
End Function


Private Function zfxGetDbManagerFromConnectionString(ByVal TypeOrConnString As String) As IDbManager
    Dim dbm As IDbManager
    Set dbm = DbManager.FromConnectionParameters(TypeOrConnString) ' Use transactions and global Logger by default
    Set zfxGetDbManagerFromConnectionString = dbm
End Function


Private Function zfxGetSQLSelect0P(tableName As String) As String
    zfxGetSQLSelect0P = "SELECT * FROM " & tableName & " WHERE age >= 45 AND country = 'South Korea' ORDER BY id DESC"
End Function


Private Function zfxGetSQLSelect1P(tableName As String) As String
    zfxGetSQLSelect1P = "SELECT * FROM " & tableName & " WHERE age >= ? AND country = 'South Korea' ORDER BY id DESC"
End Function


Private Function zfxGetSQLSelect2P(tableName As String) As String
    zfxGetSQLSelect2P = "SELECT * FROM " & tableName & " WHERE age >= ? AND country = ? ORDER BY id DESC"
End Function


Private Function zfxGetSQLInsert0P(tableName As String) As String
    zfxGetSQLInsert0P = _
        "INSERT INTO " & tableName & " (id, first_name, last_name, age, gender, email, country, domain) " & _
        "VALUES " & _
            "(" & CStr(GenerateSerialID) & ", 'first_name1', 'last_name1', 32, 'male', 'first_name1.last_name1@domain.com', 'Country', 'domain.com'), " & _
            "(" & CStr(GenerateSerialID + 1) & ", 'first_name2', 'last_name2', 32, 'male', 'first_name2.last_name2@domain.com', 'Country', 'domain.com')"
End Function


Private Function zfxGetCSVTableName() As String
    zfxGetCSVTableName = "SecureADODB.csv"
End Function


Private Function zfxGetSQLiteTableName() As String
    zfxGetSQLiteTableName = "people"
End Function


Private Function zfxGetSQLiteTableNameInsert() As String
    zfxGetSQLiteTableNameInsert = "people_insert"
End Function


Private Function zfxGetParameterOne() As Variant
    zfxGetParameterOne = 45
End Function


Private Function zfxGetParameterTwo() As Variant
    zfxGetParameterTwo = "South Korea"
End Function


'===================================================='
'================= TESTING FIXTURES ================='
'===================================================='


'@TestMethod("Connection String")
Private Sub zfxGetConnectionString_VerifiesDefaultMockConnectionStrings()
    On Error GoTo TestFail
    
Arrange:
    Dim CSVString As String
    #If Win64 Then
        CSVString = "Driver=Microsoft Access Text Driver (*.txt, *.csv);DefaultDir=" + ThisWorkbook.Path + ";"
    #Else
        CSVString = "Driver={Microsoft Text Driver (*.txt; *.csv)};DefaultDir=" + ThisWorkbook.Path + ";"
    #End If
    Dim SQLiteString As String
    SQLiteString = "Driver=SQLite3 ODBC Driver;Database=" + ThisWorkbook.Path + Application.PathSeparator + "SecureADODB.db;" + _
                   "SyncPragma=NORMAL;FKSupport=True;"
Act:
Assert:
    Assert.AreEqual CSVString, DbManager.BuildConnectionString("csv"), "CSV string mismatch"
    Assert.AreEqual SQLiteString, DbManager.BuildConnectionString("sqlite"), "SQLite string mismatch"

CleanExit:
    Exit Sub
TestFail:
    Assert.Fail "Error: " & Err.Number & " - " & Err.Description
End Sub


'@TestMethod("Connection String")
Private Sub zfxGetDbManagerFromConnectionParameters_ThrowsGivenInvalidConnectionString()
    On Error Resume Next
    Dim TypeOrConnString As String: TypeOrConnString = "Driver=SQLite3 ODBC Driver;Database=C:\TMP\db.db;"
    Dim dbm As IDbManager: Set dbm = zfxGetDbManagerFromConnectionParameters(TypeOrConnString)
    AssertExpectedError Assert, ErrNo.AdoConnectionStringErr
End Sub


'===================================================='
'================ TEST MOCK DATABASE ================'
'===================================================='


'@TestMethod("DbManager.Command")
Private Sub ztiDbManagerCommand_VerifiesAdoCommand()
    On Error GoTo TestFail
    
Arrange:
    Dim dbm As IDbManager: Set dbm = DbManager.FromConnectionParameters(zfxGetConnectionString("sqlite"))
    Dim SQLSelect2P As String: SQLSelect2P = zfxGetSQLSelect2P(zfxGetSQLiteTableName)
Act:
    Dim cmdAdo As ADODB.Command
    Set cmdAdo = dbm.Command.AdoCommand(SQLSelect2P, zfxGetParameterOne, zfxGetParameterTwo)
Assert:
    Assert.IsNotNothing cmdAdo.ActiveConnection, "ActiveConnection of the Command object is not set."
    Assert.AreEqual ADODB.ObjectStateEnum.adStateOpen, cmdAdo.ActiveConnection.State, "ActiveConnection of the Command object is not open."
    Assert.IsTrue cmdAdo.Prepared, "Prepared property of the Command object not set."
    Assert.AreEqual 2, cmdAdo.Parameters.Count, "Command should have two parameters set."
    Assert.AreEqual ADODB.DataTypeEnum.adInteger, cmdAdo.Parameters.Item(0).Type, "Param #1 type should be adInteger."
    Assert.AreEqual 45, cmdAdo.Parameters.Item(0).value, "Param #1 value should be 45."
    Assert.AreEqual ADODB.DataTypeEnum.adVarWChar, cmdAdo.Parameters.Item(1).Type, "Param #2 type should be adVarWChar."
    Assert.AreEqual "South Korea", cmdAdo.Parameters.Item(1).value, "Param #2 value should be South Korea."
    Assert.AreNotEqual vbNullString, cmdAdo.CommandText
    
CleanExit:
    Exit Sub
TestFail:
    Assert.Fail "Error: " & Err.Number & " - " & Err.Description
End Sub


'@TestMethod("DbManager.Recordset")
Private Sub ztiDbManagerRecordset_VerifiesAdoRecordsetDefaultDisconnectedArray()
    On Error GoTo TestFail
    
Arrange:
    Dim dbm As IDbManager: Set dbm = DbManager.FromConnectionParameters(zfxGetConnectionString("sqlite"))
    Dim SQLSelect2P As String: SQLSelect2P = zfxGetSQLSelect2P(zfxGetSQLiteTableName)
Act:
    Dim rstAdo As ADODB.Recordset
    Set rstAdo = dbm.Recordset.AdoRecordset(SQLSelect2P, zfxGetParameterOne, zfxGetParameterTwo)
Assert:
    Assert.IsNotNothing rstAdo.ActiveConnection, "ActiveConnection of the Recordset object is not set."
    Assert.IsNotNothing rstAdo.ActiveCommand, "ActiveCommand of the Recordset object is not set."
    Assert.IsFalse IsFalsy(rstAdo.Source), "The Source property of the Recordset object is not set."
    Assert.AreEqual ADODB.CursorTypeEnum.adOpenStatic, rstAdo.CursorType, "The CursorType of the Recordset object should be adOpenStatic."
    Assert.AreEqual ADODB.CursorLocationEnum.adUseClient, rstAdo.CursorLocation, "The CursorLocation of the Recordset object should be adUseClient."
    Assert.AreNotEqual 1, rstAdo.MaxRecords, "The MaxRecords of the Recordset object should not be set to 1 for a regular Recordset."

CleanExit:
    Exit Sub
TestFail:
    Assert.Fail "Error: " & Err.Number & " - " & Err.Description
End Sub


'@TestMethod("DbManager.Recordset")
Private Sub ztiDbManagerRecordset_VerifiesAdoRecordsetDisconnectedScalar()
    On Error GoTo TestFail
    
Arrange:
    Dim dbm As IDbManager: Set dbm = DbManager.FromConnectionParameters(zfxGetConnectionString("sqlite"))
    Dim SQLSelect2P As String: SQLSelect2P = zfxGetSQLSelect2P(zfxGetSQLiteTableName)
Act:
    Dim rst As IDbRecordset
    Set rst = dbm.Recordset(Scalar:=True, CacheSize:=15)
    Dim rstAdo As ADODB.Recordset
    Set rstAdo = rst.AdoRecordset(SQLSelect2P, zfxGetParameterOne, zfxGetParameterTwo)
Assert:
    Assert.AreEqual 1, rstAdo.MaxRecords, "The MaxRecords of the Recordset object should be set to 1 for a scalar query."
    Assert.AreEqual 15, rstAdo.CacheSize, "The CacheSize of the Recordset object should be set to 15."

CleanExit:
    Exit Sub
TestFail:
    Assert.Fail "Error: " & Err.Number & " - " & Err.Description
End Sub


'@TestMethod("DbManager.Recordset")
Private Sub ztiDbManagerRecordset_VerifiesAdoRecordsetOnlineArray()
    On Error GoTo TestFail
    
Arrange:
    Dim dbm As IDbManager: Set dbm = DbManager.FromConnectionParameters(zfxGetConnectionString("sqlite"), , , , False)
    Dim SQLSelect2P As String: SQLSelect2P = zfxGetSQLSelect2P(zfxGetSQLiteTableName)
Act:
    Dim rstAdo As ADODB.Recordset
    Set rstAdo = dbm.Recordset(Disconnected:=False).AdoRecordset(SQLSelect2P, zfxGetParameterOne, zfxGetParameterTwo)
Assert:
    Assert.AreEqual ADODB.CursorTypeEnum.adOpenForwardOnly, rstAdo.CursorType, "The CursorType of the Recordset object should be adOpenForwardOnly."
    Assert.AreEqual ADODB.CursorLocationEnum.adUseServer, rstAdo.CursorLocation, "The CursorLocation of the Recordset object should be adUseServer."

CleanExit:
    Exit Sub
TestFail:
    Assert.Fail "Error: " & Err.Number & " - " & Err.Description
End Sub


'@TestMethod("DbManager.Recordset.Query")
Private Sub ztiDbManagerOpenRecordset_VerifiesAdoRecordsetDisconnectedArraySQLite()
    On Error GoTo TestFail
    
Arrange:
    Dim dbm As IDbManager: Set dbm = DbManager.FromConnectionParameters(zfxGetConnectionString("sqlite"))
    Dim SQLSelect2P As String: SQLSelect2P = zfxGetSQLSelect2P(zfxGetSQLiteTableName)
Act:
    Dim rstAdo As ADODB.Recordset
    Set rstAdo = dbm.Recordset.OpenRecordset(SQLSelect2P, zfxGetParameterOne, zfxGetParameterTwo)
Assert:
    Assert.AreEqual 11, rstAdo.RecordCount, "Recordset SQLite SELECT query RecordCount mismatch."
    Assert.AreEqual 2, rstAdo.PageCount, "Recordset SQLite SELECT query PageCount mismatch."
    Assert.AreEqual 8, rstAdo.Fields.Count, "Recordset SQLite SELECT query did not return expected number of fields."

CleanExit:
    Exit Sub
TestFail:
    Assert.Fail "Error: " & Err.Number & " - " & Err.Description
End Sub


'@TestMethod("DbManager.Recordset.Query")
Private Sub ztiDbManagerOpenRecordset_VerifiesAdoRecordsetDisconnectedArrayCSV()
    On Error GoTo TestFail
    
Arrange:
    Dim dbm As IDbManager: Set dbm = DbManager.FromConnectionParameters(zfxGetConnectionString("csv"), , , , False)
    Dim SQLSelect1P As String: SQLSelect1P = zfxGetSQLSelect1P(zfxGetCSVTableName)
Act:
    Dim rstAdo As ADODB.Recordset
    Set rstAdo = dbm.Recordset.OpenRecordset(SQLSelect1P, zfxGetParameterOne)
Assert:
    Assert.AreEqual 11, rstAdo.RecordCount, "Recordset CSV SELECT query RecordCount mismatch."
    Assert.AreEqual 2, rstAdo.PageCount, "Recordset CSV SELECT query PageCount mismatch."
    Assert.AreEqual 8, rstAdo.Fields.Count, "Recordset CSV SELECT query did not return expected number of fields."

CleanExit:
    Exit Sub
TestFail:
    Assert.Fail "Error: " & Err.Number & " - " & Err.Description
End Sub


'@TestMethod("DbManager.Recordset.Query")
Private Sub ztiDbManagerFactoryGuard_ThrowsIfRequestedTransactionNotSupported()
    On Error Resume Next
    Dim dbm As IDbManager: Set dbm = DbManager.FromConnectionParameters(zfxGetConnectionString("csv"))
    AssertExpectedError Assert, ErrNo.AdoInvalidTransactionErr
End Sub


'@TestMethod("DbManager.Recordset.Query")
Private Sub ztiDbManagerOpenRecordset_ThrowsGivenUnsupportedParameterTypeCSV()
    '''' Present mapping maps VBA string to adVarWChar, unsupported by the CSV backend (Office 2002, 32bit)
    On Error GoTo TestFail
    
    Dim dbm As IDbManager: Set dbm = DbManager.FromConnectionParameters(zfxGetConnectionString("csv"), , , , False)
    Dim SQLSelect2P As String: SQLSelect2P = zfxGetSQLSelect2P(zfxGetCSVTableName)
    
    On Error Resume Next
    Dim rstAdo As ADODB.Recordset
    Set rstAdo = dbm.Recordset.OpenRecordset(SQLSelect2P, zfxGetParameterOne, zfxGetParameterTwo)
    AssertExpectedError Assert, ErrNo.AdoInvalidParameterTypeErr
    On Error GoTo TestFail
    
    Assert.IsNothing rstAdo, "Recordset variable unexpectedly set."
    Dim ExecuteStatus As ADODB.EventStatusEnum: ExecuteStatus = dbm.Connection.ExecuteStatus
    Assert.AreEqual ADODB.EventStatusEnum.adStatusErrorsOccurred, ExecuteStatus, "Connection error status mismatch."
    
    Exit Sub

TestFail:
    Assert.Fail "Error: " & Err.Number & " - " & Err.Description
End Sub


'@TestMethod("DbManager.Recordset.Query")
Private Sub ztiDbManagerOpenRecordset_VerifiesAdoRecordsetOnlineArraySQLite()
    On Error GoTo TestFail
    
Arrange:
    Dim dbm As IDbManager: Set dbm = DbManager.FromConnectionParameters(zfxGetConnectionString("sqlite"))
    Dim SQLSelect2P As String: SQLSelect2P = zfxGetSQLSelect2P(zfxGetSQLiteTableName)
Act:
    Dim rstAdo As ADODB.Recordset
    Set rstAdo = dbm.Recordset(Disconnected:=False).OpenRecordset(SQLSelect2P, zfxGetParameterOne, zfxGetParameterTwo)
    Dim result As Variant
    result = rstAdo.GetRows
Assert:
    Assert.AreEqual -1, rstAdo.RecordCount, "Recordset SQLite SELECT query RecordCount mismatch."
    Assert.AreEqual -1, rstAdo.PageCount, "Recordset SQLite SELECT query PageCount mismatch."
    Assert.AreEqual ADODB.PositionEnum.adPosEOF, rstAdo.AbsolutePosition, "Recordset SQLite SELECT - AbsolutePosition mismatch."
    Assert.IsTrue IsArray(result), "GetRows on recordset SQLite SELECT query did not return an array."
    Assert.AreEqual 7, UBound(result, 1), "Recordset SQLite SELECT query did not return expected number of fields."
    Assert.AreEqual 10, UBound(result, 2), "Recordset SQLite SELECT query did not return expected number of records."

CleanExit:
    Exit Sub
TestFail:
    Assert.Fail "Error: " & Err.Number & " - " & Err.Description
End Sub


'@TestMethod("DbManager.Recordset.Query")
Private Sub ztiDbManagerOpenRecordset_VerifiesAdoRecordsetScalarCSV()
    On Error GoTo TestFail
    
Arrange:
    Dim dbm As IDbManager: Set dbm = DbManager.FromConnectionParameters(zfxGetConnectionString("csv"), , , , False)
    Dim SQLSelect As String: SQLSelect = zfxGetSQLSelect0P(zfxGetCSVTableName)
Act:
    Dim result As Variant
    result = dbm.Recordset.OpenScalar(SQLSelect)
Assert:
    Assert.AreEqual 906, result, "Scalar CSV SELECT query result mismatch."

CleanExit:
    Exit Sub
TestFail:
    Assert.Fail "Error: " & Err.Number & " - " & Err.Description
End Sub


'@TestMethod("DbManager.Command.Query")
Private Sub ztiDbManagerExecuteNonQuery_VerifiesInsertSQLite()
    On Error GoTo TestFail
    
Arrange:
    '''' True (default value) parameter is next line activates transactions.
    '''' Transaction is activated in the DbManager constructor and, if not committed,
    '''' is rolledback in its destructor. Execution status indicates the result of an
    '''' individual executed command regardless of whether an active transaction is
    '''' present and, if present, regardless of whether it is later committed or rolledback.
    '''' Set to false below to disable transactions and activate the autocommit mode to see
    '''' the result of the test insert in the database.
    Dim dbm As IDbManager: Set dbm = DbManager.FromConnectionParameters(zfxGetConnectionString("sqlite"), , , , True)
    Dim conn As IDbConnection: Set conn = dbm.Connection
    Dim SQLInsert0P As String: SQLInsert0P = zfxGetSQLInsert0P(zfxGetSQLiteTableNameInsert)
Act:
    dbm.Command.ExecuteNonQuery SQLInsert0P
    Dim RecordsAffected As Long: RecordsAffected = conn.RecordsAffected
    Dim ExecuteStatus As ADODB.EventStatusEnum: ExecuteStatus = conn.ExecuteStatus
Assert:
    Assert.AreEqual ADODB.EventStatusEnum.adStatusOK, ExecuteStatus, "Execution status mismatch."
    Assert.AreEqual 2, RecordsAffected, "Execution status mismatch."

CleanExit:
    Exit Sub
TestFail:
    Assert.Fail "Error: " & Err.Number & " - " & Err.Description
End Sub
