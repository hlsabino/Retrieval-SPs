USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_CopyPayrollStructure]
	@FromGradeID [int],
	@ToGradeID [int],
	@FromPayrollMonth [datetime],
	@ToPayrollMonth [datetime],
	@CopyOtherGrades [int],
	@UserName [nvarchar](100),
	@RoleID [int],
	@UserID [int],
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION    
BEGIN TRY    
	SET NOCOUNT ON;
	
	DECLARE @SysDateTime FLOAT,@I INT,@TRC INT,@GRADEID INT,@Audit NVARCHAR(100),@HistoryStatus NVARCHAR(300)
	SET @SysDateTime=CONVERT(FLOAT,GETDATE())
	DECLARE @TABCPGRADES TABLE(ID INT IDENTITY(1,1),GRADEID INT)

	SELECT @Audit=ISNULL(Value,'False') FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='AllowAuditTrailinCustomizePayroll'
	
	IF(@CopyOtherGrades=1)
	BEGIN
		IF ((SELECT COUNT(*) FROM INV_DocDetails WITH(NOLOCK) WHERE CostCenterID=40054 AND CONVERT(DATETIME,DueDate)=CONVERT(DATETIME,@ToPayrollMonth))>0)
		BEGIN
			RAISERROR('-562',16,1) 
		END
		ELSE
		BEGIN
			DELETE FROM COM_CC50054 WHERE CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@ToPayrollMonth)
			
			INSERT INTO COM_CC50054(GradeID, PayrollDate, Type, SNo, ComponentID, Formula, AddToNet,ShowInDuesEntry,CalculateArrears,CalculateAdjustments, FieldType, Applicable,Behaviour, MaxOTHrs, ROff, TaxMap, Expression, DrAccount, CrAccount, Percentage, MaxLeaves, AtATime, CarryForward, IncludeRExclude, CompanyGUID, GUID, Description, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Message, Action, MaxCarryForwardDays, MaxEncashDays, EncashFormula, LeaveErrorMessage,LEThresholdLimit,LEDaysField,LEAmountField,LeaveOthFeatures,CarryForwardExpireDays)
			SELECT GradeID, CONVERT(FLOAT,CONVERT(DATETIME,@ToPayrollMonth)), Type, SNo, ComponentID, Formula, AddToNet,ShowInDuesEntry,CalculateArrears,CalculateAdjustments, FieldType, Applicable,Behaviour, MaxOTHrs, ROff, TaxMap, Expression, DrAccount, CrAccount, Percentage, MaxLeaves, AtATime, CarryForward, IncludeRExclude, 'admin', 'GUID', Description, @UserName, @SysDateTime, @UserName, @SysDateTime, Message, Action, MaxCarryForwardDays, MaxEncashDays, EncashFormula, LeaveErrorMessage,LEThresholdLimit,LEDaysField,LEAmountField,LeaveOthFeatures,CarryForwardExpireDays
			FROM COM_CC50054 WITH(NOLOCK)
			WHERE CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@FromPayrollMonth)
			
			DELETE FROM PAY_PayrollPT WHERE CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@ToPayrollMonth)
			INSERT INTO PAY_PayrollPT(PayrollDate, CostCenterID, NodeID, FromSlab, ToSlab, Amount,Formula, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
			SELECT CONVERT(FLOAT,CONVERT(DATETIME,@ToPayrollMonth)), CostCenterID, NodeID, FromSlab, ToSlab, Amount,Formula, @UserName, @SysDateTime, @UserName, @SysDateTime
			FROM PAY_PayrollPT WITH(NOLOCK)
			WHERE CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@FromPayrollMonth)
		END
	END
	ELSE IF(@CopyOtherGrades=2)
	BEGIN
		IF ((SELECT COUNT(*) FROM INV_DocDetails WITH(NOLOCK) WHERE CostCenterID=40054 AND CONVERT(DATETIME,DueDate)=CONVERT(DATETIME,@ToPayrollMonth))>0)
		BEGIN
			RAISERROR('-562',16,1) 
		END
		ELSE
		BEGIN
			INSERT INTO @TABCPGRADES SELECT NodeID FROM COM_CC50053 WITH(NOLOCK) WHERE StatusID=254 
			SET @I=1
			SET @TRC=(SELECT COUNT(*) FROM @TABCPGRADES)
			WHILE(@I<=@TRC)
			BEGIN
				SELECT @GRADEID=GRADEID FROM @TABCPGRADES WHERE ID=@I
				IF (@GRADEID<>@FromGradeID)
				BEGIN
					DELETE FROM COM_CC50054 WHERE CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@FromPayrollMonth) AND GradeID=@GRADEID
					INSERT INTO COM_CC50054(GradeID, PayrollDate, Type, SNo, ComponentID, Formula, AddToNet,ShowInDuesEntry,CalculateArrears,CalculateAdjustments, FieldType, Applicable,Behaviour, MaxOTHrs, ROff, TaxMap, Expression, DrAccount, CrAccount, Percentage, MaxLeaves, AtATime, CarryForward, IncludeRExclude, CompanyGUID, GUID, Description, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Message, Action, MaxCarryForwardDays, MaxEncashDays, EncashFormula, LeaveErrorMessage,LEThresholdLimit,LEDaysField,LEAmountField,LeaveOthFeatures,CarryForwardExpireDays)
					SELECT @GRADEID, CONVERT(FLOAT,CONVERT(DATETIME,@ToPayrollMonth)), Type, SNo, ComponentID, Formula, AddToNet,ShowInDuesEntry,CalculateArrears,CalculateAdjustments, FieldType, Applicable,Behaviour, MaxOTHrs, ROff, TaxMap, Expression, DrAccount, CrAccount, Percentage, MaxLeaves, AtATime, CarryForward, IncludeRExclude, 'admin', 'GUID', Description, @UserName, @SysDateTime, @UserName, @SysDateTime, Message, Action, MaxCarryForwardDays, MaxEncashDays, EncashFormula, LeaveErrorMessage,LEThresholdLimit,LEDaysField,LEAmountField,LeaveOthFeatures,CarryForwardExpireDays
					FROM COM_CC50054 WITH(NOLOCK)
					WHERE CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@FromPayrollMonth) AND GradeID=@FromGradeID
				END
			SET @I=@I+1	
			END
			DELETE FROM PAY_PayrollPT WHERE CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@ToPayrollMonth)
			INSERT INTO PAY_PayrollPT(PayrollDate, CostCenterID, NodeID, FromSlab, ToSlab, Amount,Formula, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
			SELECT CONVERT(FLOAT,CONVERT(DATETIME,@ToPayrollMonth)), CostCenterID, NodeID, FromSlab, ToSlab, Amount,Formula, @UserName, @SysDateTime, @UserName, @SysDateTime
			FROM PAY_PayrollPT WITH(NOLOCK)
			WHERE CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@FromPayrollMonth)
		END
	END
	ELSE
	BEGIN

		IF EXISTS (SELECT * FROM [COM_CC50054] with(nolock) WHERE [GradeID]=@GradeID AND CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@ToPayrollMonth))
		BEGIN
			set @HistoryStatus='Update'
		END
		ELSE
		BEGIN
			SET @HistoryStatus='Add'
		END
		
		DELETE FROM COM_CC50054 WHERE GradeID=@ToGradeID AND CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@ToPayrollMonth)
		INSERT INTO COM_CC50054(GradeID, PayrollDate, Type, SNo, ComponentID, Formula, AddToNet,ShowInDuesEntry,CalculateArrears,CalculateAdjustments, FieldType, Applicable,Behaviour, MaxOTHrs, ROff, TaxMap, Expression, DrAccount, CrAccount, Percentage, MaxLeaves, AtATime, CarryForward, IncludeRExclude, CompanyGUID, GUID, Description, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate, Message, Action, MaxCarryForwardDays, MaxEncashDays, EncashFormula, LeaveErrorMessage,LEThresholdLimit,LEDaysField,LEAmountField,LeaveOthFeatures,CarryForwardExpireDays)
		SELECT @ToGradeID, CONVERT(FLOAT,CONVERT(DATETIME,@ToPayrollMonth)), Type, SNo, ComponentID, Formula, AddToNet,ShowInDuesEntry,CalculateArrears,CalculateAdjustments, FieldType, Applicable,Behaviour, MaxOTHrs, ROff, TaxMap, Expression, DrAccount, CrAccount, Percentage, MaxLeaves, AtATime, CarryForward, IncludeRExclude, 'admin', 'GUID', Description, @UserName, @SysDateTime, @UserName, @SysDateTime, Message, Action, MaxCarryForwardDays, MaxEncashDays, EncashFormula, LeaveErrorMessage,LEThresholdLimit,LEDaysField,LEAmountField,LeaveOthFeatures,CarryForwardExpireDays
		FROM COM_CC50054 WITH(NOLOCK)
		WHERE GradeID=@FromGradeID AND CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@FromPayrollMonth)
		

		--INSERT INTO HISTROY
		IF(@Audit IS NOT NULL AND @Audit='True')
		BEGIN    
			insert into [COM_CC50054_History]         
			select 50054,@HistoryStatus,* FROM COM_CC50054 WITH(NOLOCK) WHERE [GradeID]=@ToGradeID AND CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@FromPayrollMonth)
		END
		--END INTO HISTROY
		
		IF(@ToGradeID=1)
		BEGIN
			DELETE FROM PAY_PayrollPT WHERE CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@ToPayrollMonth)
			INSERT INTO PAY_PayrollPT(PayrollDate, CostCenterID, NodeID, FromSlab, ToSlab, Amount,Formula, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
			SELECT CONVERT(FLOAT,CONVERT(DATETIME,@ToPayrollMonth)), CostCenterID, NodeID, FromSlab, ToSlab, Amount,Formula, @UserName, @SysDateTime, @UserName, @SysDateTime
			FROM PAY_PayrollPT WITH(NOLOCK)
			WHERE CONVERT(DATETIME,PayrollDate)=CONVERT(DATETIME,@FromPayrollMonth)
		END
	
	END
	
	COMMIT TRANSACTION
	--ROLLBACK TRANSACTION
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID 
	SET NOCOUNT OFF; 
	RETURN 1   
END TRY    
BEGIN CATCH    
	--SELECT ERROR_MESSAGE() AS ErrorMessage  
	SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	ROLLBACK TRANSACTION  
	SET NOCOUNT OFF    
	RETURN -999     
END CATCH

--gO
-- spPAY_CopyPayrollStructure 
-- 1
-- ,43
-- ,'01/Apr/2019'
-- ,'01/Apr/2019'
-- ,0
-- ,'admin'
-- ,1
-- ,1
-- ,1
GO
