USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spAdm_SetReportDims]
	@PrefValue [nvarchar](max),
	@Columns [nvarchar](max),
	@RemoveColumns [nvarchar](max),
	@UpdateQuery [nvarchar](max),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON      
      
	--Declaration Section      
	Declare @Table nvarchar(max),@SQL nvarchar(max),@Primarycol nvarchar(100)
	
	if(@Columns<>'')
	BEGIN
		SET @SQL=' Alter Table Inv_DocDetails '+@Columns
		exec(@SQL)
		SET @SQL=' Alter Table Acc_DocDetails '+@Columns
		exec(@SQL)
	END
	
	if(@RemoveColumns<>'')
	BEGIN
		SET @SQL=' Alter Table Inv_DocDetails '+@RemoveColumns
		exec(@SQL)
		SET @SQL=' Alter Table Acc_DocDetails '+@RemoveColumns
		exec(@SQL)
	END
	
	if(@UpdateQuery<>'')
	BEGIN
		SET @SQL=' Update Inv_DocDetails set '+@UpdateQuery+' from com_docccdata a with(nolock) where a.InvDocDetailsID=Inv_DocDetails.InvDocDetailsID'
		
		exec(@SQL)
	
		SET @SQL=' Update Acc_DocDetails set '+@UpdateQuery+' from com_docccdata a with(nolock) where a.AccDocDetailsID=Acc_DocDetails.AccDocDetailsID
		Update Acc_DocDetails set '+@UpdateQuery+' from com_docccdata a with(nolock) where a.InvDocDetailsID=Acc_DocDetails.InvDocDetailsID'
		exec(@SQL)
	END
	
	update adm_globalpreferences
	set value=@PrefValue,Description=@UpdateQuery
	where name='ReportDims'

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)
 WHERE ErrorNumber=100 AND LanguageID=@LangID

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

SET NOCOUNT OFF        
RETURN -999         
END CATCH       
GO
