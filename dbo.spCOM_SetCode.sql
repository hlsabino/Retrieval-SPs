USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_SetCode]
	@CostCenterID [int],
	@ParentCode [nvarchar](200) = '',
	@CodeGenerated [nvarchar](200) OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;

		-- Declare the variable here
		DECLARE @CodeNumber BIGINT
		
		EXEC [spCOM_GetCode] @CostCenterID,@ParentCode, @CodeGenerated OUTPUT,@CodeNumber OUTPUT
	
		--Update sequence number
		UPDATE COM_CostCenterCodeDef
		SET CurrentCodeNumber=@CodeNumber
		WHERE CostCenterID=@CostCenterID
		
SET NOCOUNT OFF;
END
GO
