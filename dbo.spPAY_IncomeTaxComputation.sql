USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_IncomeTaxComputation]
	@EmpNode [int],
	@Year [int],
	@StartMonth [int],
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	SET NOCOUNT ON;
	Declare @Grade INT,@StartMonthName datetime,@EndMonthName datetime
	
	Declare @monthTable table (id int identity(1,1),StartDate datetime,Enddate datetime,ActualDays int,MonthNo int,MontName varchar(20),MonthText varchar(100),sno int,componentid int,componentname varchar(200),AMOUNT FLOAT)
	Declare @TabMonthlyPayroll TABLE(ID INT IDENTITY(1,1),SNo int,componentID INT,SalaryBreakup varchar(100),FieldName varchar(25),
					   MonthNo01 Float, MonthNo02 Float, MonthNo03 Float, MonthNo04 Float, MonthNo05 Float, MonthNo06 Float,
					   MonthNo07 Float, MonthNo08 Float, MonthNo09 Float, MonthNo10 Float, MonthNo11 Float, MonthNo12 Float,
					   TotalAmount Float,ISGroup int)	
					   
					   

	SELECT @Grade=ISNULL(CCNID53,0) FROM COM_CCCCDATA WITH(NOLOCK) WHERE COSTCENTERID=50051 AND NODEID=@EmpNode	
	Insert into @TabMonthlyPayroll				   
			select c54.SNo,c54.ComponentID,c52.Name,'dcCalcNum'+convert(varchar,c54.Sno),0,0,0,0,0,0,0,0,0,0,0,0,0,0 from com_cc50054 c54 WITH(NOLOCK),com_cc50052 c52 WITH(NOLOCK) where 
				c52.NodeID=c54.ComponentID and gradeid=@Grade and Type =1 and taxmap>0  and PayrollDate=(Select Max(PayrollDate) From COM_CC50054  WITH(NOLOCK)) 
	Insert into @TabMonthlyPayroll				   
			select 0,0,'TOTAL SALARY','',0,0,0,0,0,0,0,0,0,0,0,0,0,1 
	--FILL MONTH TABLE
	--start Month loop
	DECLARE @IntMonthNo INT,@intRMonthNo int,@j int,@i int,@rc int,@trc int,@serno int,@comptid int
	set @rc=1
	select @trc=count(*) from @TabMonthlyPayroll where sno>0
	WHILE (@rc<=@trc)
	BEGIN
	 select @serno=sno,@comptid=componentid from @TabMonthlyPayroll where id=@rc
			set @IntMonthNo=0
			set @j=1
			set @i=1
				WHILE (@i<=12)
				BEGIN
							IF (@IntMonthNo = 12)
							BEGIN
								set @intRMonthNo = @IntMonthNo - @i;
								WHILE (@j<=@intRMonthNo)
								BEGIN
									SET @StartMonthName= CONVERT(VARCHAR,@Year)+'-' + DATENAME(MONTH,DATEADD(MONTH,@j,-1))+'-' +'01'
									SET @StartMonthName=CONVERT(DATETIME,@StartMonthName)
									SET @EndMonthName=DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@StartMonthName)+1,0))
									SET @EndMonthName=CONVERT(DATETIME,@EndMonthName)
									insert into @monthTable select @StartMonthName,@EndMonthName,datediff(d,@StartMonthName,@EndMonthName)+1,@j,left(datename(month,@StartMonthName),3),'Month'+convert(varchar,@j),@serno,@comptid,'',0
									
									
									SET @i=@i+1 
								END
							END
							ELSE
							BEGIN
								SET @StartMonthName= CONVERT(VARCHAR,@Year)+'-' + DATENAME(MONTH,DATEADD(MONTH,@i,-1))+'-' +'01'
								SET @StartMonthName=CONVERT(DATETIME,@StartMonthName)
								SET @EndMonthName=DATEADD(D,-1,DATEADD(MM,DATEDIFF(M,0,@StartMonthName)+1,0))
								SET @EndMonthName=CONVERT(DATETIME,@EndMonthName)
								set @IntMonthNo=@i
								insert into @monthTable select @StartMonthName,@EndMonthName,datediff(d,@StartMonthName,@EndMonthName)+1,@i,left(datename(month,@StartMonthName),3),'Month'+convert(varchar,@i),@serno,@comptid,'',0
								
							END
				 SET @i=@i+1 					
				 END
		set @rc=@rc+1				 
		END
		 --end Month loop
	--
	--START: LOADING EARNING COMPONENTS AND AMOUNT FROM EMPPAY TABLE AND UPDATE THE AMOUNT IN @TABVACATIONMGMET
	DECLARE @STRQRY VARCHAR(MAX),@FIELDTYPE DECIMAL(9,2),@NUMFILEDNAME VARCHAR(200),@NUMFILEDNAME2 VARCHAR(200)
	--CREATE TABLE #CALCAMOUNTTAB (FIELDTYPE DECIMAL(9,2),CALCNUMAMOUNT DECIMAL(9,2))
	CREATE TABLE #EMPPAY(EMPNODE INT,Type int,SNO INT,Amount DECIMAL(9,2),CALCFILEDNAME VARCHAR(30),CALCNUMAMOUNT DECIMAL(9,2))
	DECLARE @EMPPAYALLOW TABLE(ID INT IDENTITY(1,1),EMPNODE INT,Type int,SNO INT,AMOUNT DECIMAL(9,2),CALCFILEDNAME VARCHAR(30),CALCNUMAMOUNT DECIMAL(9,2))
		--START:LOADING EMPPAY TABLE DETAILS
			DECLARE @I1 INT,@STR VARCHAR(MAX)
			SET @I1=1
			WHILE(@I1<=20)
			BEGIN
				SET @NUMFILEDNAME='Earning'+convert(varchar,@i1)
				SET @STR='INSERT INTO #EMPPAY 
								SELECT '+ CONVERT(VARCHAR,@EMPNODE) +' ,''1'','+ CONVERT(VARCHAR,@I1) +' ,'+ @NUMFILEDNAME +','''',0 FROM PAY_EMPPAY WITH(NOLOCK) WHERE EMPLOYEEID='+CONVERT(VARCHAR,@EmpNode)
				EXEC sp_executesql @STR
				SET @NUMFILEDNAME='Deduction'+convert(varchar,@i1)
				SET @STR='INSERT INTO #EMPPAY 
								SELECT '+ CONVERT(VARCHAR,@EMPNODE) +' ,''2'','+ CONVERT(VARCHAR,@I1) +' ,'+ @NUMFILEDNAME +','''',0 FROM PAY_EMPPAY WITH(NOLOCK) WHERE EMPLOYEEID='+CONVERT(VARCHAR,@EmpNode)
				EXEC sp_executesql @STR
			SET @I1=@I1+1
			END
		UPDATE #EMPPAY SET CALCFILEDNAME='DCCALCNUM'+CONVERT(VARCHAR,SNO)
		--END:LOADING EMPPAY TABLE DETAILS
	
						   					   
	
	
	
	SET @StartMonthName= CONVERT(VARCHAR,@Year)+'-' + DATENAME(MONTH,DATEADD(MONTH,@StartMonth,-1))+'-' +'01'
	SET @StartMonthName=CONVERT(DATETIME,@StartMonthName)
	 
	
