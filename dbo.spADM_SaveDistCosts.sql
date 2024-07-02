USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SaveDistCosts]
	@mode [int],
	@ProfileID [bigint] = 0,
	@ProfileName [nvarchar](max),
	@xml [nvarchar](max),
	@dims [nvarchar](max),
	@dimxml [nvarchar](max),
	@compGUID [nvarchar](max),
	@User [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
		declare @sql nvarchar(max)
		if(@mode=1)
		BEGIN
			if(@ProfileID<=0)
			BEGIn
				select @ProfileID=isnull(max(ProfileID),0)+1 from Adm_DistributeCosts WITH(NOLOCK)
			END
			delete from Adm_DistributeCosts 
			where ProfileID=@ProfileID
			
		   set @sql='insert into Adm_DistributeCosts('+@dims+'ProfileID,ProfileName,Amount,[Percent],CompanyGUID,GUID,CreatedBy,CreatedDate)
		   select '+@dimxml+convert(nvarchar(max),@ProfileID)+','''+@ProfileName+''',X.value(''@Amount'',''float''),X.value(''@Percent'',''float''),'''+@compGUID+''',newid(),'''+@User+''',convert(float,getdate())
		   from @xml.nodes(''/XML/Row'') as DATA(X) '
	  END
	  ELSE if(@mode=2)
	  BEGIN		  
		   set @sql='
		   delete from Adm_MapCosts
		   where CostID not in(select X.value(''@CostID'',''BIGINT'') from @xml.nodes(''/XML/Row'') as DATA(X) where X.value(''@CostID'',''BIGINT'')>0)
		   
		   insert into Adm_MapCosts('+@dims+'ProfileID,AccountID,AccountTypeID,CompanyGUID,GUID,CreatedBy,CreatedDate)
		   select '+@dimxml+'X.value(''@ProfileID'',''BIGINT''),X.value(''@AccountID'',''BIGINT''),X.value(''@AccountTypeID'',''INT''),'''+@compGUID+''',newid(),'''+@User+''',convert(float,getdate())
		   from @xml.nodes(''/XML/Row'') as DATA(X) where X.value(''@CostID'',''BIGINT'')=0
		   
		   update Adm_MapCosts
		   set ProfileID=X.value(''@ProfileID'',''BIGINT''),AccountID=X.value(''@AccountID'',''BIGINT''),
		   AccountTypeID=X.value(''@AccountTypeID'',''INT'')'+@ProfileName+'
		   from @xml.nodes(''/XML/Row'') as DATA(X) where X.value(''@CostID'',''BIGINT'')>0
		   and X.value(''@CostID'',''BIGINT'')=CostID '
	  END 
	   print @sql
	   EXEC sp_executesql @sql,N'@xml xml',@xml
   
     
COMMIT TRANSACTION   
SET NOCOUNT OFF;
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
  WHERE ErrorNumber=100 AND LanguageID=@LangID    
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
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH 




 
  
  
  
  
  
  
GO
