USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPay_SetDocumentFields]
	@Flag [int] = 0,
	@GradeID [int] = 0,
	@UserID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY      

	SET NOCOUNT ON;
	DECLARE @ColumnName nvarchar(200),@strQry nvarchar(max),@strUQry nvarchar(max),@strEQry nvarchar(max),@strDQry nvarchar(max),@strAAQry nvarchar(max)
	Declare @dcNum nvarchar(100),@dcCalcNum nvarchar(100),@dcCurrID nvarchar(100),@dcExchRT nvarchar(100),@dcCalcNumFC nvarchar(100)
	Declare @RC int,@i int,@J INT,@R INT,@CostCenterID INT,@MAXSNO INT,@K INT,@TRC INT,@X INT,@COUNT INT,@PAYROLLDATE DATETIME,@TYPEID INT,@CCID INT,@ResID BIGINT,@CostCenterName nvarchar(100)
	IF(@Flag=0)--PAYROLL DOCUMENTS
	BEGIN
		Declare @Tab table(ID INT IDENTITY(1,1),COSTCENTERID INT,NUMFILEDCOUNT INT)
		INSERT INTO @Tab SELECT DISTINCT ADF.COSTCENTERID,COUNT(SYSCOLUMNNAME) FROM ADM_COSTCENTERDEF ADF WITH(NOLOCK),ADM_RIBBONVIEW RV WITH(NOLOCK)
						 WHERE ADF.COSTCENTERID=RV.FEATUREID AND ADF.SysColumnName LIKE 'dcnum%' AND ADF.ISCOLUMNINUSE=1 AND RV.TABID=13 GROUP BY ADF.COSTCENTERID HAVING COUNT(ADF.SYSCOLUMNNAME)>9
		SELECT @R=count(*) FROM @TAB
		SET @J=1
		WHILE(@J<=@R)
		BEGIN
			SELECT @CostCenterID=COSTCENTERID FROM @TAB WHERE ID=@J
			SET @strQry=''
			SET @dcNum=''
			SET @dcCalcNum=''
			SET @dcCurrID=''
			SET @dcExchRT=''
			SET @dcCalcNumFC=''
			
			Select @RC=count(*) from adm_costcenterdef with(nolock) where CostCenterID=@CostCenterID  and SysColumnName like 'dcnum%' --And IsColumnInUse=1
			set @i=1
			WHILE(@i<=@RC)
			BEGIN
				SET @ColumnName='dcNum'+convert(varchar,@i)
				print @ColumnName
				IF NOT EXISTS(SELECT NAME FROM sys.columns WHERE name =@ColumnName AND OBJECT_ID=OBJECT_ID(N'Com_DocNumData'))
				BEGIN
								
					SET @dcNum='dcNum'+convert(varchar,@i)
					SET @dcCalcNum='dcCalcNum'+convert(varchar,@i)
					SET @dcCurrID='dcCurrID'+convert(varchar,@i)
					SET @dcExchRT='dcExchRT'+convert(varchar,@i)
					SET @dcCalcNumFC='dcCalcNumFC'+convert(varchar,@i)
					
					IF((SELECT COUNT(*) FROM ADM_COSTCENTERDEF WITH(NOLOCK) WHERE COSTCENTERID=@CostCenterID AND SYSCOLUMNNAME=@dcNum AND ISCOLUMNINUSE=1)>0)
					BEGIN
						SET @strQry=@strQry+'ALTER TABLE Com_DocNumData ADD '+ Convert(varchar,@dcNum)+' float null '
						SET @strQry=@strQry+'ALTER TABLE Com_DocNumData ADD '+ Convert(varchar,@dcCalcNum)+' float null '
						SET @strQry=@strQry+'ALTER TABLE Com_DocNumData ADD '+ Convert(varchar,@dcCurrID)+' int null '
						SET @strQry=@strQry+'ALTER TABLE Com_DocNumData ADD '+ Convert(varchar,@dcExchRT)+' float null ' 
						SET @strQry=@strQry+'ALTER TABLE Com_DocNumData ADD '+ Convert(varchar,@dcCalcNumFC)+' float null '

						SET @strQry=@strQry+'ALTER TABLE COM_DocNumData_History ADD '+ Convert(varchar,@dcNum)+' float null '
						SET @strQry=@strQry+'ALTER TABLE COM_DocNumData_History ADD '+ Convert(varchar,@dcCalcNum)+' float null '
						SET @strQry=@strQry+'ALTER TABLE COM_DocNumData_History ADD '+ Convert(varchar,@dcCurrID)+' int null '
						SET @strQry=@strQry+'ALTER TABLE COM_DocNumData_History ADD '+ Convert(varchar,@dcExchRT)+' float null ' 
						SET @strQry=@strQry+'ALTER TABLE COM_DocNumData_History ADD '+ Convert(varchar,@dcCalcNumFC)+' float null '

					END
				END
			SET @i=@i+1
			END
			IF(@strQry<>'')
			BEGIN
				print (@strQry)
				EXEC sp_executesql @strQry
			END
		SET @J=@J+1
		END
	END
	ELSE IF(@Flag=1)--PAYROLL CUSTOMIZATION
	BEGIN
		Declare @TAB1 table(ID INT IDENTITY(1,1),SNO INT,TYPE INT,PAYROLLDATE DATETIME)
		INSERT INTO @TAB1 
			SELECT MAX(SNO),TYPE,CONVERT(DATETIME,PAYROLLDATE) FROM COM_CC50054 WITH(NOLOCK) WHERE  CONVERT(DATETIME,PAYROLLDATE)=(SELECT MAX(CONVERT(DATETIME,PayrollDate)) FROM COM_CC50054 WITH(NOLOCK) WHERE GRADEID=@GradeID ) AND GRADEID=@GradeID GROUP BY TYPE,PAYROLLDATE