--	 
DECLARE @TABPAYNUMDATACOLS TABLE(SNO INT IDENTITY(1,1),COLNAME NVARCHAR(25))
INSERT INTO @TABPAYNUMDATACOLS
SELECT NAME FROM sys.columns WHERE object_id=OBJECT_ID(N'[dbo].[PAY_docnumdata]') and name like ('DCCALCNUM%')
INTERSECT
SELECT NAME FROM sys.columns WHERE object_id=OBJECT_ID(N'[dbo].[PAY_docnumdata]') and name NOT like ('DCCALCNUMFC%')


DECLARE @IPAYNUMCOLS INT
DECLARE @IPAYNUMTABROWS INT
DECLARE @STRCOLS NVARCHAR(MAX),@STRCOLS1 NVARCHAR(MAX),@STRCOLS2 NVARCHAR(MAX),@STRCOLNAME NVARCHAR(25)
SET @STRCOLS=''
SET @STRCOLS1=''
SET @STRCOLS2=''
SET @IPAYNUMCOLS=1
SELECT @IPAYNUMTABROWS=COUNT(*) FROM @TABPAYNUMDATACOLS
	WHILE(@IPAYNUMCOLS<=@IPAYNUMTABROWS)
	BEGIN
		SELECT @STRCOLNAME=COLNAME FROM @TABPAYNUMDATACOLS WHERE SNO=@IPAYNUMCOLS
		IF(@STRCOLS='')
		BEGIN
			SET @STRCOLS=@STRCOLS + @STRCOLNAME	+' FLOAT'	
			SET @STRCOLS1=@STRCOLS1 + 'DN.'+@STRCOLNAME	+' FLOAT'	
			SET @STRCOLS2=@STRCOLS2 +'('+'''' + @STRCOLNAME +''',' + @STRCOLNAME  +')'
		END  
		ELSE 
		BEGIN
			SET @STRCOLS= @STRCOLS +  ','+ @STRCOLNAME	+' FLOAT'		
			SET @STRCOLS1= @STRCOLS1 +  ',DN.'+ @STRCOLNAME	+' FLOAT'
			SET @STRCOLS2=@STRCOLS2 +',('+'''' + @STRCOLNAME +''',' + @STRCOLNAME  +')'		
		END
	SET @IPAYNUMCOLS=@IPAYNUMCOLS+1
	END
