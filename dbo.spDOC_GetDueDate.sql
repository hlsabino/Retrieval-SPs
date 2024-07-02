USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDueDate]
	@AccountID [bigint],
	@LocationID [bigint] = 0,
	@DivisionID [bigint] = 0,
	@DimensionID [bigint] = 0,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON
BEGIN TRY 

	declare @LocWise bit,@DivWise bit,@SQL nvarchar(max),@DimWise BIGINT,@NodeID bigint,@tbl nvarchar(max)
	
	if (select count(value) from adm_globalpreferences WITH(NOLOCK)
		where name in('EnableLocationWise','LW CreditDebit') and value='true')=2
		set @LocWise=1
	else
		set @LocWise=0
	  
	if (select count(value) from adm_globalpreferences WITH(NOLOCK)
		where name in('EnableDivisionWise','DW CreditDebit') and value='true')=2
			set @DivWise=1
	else
		set @DivWise=0
		
	SELECT @DimWise=ISNULL(CONVERT(BIGINT,value),0) from adm_globalpreferences WITH(NOLOCK) where name='DimWiseCreditDebit'
		
	
	--Credit Limit for the account
	IF(@LocWise=1 OR @DivWise=1 OR @DimWise>0)
	BEGIN
		SET @SQL='SELECT CreditDays,CrOptionID,DebitDays , DrOptionID
		 FROM Acc_CreditDebitAmount WITH(NOLOCK)
				  where AccountID='+CONVERT(NVARCHAR,@AccountID)
		
		if(@LocWise=1)
		BEGIN
			SET @SQL=@SQL+' and LocationID='+CONVERT(NVARCHAR,@LocationID)			
		END
		
		if(@DivWise=1)
		BEGIN
			SET @SQL=@SQL+' and DivisionID='+CONVERT(NVARCHAR,@DivisionID)			
		END
		
		IF(@DimWise>0)
		BEGIN
			SET @SQL=@SQL+' and DimensionID='+CONVERT(NVARCHAR,@DimensionID)		
		END
		
		SET @SQL='if exists('+@SQL+') 
			'+@SQL+' 
		 else 
			SELECT CreditDays,CrOptionID,DebitDays , DrOptionID FROM ACC_ACCOUNTS WITH(NOLOCK)
			WHERE AccountID = '+CONVERT(NVARCHAR,@AccountID)
		exec (@SQL)

	END
	ELSE
	BEGIN
		SELECT CreditDays,CrOptionID,DebitDays , DrOptionID FROM ACC_ACCOUNTS WITH(NOLOCK)
		WHERE AccountID = @AccountID
	END
 
 
 
 
 SET NOCOUNT OFF;  
 
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
 SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
