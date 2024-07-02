USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SaveDocumentFlowDef]
	@mode [int],
	@ProfileID [int] = 0,
	@ProfileName [nvarchar](max),
	@xmlP [nvarchar](max),
	@compGUID [nvarchar](max),
	@User [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
SET NOCOUNT ON;  
		declare @sql nvarchar(max),@Dt float,@XML xml

		if(@mode=1)
		BEGIN
			if(@ProfileID<=0)
			BEGIn
				select @ProfileID=isnull(max(ProfileID),0)+1 from ADM_DocFlowDef WITH(NOLOCK)
			END
			delete from ADM_DocFlowDef 
			where ProfileID=@ProfileID

			set @XML=@xmlP
			set @Dt=CONVERT(float,getdate())

			insert into ADM_DocFlowDef(ProfileID,ProfileName,CCID,Dimxml,UnitDimension,ContractDimension,TermDateFld,Action,Description,CompanyGUID,GUID,CreatedBy,CreatedDate,ModifiedBy,ModifiedDate)
		   select convert(nvarchar(max),@ProfileID),@ProfileName
		    ,X.value('@CCID','INT') 
		    ,X.value('@Dimxml','nvarchar(max)')
			,X.value('@UnitDimension','int')
			,X.value('@ContractDimension','int')
			,X.value('@TermDateFld','nvarchar(500)')
			,X.value('@Action','int')
			,X.value('@Label','nvarchar(max)')
			,@compGUID
			,newid()
			,@User
			,@Dt
			,@User
			,@Dt
		from @XML.nodes('/XML/Row') as Data(X)
		
		  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
		  WHERE ErrorNumber=100 AND LanguageID=@LangID    
	  END
	  ELSE if(@mode=2)
	  BEGIN		
		   select distinct ProfileID,[ProfileName] from ADM_DocFlowDef with(nolock)	  
	  END
	  ELSE if(@mode=3)
	  begin
		   select * from ADM_DocFlowDef a with(nolock) where ProfileID=@ProfileID
	  end
	 
	
COMMIT TRANSACTION   
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
ROLLBACK TRANSACTION  
SET NOCOUNT OFF    
RETURN -999     
END CATCH

GO
