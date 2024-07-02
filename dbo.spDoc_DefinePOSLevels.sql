USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_DefinePOSLevels]
	@ProfileID [bigint] = 0,
	@Type [int],
	@Levels [nvarchar](max),
	@CompanyGUID [varchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
	
	declare @xml xml,@name nvarchar(200)
	
	if(@Type=1)
	begin
		select distinct ProfileID,ProfileName from ADM_POSLevelsProfiles with(nolock)
		
		select FeatureID,Name from ADM_Features with(nolock) where IsEnabled=1 and FeatureID>50000
	end
	ELSE if(@Type=2)
	begin
		select * from ADM_POSLevelsProfiles with(nolock) where ProfileID=@ProfileID
		order by [Level]
	end
	ELSE if(@Type=3)
	begin
		delete from ADM_POSLevelsProfiles where ProfileID=@ProfileID
	end
	else if(@Type=4)
	begin
		set @xml=@Levels
		select @name=A.value('@ProfileName','Nvarchar(200)')
		from @xml.nodes('/XML/Row') as DATA(A) 
		
		if exists(select ProfileID from ADM_POSLevelsProfiles with(nolock) where ProfileName=@name
		and ProfileID<>@ProfileID)
			raiserror('-112',16,1)
			
		if(@ProfileID=0 or @ProfileID=-1)		
			select @ProfileID=isnull(MAX(ProfileID),0)+1 from ADM_POSLevelsProfiles with(nolock)
		else
			delete from ADM_POSLevelsProfiles where ProfileID=@ProfileID
		
		
		INSERT INTO [ADM_POSLevelsProfiles]([ProfileID],[ProfileName],[Level],[CCID]
           ,[Map],[ParentCCID],[Filter],[CompanyGUID],[GUID],[CreatedBy],[CreatedDate])
		select @ProfileID,A.value('@ProfileName','Nvarchar(200)'),A.value('@Level','BIGINT'),A.value('@CCID','BIGINT')
		,A.value('@Map','BIGINT'),A.value('@ParentCCID','BIGINT'),A.value('@Filter','Nvarchar(max)'),@CompanyGUID,newid(),@UserName,convert(float,GETDATE())
		from @xml.nodes('/XML/Row') as DATA(A) 
		
	end

   
     
COMMIT TRANSACTION   
SET NOCOUNT OFF;
	if(@Type=4)
	  SELECT ErrorMessage,ErrorNumber,@ProfileID ProfileID FROM COM_ErrorMessages WITH(nolock)       
	  WHERE ErrorNumber=100 AND LanguageID=@LangID    
    ELSE
	  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
	  WHERE ErrorNumber=102 AND LanguageID=@LangID    
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
