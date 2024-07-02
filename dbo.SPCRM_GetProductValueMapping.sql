USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[SPCRM_GetProductValueMapping]
	@CostCenterID [int],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON;

	declare @Value nvarchar(500) 
	select @Value=Value from Com_CostCenterPreferences with(nolock) 
	where name='ProductValueMapping' and CostCenterID=@CostCenterID

	if(@Value is not null and @Value<>'')
	begin
		declare @table1 table(ColID nvarchar(50))
		DECLARE @DATA NVARCHAR(MAX)  
		insert into @table1
		exec SPSplitString @Value,';'

		IF @CostCenterID=86
		BEGIN
			select (SELECT SYSCOLUMNNAME FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=115 AND  CostCenterColID= reverse(parsename(replace(reverse(ColID),'-','.'),1)))
			as SOURCE,
			(SELECT SYSCOLUMNNAME FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND  CostCenterColID=reverse(parsename(replace(reverse(ColID),'-','.'),2))) 
			AS DESTINATION from (select ColID from @table1) as [Table]
		END
		ELSE IF @CostCenterID=89
		BEGIN
			select (SELECT SYSCOLUMNNAME FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=154 AND  CostCenterColID= reverse(parsename(replace(reverse(ColID),'-','.'),1)))
			as SOURCE,
			(SELECT SYSCOLUMNNAME FROM ADM_CostCenterDef WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND  CostCenterColID=reverse(parsename(replace(reverse(ColID),'-','.'),2))) 
			AS DESTINATION from (select ColID from @table1) as [Table]
		END
	end

SET NOCOUNT OFF;
RETURN 1
END TRY
BEGIN CATCH  
	IF ERROR_NUMBER()=50000
		BEGIN
			SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
