USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetContractsMonthlyIncome]
	@ContractIDs [nvarchar](max),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON    

	declare @table table(ID nvarchar(50))  
	
	insert into @table  
	exec SPSplitString @ContractIDs,','  
	
	select c.* from com_ccccdata c with(nolock)
	join @table t on c.nodeid=t.ID
	where costcenterid=95 	
		
	select a.contractID, a.sno,month(DocDate) m ,Year(DocDate) y,sum(f.amount) amount,f.DebitAccount,f.creditAccount,f.costcenterid
	 from ren_contract a WITH(NOLOCK)
	 join @table t on a.contractID=t.ID
	join REN_CONTRACTDOCMAPPING m WITH(NOLOCK) on a.contractid=m.contractid
	join acc_docdetails f WITH(NOLOCK) on m.docid=f.docid
	where  m.doctype=5 
	group by a.contractID, a.sno,f.DebitAccount,f.creditAccount,f.costcenterid,month(DocDate),Year(DocDate)
	order by a.contractID,y,m
	
	

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
