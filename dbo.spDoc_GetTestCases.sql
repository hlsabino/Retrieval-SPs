USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_GetTestCases]
	@ProductID [bigint],
	@costCenterID [int],
	@tableName [nvarchar](100),
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON  

	declare @sql nvarchar(max)

	set @sql='
	declare @prntid bigint
	
	select  a.TestCaseID,b.Name,b.IsGroup,Min,Max,Iteration,sample,b.ParentID,TestType,ProbableValues,Variance,SampleType,RetestDays
	into #testTable
	from INV_ProductTestcases a with(nolock)
	join '+@tableName+' b with(nolock)  on a.TestCaseID=b.NodeID   
	where DocumentID='+convert(nvarchar,@costCenterID)+' and ProductID='+convert(nvarchar,@ProductID)+'
 	
	if not exists(select * from #testTable)
	BEGIN	
		select @prntid=ParentID from INV_Product with(nolock) where  ProductID='+convert(nvarchar,@ProductID)+'
		while(@prntid>0)
		BEGIN
			insert into #testTable
			select  a.TestCaseID,b.Name,b.IsGroup,Min,Max,Iteration,sample,b.ParentID,TestType,ProbableValues,Variance,SampleType,RetestDays
			from INV_ProductTestcases a with(nolock)
			join '+@tableName+' b with(nolock)  on a.TestCaseID=b.NodeID   
			where DocumentID='+convert(nvarchar,@costCenterID)+' and ProductID=@prntid
			
			if not exists(select * from #testTable)
				select @prntid=ParentID from INV_Product with(nolock) where  ProductID=@prntid
			else
				break;	
		END
	END                    

	select * from #testTable

	drop table #testTable '
	
	exec(@sql)

		 

SET NOCOUNT OFF;     
RETURN 1
END TRY 
BEGIN CATCH    
  --Return exception info [Message,Number,ProcedureName,LineNumber]    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
  END  
  ELSE IF ERROR_NUMBER()=547  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
   WHERE ErrorNumber=-110 AND LanguageID=@LangID  
  END  
  ELSE IF ERROR_NUMBER()=2627  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
   WHERE ErrorNumber=-116 AND LanguageID=@LangID  
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
  END  
SET NOCOUNT OFF    
RETURN -999     
END CATCH  
	  
GO
