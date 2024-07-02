USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetPaymentScreenDef]
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY         
SET NOCOUNT ON  

	declare @ccID bigint

  SELECT  l.ResourceData [Text],ISNULL([Value],DefaultValue) Value,P.Name [DBText]       
   FROM COM_CostCenterPreferences P WITH(NOLOCK)         
   LEFT JOIN COM_LanguageResources L ON L.ResourceID=P.ResourceID and LanguageID=@LangID      
   WHERE P.CostCenterID=106 or (CostCenterID=92 and name='LinkDocument')
   
   
   SELECT  @ccID=Value FROM COM_CostCenterPreferences P WITH(NOLOCK)         
   WHERE P.CostCenterID=106 and Name='PaymentTermDocumentName' and ISNUMERIC([Value])=1
          
        
   select CostcenterID,SysColumnName,CostCenterColID,b.ResourceData,UserColumnType,ColumnDataType from ADM_CostCenterDef a
	join COM_LanguageResources b on a.ResourceID=b.ResourceID and b.LanguageID=@LangID
	where costcenterid =@ccID  and IsColumnInUse=1 and SysColumnName not like 'dcCalc%'
		 and SysColumnName not like 'dcCurrID%'
		 and SysColumnName not like 'dcExchRT%'
		 
	
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS          
ErrorLine        
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID        
 END        
ROLLBACK TRANSACTION        
SET NOCOUNT OFF          
RETURN -999           
END CATCH     
GO
