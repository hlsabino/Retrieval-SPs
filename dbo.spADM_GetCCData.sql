USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetCCData]
	@ccid [int],
	@Where [nvarchar](max),
	@join [nvarchar](max),
	@TypeWhere [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON

	declare @sql nvarchar(max),@table nvarchar(50)

	select @table=TableName from ADM_Features WITH(NOLOCK)
	where FeatureID=@ccid

	if (@ccid > 50000)
	BEGIN
		set @sql = 'Select a.NodeID ID,a.Code,a.name ,f.GUID+''.''+f.FileExtension FileName from ' + @table + ' a WITH(NOLOCK) 
				 JOIN COM_CCCCData CC WITH(NOLOCK) ON CC.COSTCENTERID=' +convert(nvarchar(max),@ccid)+ ' AND CC.NODEID= a.NODEID 
				  left join COM_Files f WITH(NOLOCK) on f.FeaturePK=a.NodeID and f.FeatureID=' +convert(nvarchar(max),@ccid)+ ' and f.IsDefaultImage=1 '+@join
	   
		if (@Where<>'')
			set @sql =@sql+ ' where ' + @Where
	END
	else if (@ccid = 3)
	BEGIN
			set @sql = 'Select p.ProductID ID,p.ProductCode Code,p.ProductName name,p.IsGroup,f.GUID+''.''+f.FileExtension FileName
					from inv_product p WITH(NOLOCK) 
					JOIN COM_CCCCData CC WITH(NOLOCK) ON CC.COSTCENTERID=3 AND CC.NODEID= p.ProductID 
					left join COM_Files f WITH(NOLOCK) on f.FeaturePK=p.ProductID and f.FeatureID=3 and f.IsDefaultImage=1 '+@join

			 if (@Where<>'')
			set @sql =@sql+ ' where ' + @Where

	 
	END

	exec(@sql)
	
		
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
