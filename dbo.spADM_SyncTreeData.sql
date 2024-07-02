USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SyncTreeData]
	@Type [int],
	@CCID [int],
	@StartID [bigint],
	@ModDate [float],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY
SET NOCOUNT ON
	
	declare @Tbl as table(ID bigint)
	
	if @Type=1 -- Get Tree Structure
	begin
		declare @CCTable nvarchar(20),@SQL nvarchar(max),@PK nvarchar(20)
		select @CCTable=TableName from adm_features with(nolock) where FeatureID=@CCID
		
		if @CCID=2
			set @PK='AccountID'
		else if @CCID=3
			set @PK='ProductID'
		else if @CCID=16
			set @PK='BatchID'
		else if @CCID>50000
			set @PK='NodeID'
		
		
		set @SQL='select TOP 1000 '+@PK+' ID,lft,rgt,ParentID,Depth from '+@CCTable+' with(nolock) where '+@PK+'>'+convert(nvarchar,@StartID)+' order by '+@PK
		
		select @CCTable TableName,@PK PK
		print(@SQL)
		exec(@SQL)
	end

	
	
COMMIT TRANSACTION
SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
