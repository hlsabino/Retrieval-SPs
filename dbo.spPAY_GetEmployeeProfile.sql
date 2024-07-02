USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetEmployeeProfile]
	@EmployeeID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;
DECLARE @strQry Nvarchar(max),@strColumns Nvarchar(max),@strSelect Nvarchar(max),@strSelectCols Nvarchar(max)
DECLARE @strCCCols Nvarchar(max),@strPayColumns Nvarchar(max),@DTYPE NVARCHAR(100)
DECLARE @R INT,@TR INT,@UserColName VARCHAR(100),@SysColName VARCHAR(100),@COLUMNCOSTCENTERID INT,@PARENTCOSTCENTERSYSNAME NVARCHAR(100)
DECLARE @strLookupDimQry  nvarchar(max)
			
SET @strQry=''
SET @strLookupDimQry=''
SET @strColumns=''
SET @strSelectCols=''
SET @strSelect=''
SET @strCCCols=''
SET @strPayColumns=''
SET @PARENTCOSTCENTERSYSNAME=''

DECLARE @TABEMPVIEW TABLE(ID INT IDENTITY(1,1),COSTCENTERCOLID INT,SYSCOLUMNNAME NVARCHAR(200),USERCOLUMNNAME NVARCHAR(200),
						  DATATYPE NVARCHAR(100),COLUMNCOSTCENTERID INT,SYSTABLENAME NVARCHAR(100),PARENTCOSTCENTERSYSNAME NVARCHAR(100))

DECLARE @TABEMPCCVIEW TABLE(ID INT IDENTITY(1,1),COSTCENTERCOLID INT,SYSCOLUMNNAME NVARCHAR(200),USERCOLUMNNAME NVARCHAR(200),
						  DATATYPE NVARCHAR(100),COLUMNCOSTCENTERID INT,SYSTABLENAME NVARCHAR(100),PARENTCOSTCENTERSYSNAME NVARCHAR(100))
						  
DECLARE @TABEMPPAYVIEW TABLE(ID INT IDENTITY(1,1),COSTCENTERCOLID INT,SYSCOLUMNNAME NVARCHAR(200),USERCOLUMNNAME NVARCHAR(200),
						  DATATYPE NVARCHAR(100),COLUMNCOSTCENTERID INT,SYSTABLENAME NVARCHAR(100),PARENTCOSTCENTERSYSNAME NVARCHAR(100))						  						  						  

INSERT INTO @TABEMPVIEW 
	SELECT COSTCENTERCOLID,SYSCOLUMNNAME,USERCOLUMNNAME,ISNULL(USERCOLUMNTYPE,'TEXT'),COLUMNCOSTCENTERID,SYSTABLENAME,PARENTCOSTCENTERSYSNAME FROM ADM_COSTCENTERDEF WHERE
	 COSTCENTERID=50051 AND SYSTABLENAME='COM_CC50051'
	AND COSTCENTERCOLID IN (SELECT COSTCENTERCOLID FROM ADM_QuickViewDefn WHERE QNAME='Mobile_View')

INSERT INTO @TABEMPCCVIEW 
	SELECT COSTCENTERCOLID,SYSCOLUMNNAME,USERCOLUMNNAME,ISNULL(USERCOLUMNTYPE,'TEXT'),COLUMNCOSTCENTERID,SYSTABLENAME,PARENTCOSTCENTERSYSNAME FROM ADM_COSTCENTERDEF WHERE
	 COSTCENTERID=50051 AND SYSTABLENAME='COM_CCCCDATA'
	AND COSTCENTERCOLID IN (SELECT COSTCENTERCOLID FROM ADM_QuickViewDefn WHERE QNAME='Mobile_View')


