USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRPT_GetNodeNames]
	@CCID [int],
	@NodeID [nvarchar](max),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

	declare @SQL nvarchar(max),@PK nvarchar(20),@TblName nvarchar(20),@Name nvarchar(20)
    set @PK=null
    select @TblName=TableName from ADM_Features with(nolock) where FeatureID=@CCID
    
    SELECT @PK=COL_NAME(ic.object_id, ic.column_id)
	FROM sys.indexes AS i 
	INNER JOIN sys.index_columns AS ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
    WHERE (i.is_primary_key = 1) and OBJECT_NAME(ic.object_id)=@TblName           
    
    if @CCID=2
        set @Name='AccountName'
	else if @CCID=3
		set @Name='ProductName'
	else if @CCID=16
		set @Name='BatchNumber'
	else if @CCID=44
	begin
		set @PK='NodeID'
		set @Name='Name'
	end
	else if @CCID=65
		set @Name='ContactName'
	else if @CCID=72
		set @Name='AssetName'
	else if @CCID=73
		set @Name='CaseNumber'
	else if @CCID=76
		set @Name='BOMName'
	else if @CCID=83
		set @Name='CustomerName'
	else if @CCID=86
		set @Name='Code'
	else if @CCID=88
		set @Name='Name'
	else if @CCID=89
		set @Name='Code'
	else if @CCID=92
		set @Name='Name'
	else if @CCID=93
		set @Name='Name'
	else if @CCID=94
		set @Name='TenantCode'
	else if @CCID=95
		set @Name='ContractNumber'
	else if @CCID=101
		set @Name='BudgetName'
	else if @CCID=110
		set @Name='ContactPerson'
	else if @CCID=113
		set @Name='Status'
    else if @CCID>50000
        set @Name='Name'
	else if @CCID=300
    begin
		set @PK='CostCenterID'
        set @Name='DocumentName'
    end

--	set rowcount 15
	if @PK is not null
	begin
		set @SQL=''
		if CHARINDEX(',',@NodeID)>0
			set @SQL='select '+@Name+' Name,'+@PK+' PK from '+@TblName+' WITH(NOLOCK) where '+@PK+' IN ('+@NodeID+')'
		else
			set @SQL='select '+@Name+' Name,'+@PK+' PK from '+@TblName+' WITH(NOLOCK) where '+@PK+'='+@NodeID
		--print(@SQL)
		EXEC(@SQL)
	end
	else
		select 0 Name where 1!=1
	
 
SET NOCOUNT OFF;  
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
