USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_HoldRelQueue]
	@COSTCENTERID [int],
	@NodeID [int] = 0,
	@Wid [int],
	@WLvl [int],
	@date [datetime],
	@remarks [nvarchar](max),
	@IsHold [bit],
	@CompanyGUID [nvarchar](500),
	@RoleID [int] = 1,
	@UserID [int] = 1,
	@UserName [nvarchar](500),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY        
SET NOCOUNT ON;   
	
	declare @sql nvarchar(max),@st int
	
	
	if(@IsHold=1)
		set @st=438
	else
		set @st=499	
	 
	insert into COM_Approvals(CCID,CCNODEID,Date,Remarks,StatusID,UserID,WorkFlowLevel,DocDetID,CompanyGUID,GUID,CreatedBy,CreatedDate)
	select @COSTCENTERID,@NodeID,convert(float,@date),@remarks,@st,@UserID,@WLvl,0,@CompanyGUID,newid(),@UserName,convert(float,getdate())
	 
	
	if(@COSTCENTERID=95)
	BEGIN
		if(@IsHold=1)
			set @sql='update REN_Contract set WorkFlowQueue='''+@UserName+''' where ContractID='+convert(nvarchar(max),@NodeID)
		ELSE
			set @sql='update REN_Contract set WorkFlowQueue='''' where ContractID='+convert(nvarchar(max),@NodeID)
		exec(@sql)
	END
	
	
COMMIT TRANSACTION      
SET NOCOUNT OFF;    

if(@IsHold=1)    
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
	WHERE ErrorNumber=-160 AND LanguageID=@LangID      
ELSE
    SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)       
	WHERE ErrorNumber=-161 AND LanguageID=@LangID      
	  
RETURN 1      
END TRY      
BEGIN CATCH        
 --Return exception info [Message,Number,ProcedureName,LineNumber]        
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
