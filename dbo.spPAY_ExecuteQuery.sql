USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_ExecuteQuery]
	@EmployeeID [int] = 0,
	@EditSeqNo [int] = 0,
	@EffectFrom [varchar](20) = null,
	@Query [nvarchar](max),
	@Flag [int] = 0,
	@userid [int] = 1,
	@langid [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN

DECLARE @HistoryStatus NVARCHAR(300),@Audit NVARCHAR(100)

SELECT @Audit=Value FROM COM_CostCenterPreferences WITH(NOLOCK) WHERE CostCenterID=50051 and Name='AuditTrial'

IF (ISNULL(@Flag,0)=1)
	BEGIN
			EXEC sp_executesql @Query

		if(@EditSeqNo=0)
			set @HistoryStatus='Add'
		else
			set @HistoryStatus='Update'

			IF(@Audit IS NOT NULL AND @Audit='True')
			BEGIN
				INSERT INTO PAY_EmpPay_History
				SELECT 50051,@HistoryStatus,* FROM PAY_EmpPay WHERE EmployeeID=@EmployeeID AND EffectFrom=CONVERT(DATETIME,@EffectFrom)
			END
	END
ELSE IF (ISNULL(@Flag,0)=2)
	BEGIN

		IF(@Audit IS NOT NULL AND @Audit='True')
		BEGIN
			IF EXISTS(SELECT SeqNo FROM PAY_EMPPAY WHERE EmployeeID=@EmployeeID AND SeqNo<>@EditSeqNo)
			BEGIN
				INSERT INTO PAY_EmpPay_History
				SELECT 50051,'Delete',* FROM PAY_EmpPay WHERE EmployeeID=@EmployeeID AND SeqNo=@EditSeqNo
			END
		END

		EXEC sp_executesql @Query

	END
END
GO
