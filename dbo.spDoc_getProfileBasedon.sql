USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_getProfileBasedon]
	@DbAcc [bigint] = 0,
	@CrAcc [bigint] = 0,
	@incType [int],
	@where [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
  
BEGIN TRY    
SET NOCOUNT ON;  
	
	declare @sql nvarchar(max),@prfid bigint,@cnt int
	
	set @sql='select @prfid=max(ProfileID),@cnt=count(ProfileID) from Adm_MapCosts a with(nolock)'
	
	if(@incType=1)
	BEGIN
		set @sql=@sql+' left join acc_accounts db on a.AccountTypeID=db.AccountTypeID and db.AccountID='+convert(nvarchar(max),@DbAcc)
		set @sql=@sql+' left join acc_accounts Cr on a.AccountTypeID=Cr.AccountTypeID and Cr.AccountID='+convert(nvarchar(max),@CrAcc)
	END
	
	set @sql=@sql+'where 1=1'+@where
	--print @sql
	EXEC sp_executesql @sql,N'@prfid bigint output,@cnt bigint output',@prfid output,@cnt output
  
   if(@cnt=1 and @prfid is not null and @prfid>0)
	select * from Adm_DistributeCosts a with(nolock) where ProfileID=@prfid
   	
 
     
  
SET NOCOUNT OFF; 
RETURN 1  
END TRY  
BEGIN CATCH       
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999  AND LanguageID=@LangID 
  END  
 
SET NOCOUNT OFF    
RETURN -999     
END CATCH 




 
  
  
  
  
  
  
GO