INSERT INTO @TABEMPPAYVIEW 
	SELECT COSTCENTERCOLID,SYSCOLUMNNAME,USERCOLUMNNAME,ISNULL(USERCOLUMNTYPE,'TEXT'),COLUMNCOSTCENTERID,SYSTABLENAME,PARENTCOSTCENTERSYSNAME FROM ADM_COSTCENTERDEF WHERE
	 COSTCENTERID=50051 AND SYSTABLENAME='PAY_EmpPay'
	AND COSTCENTERCOLID IN (SELECT COSTCENTERCOLID FROM ADM_QuickViewDefn WHERE QNAME='Mobile_View')	
	
	--EMPLOYEE MASTER
	SET @R=1
   	SELECT @TR=COUNT(*) FROM @TABEMPVIEW 
	WHILE (@R<=@TR)
	BEGIN	
		SELECT @SysColName=SYSCOLUMNNAME,@DTYPE=DATATYPE,@COLUMNCOSTCENTERID=COLUMNCOSTCENTERID FROM @TABEMPVIEW WHERE ID=@R
		IF(@strSelect='')
		BEGIN
				IF(@SysColName='StatusID')
				BEGIN
					SET @strSelect='C51.'+convert(varchar,@SysColName)
					SET @strSelect='C3'+CONVERT(VARCHAR,@R)+'.Status as Status'
					IF(@strLookupDimQry='')
						SET @strLookupDimQry=' LEFT JOIN COM_Status C3'+CONVERT(VARCHAR,@R)+' ON C51.'+convert(varchar,@SysColName)+'=C3'+CONVERT(VARCHAR,@R)+'.StatusID'
					ELSE
						SET @strLookupDimQry=@strLookupDimQry+' LEFT JOIN COM_Status C3'+CONVERT(VARCHAR,@R)+' ON C51.'+convert(varchar,@SysColName)+'=C3'+CONVERT(VARCHAR,@R)+'.StatusID'
				END
				ELSE IF(@SysColName='BankBranch' OR @SysColName='BankRoutingCode' OR @SysColName='BankAgentCode')
				BEGIN
					IF(@SysColName='BankBranch')
						SET @strSelect='C68.ccAlpha2 AS BankBranch'
					ELSE IF(@SysColName='BankAgentCode')
						SET @strSelect='C68.ccAlpha7 AS BankAgentCode'
					ELSE IF(@SysColName='BankRoutingCode')
						SET @strSelect='C68.ccAlpha8 AS BankRoutingCode'
				END
				ELSE
				BEGIN
					IF(ISNULL(@DTYPE,'')='DATE')--DATE DATATYPE
						SET @strSelect=',REPLACE(CONVERT(VARCHAR(12),CONVERT(DATETIME,'+'C51.'+convert(varchar,@SysColName)+'),106),'' '',''/'') '+convert(varchar,@SysColName)
					ELSE IF(ISNULL(@DTYPE,'')='COMBOBOX' AND @COLUMNCOSTCENTERID=44)--LOOKUP TYPE
					BEGIN
						SET @strSelect='C51.'+convert(varchar,@SysColName)
						SET @strSelect='C4'+CONVERT(VARCHAR,@R)+'.Name as '+convert(varchar,@SysColName)+'Name'
						IF(@strLookupDimQry='')
							SET @strLookupDimQry=' LEFT JOIN COM_LOOKUP C4'+CONVERT(VARCHAR,@R)+' ON C51.'+convert(varchar,@SysColName)+'=C4'+CONVERT(VARCHAR,@R)+'.NODEID'
						ELSE
							SET @strLookupDimQry=@strLookupDimQry+' LEFT JOIN COM_LOOKUP C4'+CONVERT(VARCHAR,@R)+' ON C51.'+convert(varchar,@SysColName)+'=C4'+CONVERT(VARCHAR,@R)+'.NODEID'
						
					END	
					ELSE IF((ISNULL(@DTYPE,'')='COMBOBOX' OR ISNULL(@DTYPE,'')='LISTBOX') AND @COLUMNCOSTCENTERID>50000)--DIMENSION
					BEGIN
						SET @strSelect='C51.'+convert(varchar,@SysColName)+' as '+convert(varchar,@SysColName)+'NodeID'
						SET @strSelect='C5'+CONVERT(VARCHAR,@R)+'.Code as '+convert(varchar,@SysColName)+'Code'
						SET @strSelect='C5'+CONVERT(VARCHAR,@R)+'.Name as '+convert(varchar,@SysColName)+'Name'
						IF(@strLookupDimQry='')
							SET @strLookupDimQry=' LEFT JOIN COM_CC'+ CONVERT(VARCHAR,@COLUMNCOSTCENTERID)+' C5'+CONVERT(VARCHAR,@R)+' ON C51.'+convert(varchar,@SysColName)+'=C5'+CONVERT(VARCHAR,@R)+'.NODEID'
						ELSE
							SET @strLookupDimQry=@strLookupDimQry+' LEFT JOIN COM_CC'+ CONVERT(VARCHAR,@COLUMNCOSTCENTERID)+' C5'+CONVERT(VARCHAR,@R)+' ON C51.'+convert(varchar,@SysColName)+'=C5'+CONVERT(VARCHAR,@R)+'.NODEID'
						
					END							
					ELSE
						SET @strSelect='C51.'+convert(varchar,@SysColName)
				END
		END
		ELSE
		BEGIN
				IF(@SysColName='StatusID')
				BEGIN
					SET @strSelect=@strSelect+',C51.'+convert(varchar,@SysColName)
					SET @strSelect=@strSelect+',C3'+CONVERT(VARCHAR,@R)+'.Status as Status'
					IF(@strLookupDimQry='')
						SET @strLookupDimQry=' LEFT JOIN COM_Status C3'+CONVERT(VARCHAR,@R)+' ON C51.'+convert(varchar,@SysColName)+'=C3'+CONVERT(VARCHAR,@R)+'.StatusID'
					ELSE
						SET @strLookupDimQry=@strLookupDimQry+' LEFT JOIN COM_Status C3'+CONVERT(VARCHAR,@R)+' ON C51.'+convert(varchar,@SysColName)+'=C3'+CONVERT(VARCHAR,@R)+'.StatusID'
				END
				ELSE IF(@SysColName='BankBranch' OR @SysColName='BankRoutingCode' OR @SysColName='BankAgentCode')
				BEGIN
					IF(@SysColName='BankBranch')
						SET @strSelect=@strSelect+','+'C68.ccAlpha2 AS BankBranch'
					ELSE IF(@SysColName='BankAgentCode')
						SET @strSelect=@strSelect+','+'C68.ccAlpha7 AS BankAgentCode'
					ELSE IF(@SysColName='BankRoutingCode')
						SET @strSelect=@strSelect+','+'C68.ccAlpha8 AS BankRoutingCode'
				END
				ELSE
				BEGIN 
					IF(ISNULL(@DTYPE,'')='DATE')--DATE DATATYPE
						SET @strSelect=@strSelect+',REPLACE(CONVERT(VARCHAR(12),CONVERT(DATETIME,'+'C51.'+convert(varchar,@SysColName)+'),106),'' '',''/'') '+convert(varchar,@SysColName)
					ELSE IF(ISNULL(@DTYPE,'')='COMBOBOX' AND @COLUMNCOSTCENTERID=44)--LOOKUP TYPE
					BEGIN
						SET @strSelect=@strSelect+','+'C51.'+convert(varchar,@SysColName)+' as '+convert(varchar,@SysColName)+'NodeID'
						SET @strSelect=@strSelect+','+'C4'+CONVERT(VARCHAR,@R)+'.Name as '+convert(varchar,@SysColName)+'Name'
						IF(@strLookupDimQry='')
							SET @strLookupDimQry=' LEFT JOIN COM_LOOKUP C4'+CONVERT(VARCHAR,@R)+' ON C51.'+convert(varchar,@SysColName)+'=C4'+CONVERT(VARCHAR,@R)+'.NODEID'
						ELSE
							SET @strLookupDimQry=@strLookupDimQry+' LEFT JOIN COM_LOOKUP C4'+CONVERT(VARCHAR,@R)+' ON C51.'+convert(varchar,@SysColName)+'=C4'+CONVERT(VARCHAR,@R)+'.NODEID'
						
					END	
					ELSE IF((ISNULL(@DTYPE,'')='COMBOBOX' OR ISNULL(@DTYPE,'')='LISTBOX') AND @COLUMNCOSTCENTERID>50000)--DIMENSION
					BEGIN
						SET @strSelect=@strSelect+','+'C51.'+convert(varchar,@SysColName)+' as '+convert(varchar,@SysColName)+'NodeID'
						SET @strSelect=@strSelect+','+'C5'+CONVERT(VARCHAR,@R)+'.Code as '+convert(varchar,@SysColName)+'Code'
						SET @strSelect=@strSelect+','+'C5'+CONVERT(VARCHAR,@R)+'.Name as '+convert(varchar,@SysColName)+'Name'
						IF(@strLookupDimQry='')
							SET @strLookupDimQry=' LEFT JOIN COM_CC'+ CONVERT(VARCHAR,@COLUMNCOSTCENTERID)+' C5'+CONVERT(VARCHAR,@R)+' ON C51.'+convert(varchar,@SysColName)+'=C5'+CONVERT(VARCHAR,@R)+'.NODEID'
						ELSE
							SET @strLookupDimQry=@strLookupDimQry+' LEFT JOIN COM_CC'+ CONVERT(VARCHAR,@COLUMNCOSTCENTERID)+' C5'+CONVERT(VARCHAR,@R)+' ON C51.'+convert(varchar,@SysColName)+'=C5'+CONVERT(VARCHAR,@R)+'.NODEID'
						
					END								
					ELSE
						SET @strSelect=@strSelect+','+'C51.'+convert(varchar,@SysColName)
				END
		END
	SET @R=@R+1
	END
	
	IF (ISNULL(@strSelect,'')<>'')
	BEGIN
		SET @strSelectCols=CONVERT(VARCHAR,REPLACE(LEFT(@strSelect,DATALENGTH(@strSelect)-1),'C51.',''))
	END
	--EMPLOYEE MASTER
		
	--COSTCENTER DATA
	SET @R=1
   	SELECT @TR=COUNT(*) FROM @TABEMPCCVIEW 
	WHILE (@R<=@TR)
	BEGIN
		SELECT @SysColName=SYSCOLUMNNAME,@UserColName=USERCOLUMNNAME,@DTYPE=DATATYPE,@COLUMNCOSTCENTERID=COLUMNCOSTCENTERID,@PARENTCOSTCENTERSYSNAME=PARENTCOSTCENTERSYSNAME
		 FROM @TABEMPCCVIEW WHERE ID=@R 
		SET @UserColName=REPLACE(@UserColName,'(PP)','')
		IF(@strSelect='')
		BEGIN
			IF(ISNULL(@DTYPE,'')='LISTBOX' AND @COLUMNCOSTCENTERID>50000)--DIMENSION
			BEGIN
				SET @strSelect='CC.'+convert(varchar,@SysColName)+ ' as '+ convert(varchar,@UserColName)+'NodeID'
				SET @strSelect='C6'+CONVERT(VARCHAR,@R)+'.Code as '+convert(varchar,@UserColName)+'Code'
				SET @strSelect='C6'+CONVERT(VARCHAR,@R)+'.Name as '+convert(varchar,@UserColName)+'Name'
				IF(@strLookupDimQry='')
					SET @strLookupDimQry=' LEFT JOIN '+ CONVERT(VARCHAR,@PARENTCOSTCENTERSYSNAME)+' C6'+CONVERT(VARCHAR,@R)+' ON CC.'+convert(varchar,@SysColName)+'=C6'+CONVERT(VARCHAR,@R)+'.NODEID'
				ELSE
					SET @strLookupDimQry=@strLookupDimQry+' LEFT JOIN '+ CONVERT(VARCHAR,@PARENTCOSTCENTERSYSNAME)+' C6'+CONVERT(VARCHAR,@R)+' ON CC.'+convert(varchar,@SysColName)+'=C6'+CONVERT(VARCHAR,@R)+'.NODEID'
			END		
			ELSE
				SET @strSelect='CC.'+convert(varchar,@SysColName)+ ' AS'+ convert(varchar,@UserColName)
		END
		ELSE
		BEGIN
			IF(ISNULL(@DTYPE,'')='LISTBOX' AND @COLUMNCOSTCENTERID>50000)--DIMENSION
			BEGIN
				SET @strSelect=@strSelect+','+'CC.'+convert(varchar,@SysColName)+ ' as '+ convert(varchar,@UserColName)+'NodeID'
				SET @strSelect=@strSelect+','+'C6'+CONVERT(VARCHAR,@R)+'.Code as '+convert(varchar,@UserColName)+'Code'
				SET @strSelect=@strSelect+','+'C6'+CONVERT(VARCHAR,@R)+'.Name as '+convert(varchar,@UserColName)+'Name'
				IF(@strLookupDimQry='')
					SET @strLookupDimQry=' LEFT JOIN '+ CONVERT(VARCHAR,@PARENTCOSTCENTERSYSNAME)+' C6'+CONVERT(VARCHAR,@R)+' ON CC.'+convert(varchar,@SysColName)+'=C6'+CONVERT(VARCHAR,@R)+'.NODEID'
				ELSE
					SET @strLookupDimQry=@strLookupDimQry+' LEFT JOIN '+ CONVERT(VARCHAR,@PARENTCOSTCENTERSYSNAME)+' C6'+CONVERT(VARCHAR,@R)+' ON CC.'+convert(varchar,@SysColName)+'=C6'+CONVERT(VARCHAR,@R)+'.NODEID'
			END		
			ELSE
				SET @strSelect=@strSelect+','+'CC.'+convert(varchar,@SysColName)
		END
	SET @R=@R+1
	END
	
	IF (ISNULL(@strSelect,'')<>'')
	BEGIN
		SET @strSelectCols=CONVERT(VARCHAR,REPLACE(LEFT(@strSelect,DATALENGTH(@strSelect)-1),'CC.',''))
	END
	--COSTCENTER DATA
	
	--EMP PAY DATA
	SET @R=1
   	SELECT @TR=COUNT(*) FROM @TABEMPPAYVIEW
	WHILE (@R<=@TR)
	BEGIN	
		SELECT @SysColName=SYSCOLUMNNAME,@DTYPE=DATATYPE  FROM @TABEMPPAYVIEW WHERE ID=@R
		IF(@strSelect='')
			SET @strSelect='PE.'+convert(varchar,@SysColName)
		ELSE
			SET @strSelect=@strSelect+','+'PE.'+convert(varchar,@SysColName)
	SET @R=@R+1
	END
	
	IF (ISNULL(@strSelect,'')<>'')
	BEGIN
		SET @strSelectCols=CONVERT(VARCHAR,REPLACE(LEFT(@strSelect,DATALENGTH(@strSelect)-1),'PE.',''))
	END
	--EMP PAY DATA
	print (@strselect)
	SET @strQry=@strQry+'  SELECT TOP 1 ' + CONVERT(NVARCHAR(MAX),@strselect)+' FROM COM_CC50051 C51
	LEFT JOIN PAY_EmpPay PE ON C51.NODEID=PE.EMPLOYEEID
	JOIN COM_CCCCDATA CC ON C51.NODEID=CC.NODEID AND CC.COSTCENTERID=50051
	LEFT JOIN COM_CC50068 C68 ON C51.IBANK=C68.NODEID '
	SET @strQry=@strQry+@strLookupDimQry
	SET @strQry=@strQry+ ' WHERE C51.NODEID='+ CONVERT(VARCHAR,@EmployeeID)+' ORDER BY  PE.EffectFrom DESC'
	print (@strQry)
	EXEC sp_executesql @STRQRY

END
GO
