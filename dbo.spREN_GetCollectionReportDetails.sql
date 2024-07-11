USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetCollectionReportDetails]
	@PropertyID [bigint],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
    
BEGIN TRY     
SET NOCOUNT ON    
    
       declare @val nvarchar(50),@PrefValue nvarchar(50),@tablename nvarchar(50),@sql nvarchar(max),@nodeid bigint
     SELECT @val=Value from  COM_CostCenterPreferences WHERE CostCenterID=495    
     and Name='MapReport'
     
     if(@val is not null and @val<>'' )
     begin
		select * from dbo.ADM_RevenUReports where ReportID=@val
     end
     
     select name,value from com_costcenterpreferences where costcenterid=92 and Name='LinkDocument'
     
      select @PrefValue=value from com_costcenterpreferences where costcenterid=92 and Name='LinkDocument'
    
     if(@PropertyID>0 and @PrefValue is not null and @PrefValue<>'')
     begin
		select @tablename=tablename from ADM_Features where FeatureID=@PrefValue
		
		select @sql='select @nodeid=nodeid from '+@tablename+' where name='''+(select Name from REN_Property where NodeID=@PropertyID)+''''
	 
		exec sp_executesql @sql,N'@nodeid bigint output',@nodeid output
		
		select @nodeid
     end
     
      
    
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS      
ErrorLine    
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
    
SET NOCOUNT OFF      
RETURN -999       
END CATCH 

GO
