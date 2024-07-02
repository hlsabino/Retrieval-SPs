USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDiscountfields]
	@CCIDs [nvarchar](500),
	@BaccIds [nvarchar](500),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON;    
    --Declaration Section    
  DECLARE @Sql nvarchar(max)

	 set @Sql='SElect DiscountCommisionFld,DiscountInterestFld,CostCenterID,OnDiscount FROM ADM_DocumentTypes WITH(NOLOCK) Where CostCenterID in ('+@CCIDs+')'
	exec(@Sql)
     --Getting Costcenter Fields      
   set @Sql='
    SELECT  C.CostCenterID,C.CostCenterColID,C.SysColumnName,C.UserDefaultValue,DD.DebitAccount,DD.CreditAccount,DD.PostingType,DD.CrRefID,DD.CrRefColID
    ,CR.SysColumnName as CRSysColumnName,CR.sectionid CRSection,DD.DrRefID,DD.DrRefColID,DR.SysColumnName as DRSysColumnName
    ,DR.sectionid DrSection, DBACC.ACCOUNTNAME DebitAccountName ,  CRACC.ACCOUNTNAME CreditAccountName,C.CrFilter,C.DbFilter
   FROM ADM_CostCenterDef C WITH(NOLOCK)    
   JOIN ADM_DocumentTypes DT WITH(NOLOCK) ON DT.CostCenterID=C.CostCenterID 
   join (SElect DiscountCommisionFld,DiscountInterestFld,OnDiscount FROM ADM_DocumentTypes WITH(NOLOCK) Where CostCenterID in ('+@CCIDs+')) as dis  ON dis.OnDiscount=C.CostCenterID
  LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID       
  LEFT JOIN ADM_CostCenterDef DR WITH(NOLOCK) ON DR.CostCenterColID = DD.DrRefID and  DD.DrRefID IS NOT NULL
  LEFT JOIN ADM_CostCenterDef CR WITH(NOLOCK) ON CR.CostCenterColID = DD.CrRefID  and  DD.CrRefID IS NOT NULL  
  LEFT JOIN ACC_ACCOUNTS DBACC WITH(NOLOCK)  ON  DD.DebitAccount =  DBACC.ACCOUNTID
  LEFT JOIN ACC_ACCOUNTS CRACC WITH(NOLOCK) ON  DD.CreditAccount =  CRACC.ACCOUNTID
  WHERE  (C.SysColumnName =dis.DiscountCommisionFld or C.SysColumnName =dis.DiscountInterestFld) '  
exec(@Sql)


 set @Sql=' select AccountID,PDCDiscountAccount from ACC_Accounts WITH(NOLOCK)   
where AccountID in('+@BaccIds+')'
exec(@Sql)


SET NOCOUNT OFF;    
RETURN 1    
END TRY    
-- TEST   
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

SET NOCOUNT OFF      
RETURN -999       
END CATCH    
GO