PRINT 	@STRCOLS2

SET @strQry=''
--DROP TABLE #TAB3
--DROP TABLE #TAB1
CREATE TABLE #TAB3 (STARTDATE DATETIME)
SET @strQry='ALTER TABLE #TAB3 ADD '+ @STRCOLS +''
--PRINT (@strQry)
EXEC sp_executesql @STRQRY
SET @strQry=''
SET @strQry='INSERT INTO #TAB3
select td.dcalpha17,'+ CONVERT(NVARCHAR(max),@STRCOLS1)+'
 from inv_docdetails id,com_doctextdata td,com_docccdata cc,PAY_docnumdata dn
 where id.costcenterid=40054 and id.invdocdetailsid=td.invdocdetailsid and id.invdocdetailsid=dn.invdocdetailsid and id.invdocdetailsid=cc.invdocdetailsid
 and id.vouchertype=11 and cc.dcccnid51='+ CONVERT(NVARCHAR,@EmpNode) +''
-- PRINT (@strQry)
EXEC sp_executesql @STRQRY
 
CREATE TABLE #TAB1 (STARTDATE DATETIME,FIELDNAME VARCHAR(100),AMOUNT FLOAT,SNO INT)
SET @strQry=''
SET @strQry='INSERT INTO  #TAB1
 SELECT STARTDATE,CA.COLNAME,CA.COLVALUE,0 FROM #TAB3
 CROSS APPLY(VALUES '+ CONVERT(NVARCHAR(MAX), @STRCOLS2) +') AS CA(COLNAME,COLVALUE)'
--PRINT (@strQry)
EXEC sp_executesql @STRQRY

	UPDATE T SET T.SNO=T1.SNO FROM #EMPPAY T1 INNER JOIN #TAB1 T ON T1.CALCFILEDNAME=T.FIELDNAME AND T1.TYPE=1
	UPDATE T SET T.AMOUNT=T1.AMOUNT FROM #TAB1 T1 INNER JOIN @monthTable T ON T1.STARTDATE=T.STARTDATE AND T1.SNO=T.SNO
	UPDATE T SET T.AMOUNT=T1.AMOUNT FROM #EMPPAY T1 INNER JOIN @monthTable T ON  T1.SNO=T.SNO AND T.AMOUNT=0 AND T1.TYPE=1
	UPDATE T SET T.COMPONENTNAME=T1.SalaryBreakup FROM @monthTable T INNER JOIN  @TabMonthlyPayroll T1 ON T.SNO=T1.SNO AND T.COMPONENTID=T1.COMPONENTID 
	 --SELECT * FROM @TAB1
	 
	 select * from @TabMonthlyPayroll
	 select * from @monthTable
	 DROP TABLE #TAB3
	 DROP TABLE #TAB1
END
GO