SELECT * FROM @TAB1
		SET @K=1
		SELECT @TRC=COUNT(*) FROM @TAB1
		WHILE(@K<=@TRC)
		BEGIN
		    SELECT @MAXSNO=SNO,@PAYROLLDATE=PAYROLLDATE,@TYPEID=TYPE FROM @TAB1 WHERE ID=@K	
		    SET @dcNum=''
			SET @dcCalcNum=''
			SET @dcCurrID=''
			SET @dcExchRT=''
			SET @dcCalcNumFC=''
			SET @strQry=''
			SET @strUQry=''
			SET @strEQry=''
			SET @strDQry=''
			SET @ColumnName=''
			SET @strAAQry=''
			SET @X=1
				WHILE(@X<=@MAXSNO)
				BEGIN
					--ADD EMPPAY EARNING COLUMNS
					IF(@TYPEID=1)
					BEGIN
						SET @ColumnName=''
						SET @ColumnName='Earning'+convert(varchar,@X)
						--print @ColumnName
						IF NOT EXISTS(SELECT NAME FROM sys.columns WHERE name =@ColumnName AND OBJECT_ID=OBJECT_ID(N'PAY_EmpPay'))
						BEGIN
							IF((SELECT COUNT(*) FROM COM_CC50054 WITH(NOLOCK) WHERE SNO=@X AND TYPE=1 AND CONVERT(DATETIME,PAYROLLDATE)=CONVERT(DATETIME,@PAYROLLDATE))>0)
							BEGIN
							PRINT 'TEST'
								SET @strEQry=@strEQry+' ALTER TABLE PAY_EmpPay ADD '+ Convert(varchar,@ColumnName)+' float not null default(0) '
								SET @strEQry=@strEQry+' ALTER TABLE PAY_EmpPay_History ADD '+ Convert(varchar,@ColumnName)+' float not null default(0) '
							END
						END
						IF NOT EXISTS(SELECT NAME FROM sys.columns WHERE name =@ColumnName AND OBJECT_ID=OBJECT_ID(N'PAY_EmpMonthlyArrAdjDetails'))
						BEGIN
							IF((SELECT COUNT(*) FROM COM_CC50054 WITH(NOLOCK) WHERE SNO=@X AND TYPE=1 AND CONVERT(DATETIME,PAYROLLDATE)=CONVERT(DATETIME,@PAYROLLDATE))>0)
							BEGIN
								SET @strAAQry=@strAAQry+' ALTER TABLE PAY_EmpMonthlyArrAdjDetails ADD '+ Convert(varchar,@ColumnName)+' float not null default(0) '
							END
						END
					END
					--ADD EMPPAY EARNING COLUMNS

					--ADD EMPPAY DEDUCTION COLUMNS
					IF(@TYPEID=2)
					BEGIN
						SET @ColumnName='Deduction'+convert(varchar,@X)
						--print @ColumnName
						IF NOT EXISTS(SELECT NAME FROM sys.columns WHERE name =@ColumnName AND OBJECT_ID=OBJECT_ID(N'PAY_EmpPay'))
						BEGIN
							IF((SELECT COUNT(*) FROM COM_CC50054 WITH(NOLOCK) WHERE SNO=@X AND TYPE=2 AND CONVERT(DATETIME,PAYROLLDATE)=@PAYROLLDATE)>0)
							BEGIN
								SET @strDQry=@strDQry+' ALTER TABLE PAY_EmpPay ADD '+ Convert(varchar,@ColumnName)+' float not null default(0) '
								SET @strDQry=@strDQry+' ALTER TABLE PAY_EmpPay_History ADD '+ Convert(varchar,@ColumnName)+' float not null default(0) '
							END
						END
						IF NOT EXISTS(SELECT NAME FROM sys.columns WHERE name =@ColumnName AND OBJECT_ID=OBJECT_ID(N'PAY_EmpMonthlyArrAdjDetails'))
						BEGIN
							IF((SELECT COUNT(*) FROM COM_CC50054 WITH(NOLOCK) WHERE SNO=@X AND TYPE=2 AND CONVERT(DATETIME,PAYROLLDATE)=@PAYROLLDATE)>0)
							BEGIN
								SET @strAAQry=@strAAQry+' ALTER TABLE PAY_EmpMonthlyArrAdjDetails ADD '+ Convert(varchar,@ColumnName)+' float not null default(0) '
							END
						END
					END
					--ADD EMPPAY DEDUCTION COLUMNS
					
					-----------------------
					--START ADD FLD IN CostCenterDef
					IF(@TYPEID=1 OR @TYPEID=2)
					BEGIN
						if(@TYPEID=1)
						BEGIN
							SET @CCID=405
							SET @CostCenterName='Payroll Earnings'
						END
						ELSE IF(@TYPEID=2)
						BEGIN
							SET @CCID=406
							SET @CostCenterName='Payroll Deductions'
						END
						------------START INSERT IN Payroll Earnings & Deductions-------
						SET @ColumnName='dcNum'+convert(varchar,@X)
						if not exists(select CostCenterID from ADM_CostCenterDef WITH(NOLOCK) where CostCenterID=@CCID and SysColumnName=@ColumnName)
						begin
							SET @dcNum='dcNum'+convert(varchar,@X)
							SET @dcCalcNum='dcCalcNum'+convert(varchar,@X)
							SET @dcExchRT='dcExchRT'+convert(varchar,@X)
							SET @dcCalcNumFC='dcCalcNumFC'+convert(varchar,@X)

							select @ResID=MAX([ResourceID])+1 from [com_languageresources] with(nolock)
			
							INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
							VALUES(@ResID,@dcNum,1,'English',@dcNum,'',NULL,'ADMIN',44,NULL,NULL,NULL)
							INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
							VALUES(@ResID,@dcNum,2,'Arabic',@dcNum,'',NULL,'ADMIN',44,NULL,NULL,NULL)

							INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
							VALUES(@ResID+1,@dcCalcNum,1,'English',@dcCalcNum,'',NULL,'ADMIN',44,NULL,NULL,NULL)
							INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
							VALUES(@ResID+1,@dcCalcNum,2,'Arabic',@dcCalcNum,'',NULL,'ADMIN',44,NULL,NULL,NULL)

							INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
							VALUES(@ResID+2,@dcExchRT,1,'English',@dcExchRT,'',NULL,'ADMIN',44,NULL,NULL,NULL)
							INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
							VALUES(@ResID+2,@dcExchRT,2,'Arabic',@dcExchRT,'',NULL,'ADMIN',44,NULL,NULL,NULL)

							INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
							VALUES(@ResID+3,@dcCalcNumFC,1,'English',@dcCalcNumFC,'',NULL,'ADMIN',44,NULL,NULL,NULL)
							INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
							VALUES(@ResID+3,@dcCalcNumFC,2,'Arabic',@dcCalcNumFC,'',NULL,'ADMIN',44,NULL,NULL,NULL)
			
							INSERT INTO [adm_costcenterdef] ([CostCenterID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])
							select @CCID,@ResID,@CostCenterName,'PAY_DocNumData',@dcNum,@dcNum,NULL,'FLOAT','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,1,NULL,NULL,NULL,NULL,NULL,1,NULL,'COMPANYGUID','EE2751B1-CA01-421E-9519-151B7655E3A1',NULL,'admin',	'40796.5280692515','ADMIN','42635.1385994599',0,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL
							union
							select @CCID,@ResID+1,@CostCenterName,'PAY_DocNumData',@dcCalcNum,@dcCalcNum,NULL,'FLOAT','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,1,NULL,NULL,NULL,NULL,NULL,1,NULL,'COMPANYGUID','EE2751B1-CA01-421E-9519-151B7655E3A1',NULL,'admin',	'40796.5280692515','ADMIN','42635.1385994599',0,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL
							union
							select @CCID,@ResID+2,@CostCenterName,'PAY_DocNumData',@dcExchRT,@dcExchRT,NULL,'FLOAT','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,1,NULL,NULL,NULL,NULL,NULL,1,NULL,'COMPANYGUID','EE2751B1-CA01-421E-9519-151B7655E3A1',NULL,'admin',	'40796.5280692515','ADMIN','42635.1385994599',0,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL
							union
							select @CCID,@ResID+3,@CostCenterName,'PAY_DocNumData',@dcCalcNumFC,@dcCalcNumFC,NULL,'FLOAT','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,1,NULL,NULL,NULL,NULL,NULL,1,NULL,'COMPANYGUID','EE2751B1-CA01-421E-9519-151B7655E3A1',NULL,'admin',	'40796.5280692515','ADMIN','42635.1385994599',0,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL
						end
						------------END INSERT IN Payroll Earnings & Deductions-------

						------------START INSERT IN Appraisals-------
						
						if(@TYPEID=1)
							SET @ColumnName='Earning'+convert(varchar,@X)
						ELSE IF(@TYPEID=2)
							SET @ColumnName='Deduction'+convert(varchar,@X)
						if not exists(select CostCenterID from ADM_CostCenterDef WITH(NOLOCK) where CostCenterID=409 and SysColumnName=@ColumnName)
						begin
							select @ResID=MAX([ResourceID])+1 from [com_languageresources] with(nolock)
			
							INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
							VALUES(@ResID,@ColumnName,1,'English',@ColumnName,'',NULL,'ADMIN',44,NULL,NULL,NULL)
							INSERT INTO [com_languageresources] ([ResourceID],[ResourceName],[LanguageID],[LanguageName],[ResourceData],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[FEATURE])
							VALUES(@ResID,@ColumnName,2,'Arabic',@ColumnName,'',NULL,'ADMIN',44,NULL,NULL,NULL)
			
							INSERT INTO [adm_costcenterdef] ([CostCenterID],[ResourceID],[CostCenterName],[SysTableName],[UserColumnName],[SysColumnName],[ColumnTypeSeqNumber],[UserColumnType],[ColumnDataType],[UserDefaultValue],[UserProbableValues],[ColumnOrder],[IsMandatory],[IsEditable],[IsVisible],[IsCostCenterUserDefined],[IsColumnUserDefined],[IsCCDeleted],[IsColumnDeleted],[ColumnCostCenterID],[ColumnCCListViewTypeID],[FetchMaxRows],[IsColumnGroup],[ColumnGroupNumber],[SectionSeqNumber],[SectionID],[SectionName],[RowNo],[ColumnNo],[ColumnSpan],[IsColumnInUse],[UIWidth],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[IsUnique],[IsForeignKey],[ParentCostCenterID],[ParentCostCenterColID],[IsValidReportBuilderCol],[ParentCostCenterSysName],[ParentCostCenterColSysName],[ParentCCDefaultColID],[LinkData],[LocalReference],[Decimal],[TextFormat],[Filter],[IsRepeat],[LastValueVouchers],[IsnoTab],[dependancy],[dependanton],[IsTransfer],[DbFilter],[CrFilter],[ShowInQuickAdd],[QuickAddOrder],[Calculate],[Cformula],[IsReEvaluate])
							select 409,@ResID,'Appraisals','PAY_EmpPay',@ColumnName,@ColumnName,NULL,'FLOAT','FLOAT','','',0,0,1,1,0,1,0,0,0,0,NULL,0,NULL,1,NULL,NULL,NULL,NULL,NULL,1,NULL,'COMPANYGUID','EE2751B1-CA01-421E-9519-151B7655E3A1',NULL,'admin',	'40796.5280692515','ADMIN','42635.1385994599',0,0,NULL,NULL,1,NULL,NULL,NULL,NULL,NULL,NULL,NULL,NULL,0,NULL,0,NULL,NULL,NULL,NULL,NULL,0,NULL,NULL,NULL,NULL
						end
						------------END INSERT IN Appraisals-------
		            END
					--END ADD FLD IN CostCenterDef
					-----------------------		
							
					SET @ColumnName='dcNum'+convert(varchar,@X)
					--print @ColumnName
					IF NOT EXISTS(SELECT NAME FROM sys.columns WHERE name =@ColumnName AND OBJECT_ID=OBJECT_ID(N'PAY_DocNumData'))
					BEGIN
						IF((SELECT COUNT(*) FROM COM_CC50054 WITH(NOLOCK) WHERE SNO=@X AND CONVERT(DATETIME,PAYROLLDATE)=@PAYROLLDATE)>0)
						BEGIN
							SET @dcNum='dcNum'+convert(varchar,@X)
							SET @dcCalcNum='dcCalcNum'+convert(varchar,@X)
							SET @dcExchRT='dcExchRT'+convert(varchar,@X)
							SET @dcCalcNumFC='dcCalcNumFC'+convert(varchar,@X)
						
							SET @strQry=@strQry+'ALTER TABLE PAY_DocNumData ADD '+ Convert(varchar,@dcNum)+' float null '
							SET @strQry=@strQry+'ALTER TABLE PAY_DocNumData ADD '+ Convert(varchar,@dcCalcNum)+' float null '
							SET @strQry=@strQry+'ALTER TABLE PAY_DocNumData ADD '+ Convert(varchar,@dcExchRT)+' float null ' 
							SET @strQry=@strQry+'ALTER TABLE PAY_DocNumData ADD '+ Convert(varchar,@dcCalcNumFC)+' float null '

							SET @strQry=@strQry+'ALTER TABLE PAY_DocNumData_History ADD '+ Convert(varchar,@dcNum)+' float null '
							SET @strQry=@strQry+'ALTER TABLE PAY_DocNumData_History ADD '+ Convert(varchar,@dcCalcNum)+' float null '
							SET @strQry=@strQry+'ALTER TABLE PAY_DocNumData_History ADD '+ Convert(varchar,@dcExchRT)+' float null ' 
							SET @strQry=@strQry+'ALTER TABLE PAY_DocNumData_History ADD '+ Convert(varchar,@dcCalcNumFC)+' float null '
							
							--UPDATING ADM_COSTCENTERDEF ISCOLUMNINUSE COLUMN FOR COSTCENTERID 40054
							SET @strUQry=@strUQry+'UPDATE ADM_COSTCENTERDEF SET ISCOLUMNINUSE=1 WHERE COSTCENTERID=40054 AND USERCOLUMNNAME=N'''+ Convert(varchar,@dcNum)+''' '+ CHAR(13)
						END
					END
				SET @X=@X+1	
				END
				PRINT @strEQry
				IF(@strQry<>'')
				BEGIN
					print (@strQry)
					EXEC sp_executesql @strQry
					PRINT (@strUQry)
					EXEC sp_executesql @strUQry
				END
				IF(@strEQry<>'')
				BEGIN
				print (@strEQry)
					EXEC sp_executesql @strEQry
				END
				IF(@strDQry<>'')
				BEGIN
				--print (@strDQry)
					EXEC sp_executesql @strDQry
				END
				IF(@strAAQry<>'')
				BEGIN
				print (@strAAQry)
					EXEC sp_executesql @strAAQry
				END
		SET @K=@K+1
		END
	END
	
COMMIT TRANSACTION
SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=100 AND LanguageID=@LangID    

SET NOCOUNT OFF;      
RETURN  1    
END TRY    
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
ROLLBACK TRANSACTION  
SET NOCOUNT OFF      
RETURN -999       
END CATCH
GO
