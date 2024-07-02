USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_AddDimensionNode]
	@Dimesion [int] = 0,
	@Text [nvarchar](max),
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [bigint],
	@ROLEID [bigint],
	@LangID [int] = 1,
	@IsOffline [bit]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION      
BEGIN TRY      
SET NOCOUNT ON;     
	--Declaration Section    
	DECLARE @CCStatusID FLOAT,@Code nvarchar(200),@CodePrefix nvarchar(200),@CodeNumber bigint,@DimesionNodeID bigint
	declare @Codetemp table (prefix nvarchar(100),number bigint, suffix nvarchar(100), code nvarchar(200),IsManualCode bit)
				
				set @CCStatusID = (select  statusid from com_status where costcenterid=@Dimesion and status = 'Active')
				
			
				if exists(SELECT CostCenterID FROM COM_CostCenterCodeDef WITH(nolock)
				WHERE CostCenterID=@Dimesion and IsName=0 and IsGroupCode=0 and isenable=1)
				BEGIN
						
						delete from @Codetemp
						insert into @Codetemp
						EXEC [spCOM_GetCodeData] @Dimesion,1,''  
						
						select @Code=code,@CodePrefix= prefix, @CodeNumber=@CodeNumber from @Codetemp
				END
				ELSE
				BEGIN
					set @Code=@Text
					set @CodePrefix=''
					set @CodeNumber=0
				END
				
				EXEC @DimesionNodeID = [dbo].[spCOM_SetCostCenter]
					@NodeID = 0,@SelectedNodeID = 1,@IsGroup = 0,
					@Code = @Code,
					@Name = @Text,
					@AliasName='',
					@PurchaseAccount=0,@SalesAccount=0,@StatusID=@CCStatusID,
					@CustomFieldsQuery=NULL,@AddressXML=NULL,@AttachmentsXML=NULL,
					@CustomCostCenterFieldsQuery=NULL,@ContactsXML=NULL,@NotesXML=NULL,
					@CostCenterID = @Dimesion,@CompanyGUID=@COMPANYGUID,@GUID='',@UserName=@UserName,@RoleID=1,@UserID=1,
					@CodePrefix=@CodePrefix,@CodeNumber=@CodeNumber,
					@CheckLink = 0,@IsOffline=@IsOffline
				
   
COMMIT TRANSACTION  
SET NOCOUNT OFF;     

SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID    

RETURN  @DimesionNodeID    
END TRY    
BEGIN CATCH      
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN       
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID    
 END    
 ELSE    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine    
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID    
 END    
ROLLBACK TRANSACTION    
SET NOCOUNT OFF      
RETURN -999       
END CATCH    
    
    
GO
