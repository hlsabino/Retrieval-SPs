USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_DeleteAllDocuments]
	@DeletePrefix [bit] = 1,
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;    
	--Declaration Section    
	DECLARE @HasAccess bit,@DocID INT,@PrefValue NVARCHAR(500)
	DECLARE @sql nvarchar(max),@tablename nvarchar(200),@CurrentNo INT,@return_value int
	declare @AccDocID INT,@DELETECCID INT    
	DECLARE @CostCenterID INT,@VoucherNo NVARCHAR(80),@J INT,@JCNT INT,@NodeID INT
	
	--------------------------------------------------------------------------------
	CREATE TABLE #x (drop_script NVARCHAR(MAX),create_script NVARCHAR(MAX))
	DECLARE @drop   NVARCHAR(MAX) = N'',@create NVARCHAR(MAX) = N''

	SELECT @drop += N' ALTER TABLE ' + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) + ' DROP CONSTRAINT ' + QUOTENAME(fk.name)
	FROM sys.foreign_keys AS fk
	INNER JOIN sys.tables AS ct ON fk.parent_object_id = ct.[object_id]
	INNER JOIN sys.schemas AS cs ON ct.[schema_id] = cs.[schema_id]

	INSERT #x(drop_script) 
	SELECT @drop

	SELECT @create += N' ALTER TABLE ' + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) + case when fk.is_not_trusted = 0 then ' WITH CHECK ' ELSE ' WITH NOCHECK ' END
	+ ' ADD CONSTRAINT ' + QUOTENAME(fk.name) + ' FOREIGN KEY (' + STUFF((SELECT ',' + QUOTENAME(c.name)
	FROM sys.columns AS c 
	INNER JOIN sys.foreign_key_columns AS fkc ON fkc.parent_column_id = c.column_id AND fkc.parent_object_id = c.[object_id]
	WHERE fkc.constraint_object_id = fk.[object_id]
	ORDER BY fkc.constraint_column_id 
	FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') + ') REFERENCES ' + QUOTENAME(rs.name) + '.' + QUOTENAME(rt.name) + '(' + STUFF((SELECT ',' + QUOTENAME(c.name)
	FROM sys.columns AS c 
	INNER JOIN sys.foreign_key_columns AS fkc ON fkc.referenced_column_id = c.column_id AND fkc.referenced_object_id = c.[object_id]
	WHERE fkc.constraint_object_id = fk.[object_id]
	ORDER BY fkc.constraint_column_id 
	FOR XML PATH(N''), TYPE).value(N'.[1]', N'nvarchar(max)'), 1, 1, N'') + ')'

	FROM sys.foreign_keys AS fk
	INNER JOIN sys.tables AS rt ON fk.referenced_object_id = rt.[object_id]
	INNER JOIN sys.schemas AS rs ON rt.[schema_id] = rs.[schema_id]
	INNER JOIN sys.tables AS ct ON fk.parent_object_id = ct.[object_id]
	INNER JOIN sys.schemas AS cs ON ct.[schema_id] = cs.[schema_id]
	WHERE rt.is_ms_shipped = 0 AND ct.is_ms_shipped = 0

	UPDATE #x 
	SET create_script = @create

	EXEC sp_executesql @drop
	----------------------------------------
	
	DECLARE @TblLink As TABLE(ID INT IDENTITY(1,1),LinkDimension INT,TableName NVARCHAR(100),FName NVARCHAR(100))
	DECLARE @UpdSQL NVARCHAR(MAX),@sTables NVARCHAR(MAX),@sTab NVARCHAR(100),@sCCIds NVARCHAR(MAX),@sInserts NVARCHAR(MAX)
	DECLARE @Dimesion INT,@I INT,@CNT INT,@FName NVARCHAR(100),@sIDReSeed NVARCHAR(MAX),@sDelete NVARCHAR(MAX)
	DECLARE @StatusID INT
		
	SET @UpdSQL=''
	SET @sTables=''
	SET @sTab=''
	SET @sCCIds=''
	SET @sInserts=''
	SET @FName=''
	SET @sIDReSeed=''
	SET @sDelete=''

	INSERT INTO @TblLink
	select DISTINCT a.PrefValue,b.TableName,b.Name 
	from COM_DocumentPreferences a with(nolock)
	JOIN ADM_Features b with(nolock) on b.FeatureID=a.PrefValue
	where PrefName='DocumentLinkDimension' and PrefValue is not null and PrefValue<>'' and ISNUMERIC(PrefValue)=1 and CONVERT(int,PrefValue)>50000
	SET @CNT=@@ROWCOUNT
	SET @I=1 
	
	WHILE(@I<=@CNT)
	BEGIN
		select @Dimesion=LinkDimension,@sTab=TableName,@FName=FName from @TblLink where ID=@I
		SET @StatusID=0
		SELECT @StatusID=StatusID FROM [COM_Status] WITH(NOLOCK) WHERE CostCenterID=@Dimesion AND [Status]='Active'
		IF(@StatusID IS NULL OR @StatusID=0)
			SELECT @StatusID=CONVERT(INT,UserDefaultValue) FROM ADM_CostCenterDef WITH(NOLOCK) where CostCenterID=@Dimesion AND SysColumnName='StatusID'
		print CONVERT(NVARCHAR,@Dimesion)
		----
		if(LEN(@sCCIds)>0)
			SET @sCCIds+=','
		SET @sCCIds+=CONVERT(NVARCHAR,@Dimesion)
		print @sCCIds
		----
		if(LEN(@sTables)>0)
			SET @sTables+=','
		SET @sTables+= '''' + @sTab+ ''''
		print @sTables
		----
		if(LEN(@UpdSQL)>0)
			SET @UpdSQL+=','
		SET @UpdSQL+='dcCCNID'+CONVERT(NVARCHAR,(@Dimesion-50000))+'=1'
		--print @UpdSQL
		----
		--SET @sDelete+=' DELETE FROM '+@sTab +' WHERE NodeID>2 '

		--SET @sIDReSeed+=' DBCC CHECKIDENT('''+@sTab +''',RESEED,1)  '

		SET @sInserts+='
SET IDENTITY_INSERT ['+@sTab+'] ON
INSERT INTO ['+@sTab+'] ([NodeID],[Code],[Name],[AliasName],[StatusID],[Depth],[ParentID],[lft],[rgt],[IsGroup],[CreditDays],[CreditLimit],[PurchaseAccount],[SalesAccount],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DebitDays],[DebitLimit],[CodePrefix],[CodeNumber],[GroupSeqNoLength],[CurrencyID])VALUES(0,'''+@FName+''','''+@FName+''','''+@FName+''','+CONVERT(NVARCHAR,@StatusID)+',0,0,0,0,1,0,0.000000000000000e+000,0,0,''GUID'',''GUID'',NULL,''ADMIN'',2.200000000000000e+001,NULL,NULL,0,0.000000000000000e+000,NULL,0,0,NULL)
INSERT INTO ['+@sTab+'] ([NodeID],[Code],[Name],[AliasName],[StatusID],[Depth],[ParentID],[lft],[rgt],[IsGroup],[CreditDays],[CreditLimit],[PurchaseAccount],[SalesAccount],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DebitDays],[DebitLimit],[CodePrefix],[CodeNumber],[GroupSeqNoLength],[CurrencyID])VALUES(1,'''+@FName+''','''+@FName+''','''+@FName+''','+CONVERT(NVARCHAR,@StatusID)+',1,2,2,3,0,0,0.000000000000000e+000,0,0,''GUID'',''GUID'',NULL,''ADMIN'',2.200000000000000e+001,NULL,NULL,0,0.000000000000000e+000,NULL,0,0,NULL)
INSERT INTO ['+@sTab+'] ([NodeID],[Code],[Name],[AliasName],[StatusID],[Depth],[ParentID],[lft],[rgt],[IsGroup],[CreditDays],[CreditLimit],[PurchaseAccount],[SalesAccount],[CompanyGUID],[GUID],[Description],[CreatedBy],[CreatedDate],[ModifiedBy],[ModifiedDate],[DebitDays],[DebitLimit],[CodePrefix],[CodeNumber],[GroupSeqNoLength],[CurrencyID])VALUES(2,'''+@FName+''','''+@FName+''','''+@FName+''','+CONVERT(NVARCHAR,@StatusID)+',0,0,1,4,1,0,0.000000000000000e+000,0,0,''GUID'',''GUID'',NULL,''admin'',2.200000000000000e+001,NULL,NULL,0,0.000000000000000e+000,NULL,0,0,NULL)
SET IDENTITY_INSERT ['+@sTab+'] OFF

INSERT INTO COM_CCCCData ([CostCenterID], [NodeID], [CreatedBy],[CreatedDate], [CompanyGUID],[GUID])  
Select '+CONVERT(NVARCHAR,@Dimesion)+',NodeID,''admin'',1,''COMPANYGUID'',''GUID'' from '+@sTab+' with(nolock) WHERE NODEID>=0
		
'
		--print @sInserts
		SET @I=@I+1
	END

	IF(LEN(@UpdSQL)>0)
	BEGIN
		------ Updating COM_DocCCData to Default Value 1
		SET @UpdSQL='UPDATE a SET '+ @UpdSQL +' FROM COM_DocCCData a WITH(NOLOCK)'
		print @UpdSQL
		EXEC sp_executesql @UpdSQL

		-------- Deleting Dimension Data
		--print @sDelete
		--EXEC sp_executesql @sDelete

		-------- Truncating Dimension Tables
		SET @sTables=' and object_id IN(Select object_Id from sys.Tables where Name IN('+ @sTables+' )) '
		print @sTables
		exec sp_MSforeachtable
		@command1='TRUNCATE TABLE ?',
		@whereand=@sTables

		------ Deleting from other Tables related to the above Dimensions
		SET @sCCIds=' DELETE a FROM COM_CCCCDATA a WITH(NOLOCK) WHERE a.CostCenterID IN('+@sCCIds+') 
					  DELETE a FROM COM_CostCenterCostCenterMap a WITH(NOLOCK) WHERE a.ParentCostCenterID IN('+@sCCIds+') 
					  DELETE a FROM COM_Notes a WITH(NOLOCK) WHERE a.FeatureID IN('+@sCCIds+') 
					  DELETE a FROM COM_Address a WITH(NOLOCK) WHERE a.FeatureID IN('+@sCCIds+') 
					  DELETE a FROM COM_Address_History a WITH(NOLOCK) WHERE a.FeatureID IN('+@sCCIds+') 
					  DELETE a FROM COM_Files a WITH(NOLOCK) WHERE a.FeatureID IN('+@sCCIds+') 
					  '
		print @sCCIds
		EXEC sp_executesql @sCCIds

		------ Inserting Default Records
		print @sInserts
		EXEC sp_executesql @sInserts

		------ Reseeding Identity Column
		--EXEC sp_executesql @sIDReSeed

	END

	--------------------------------------------------------------------------------

	DELETE a FROM COM_Notes a WITH(NOLOCK) WHERE FeatureID between 40000 and 50000
	DELETE a FROM COM_Files a WITH(NOLOCK) WHERE FeatureID between 40000 and 50000
	
	if exists (select * from sys.tables with(nolock) where name='CRM_Activities')
	begin
		SET @sql='DELETE a FROM CRM_Activities a WITH(NOLOCK) WHERE CostCenterID between 40000 and 50000' 
		EXEC sp_executesql @sql
	end
	
	--CASE DELETE
	if exists (select * from sys.tables with(nolock) where name='CRM_Cases')
	begin
		SET @sql='declare @Tblcase table(ID int identity(1,1),CaseID INT)
		INSERT INTO @Tblcase(CaseID)
		select CaseID FROM CRM_Cases with(nolock) where SvcContractID IS NOT NULL AND SvcContractID>0
		declare @I int,@CNT int,@NodeID int
		select @I=1,@CNT=count(*) FROM @Tblcase
		WHILE(@I<=@CNT)
		BEGIN
			SELECT @NodeID=CaseID FROM @Tblcase WHERE ID=@I
			exec spCRM_DeleteCase @CASEID=@NodeID,@USERID=1,@LangID=1,@RoleID=1
			SET @I=@I+1
		END'
		EXEC sp_executesql @sql
	end
	
	if (@DeletePrefix is not null and @DeletePrefix=1)	
	BEGIN
		update a 
		set CurrentCodeNumber= (case when CodeNumberRoot>0 then CodeNumberRoot-1 else 0 end)
		FROM COM_CostCenterCodeDef  a WITH(NOLOCK)
		where CostCenterID between 40000 and 50000
		
		delete a 
		from COM_CostCenterCodeDef a WITH(NOLOCK)
		where CostCenterID between 40000 and 50000 and codeprefix<>''
	END
	
	exec sp_MSforeachtable
	@command1='TRUNCATE TABLE ?',
	@whereand=' and object_id IN(Select object_Id from sys.Tables where Name IN(
	''COM_DocCCData'',''COM_DocNumData'',''PAY_DocNumData'',''COM_DocTextData'',''COM_DocPayTerms''
	,''COM_Approvals'',''com_pospaymodes'',''INV_SerialStockProduct'',''INV_TempInfo'',''INV_BinDetails'',''INV_DocExtraDetails'',''COM_Billwise'',''COM_BillWiseNonAcc''
	,''ACC_DocDetails_History_ATUser'',''INV_DocDetails_History_ATUser'',''COM_DocCCData_History'',''COM_DocNumData_History''
	,''COM_DocTextData_History'',''ACC_DocDetails_History'',''INV_DocDetails_History'',''COM_BillwiseHistory''
	,''COM_DocID'',''ACC_DocDetails'',''INV_DocDetails'',''COM_DocAddressData'',''COM_LCBills'',''COM_DocDenominations'',''COM_ChequeReturn'',''REN_ContractDocMapping''
	,''COM_BiddingDocs''))'

	DELETE a FROM INV_BatchDetails a WITH(NOLOCK) WHERE InvDocDetailsID>0
	
	--- Executing Create Foreign Keys Script
	EXEC sp_executesql @create;
	DROP TABLE #x 
			 
COMMIT TRANSACTION
--ROLLBACK TRANSACTION

SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID  
RETURN 1
END TRY
BEGIN CATCH  
	if(@return_value=-999)
	return -999
	--Return exception info Message,Number,ProcedureName,LineNumber  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
