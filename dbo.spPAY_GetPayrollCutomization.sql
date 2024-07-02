USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_GetPayrollCutomization]
	@GradeID [int],
	@PayrollDate [datetime],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
	SELECT * FROM [COM_CC50054] WITH(NOLOCK) WHERE [GradeID]=@GradeID AND [PayrollDate]=@PayrollDate
	
	SELECT REPLACE(RIGHT(CONVERT(VARCHAR(11), Convert(DATETIME,MAX([PayrollDate])), 106), 8), ' ', '-') PayrollDate,isnull(MAX(SNO),0) SNO FROM [COM_CC50054] WITH(NOLOCK)
	
	SELECT * FROM PAY_PayrollPT WITH(NOLOCK) WHERE [PayrollDate]=@PayrollDate

	
END
GO
