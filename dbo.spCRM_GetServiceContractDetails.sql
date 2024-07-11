USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_GetServiceContractDetails]
	@SvcContractID [bigint] = 0,
	@RoleID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @HasAccess bit

		--SP Required Parameters Check
		IF (@SvcContractID < 1)
		BEGIN
			RAISERROR('-100',16,1)
		END

		--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,71,2)
		
		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		
SELECT     C.SvcContractID,CONVERT( Datetime, C.Date) AS [Date], C.DocID, C.StatusID, C.ContractTemplID, C.CustomerID, C.StartDate, C.EndDate, C.Description, C.Depth, C.ParentID, C.lft, C.rgt, C.IsGroup, C.CompanyGUID, 
                      C.GUID, C.CreatedBy, C.CreatedDate, C.ModifiedBy, C.ModifiedDate,S.ScheduleID,S.Name,S.StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,
				S.FreqRelativeInterval,S.FreqRecurrenceFactor, CONVERT(datetime,S.StartDate) as CStartDate ,case when S.EndDate='' then null else convert(Datetime, S.EndDate) end as CEndDate ,S.StartTime,S.EndTime
FROM         CRM_ServiceContract C
left join COM_Schedules S
on C.BillingScheduleID =S.ScheduleID 

WHERE     (SvcContractID = @SvcContractID)

CREATE  TABLE #TABLE (ContractLineID INT, ProductName NVARCHAR(300), SvcContractID BIGINT, ProductID BIGINT, LineNumber NVARCHAR(300), SerialNumber NVARCHAR(300), UnitsType NVARCHAR(300), AllottedUnits NVARCHAR(300), Price NVARCHAR(300), Discount NVARCHAR(300), 
                      NetPrice NVARCHAR(300), SvcFrequencyID NVARCHAR(300),  SvcFrequencyName NVARCHAR(300),   SvcStartDate datetime,   SvcEndDate datetime,  CompanyGUID  NVARCHAR(300), GUID  NVARCHAR(300),  CreatedBy  NVARCHAR(300),  CreatedDate  NVARCHAR(300), ModifiedBy  NVARCHAR(300),  ModifiedDate  NVARCHAR(300), ScheduleID  NVARCHAR(300)
                      , Name  NVARCHAR(300), StatusID  NVARCHAR(300),FreqType  NVARCHAR(300),FreqInterval  NVARCHAR(300),FreqSubdayType  NVARCHAR(300),FreqSubdayInterval  NVARCHAR(300),
				 FreqRelativeInterval  NVARCHAR(300), FreqRecurrenceFactor  NVARCHAR(300), StartDate datetime, EndDate Datetime, StartTime NVARCHAR(300), EndTime NVARCHAR(300), Employeeid NVARCHAR(300),   ResourceName NVARCHAR(300),  ResourceCode NVARCHAR(300) , voucherno NVARCHAR(300)
				 , invDocDetailID NVARCHAR(300),   CLStatus NVARCHAR(300),
				 Parts NVARCHAR(300), MaxAmount NVARCHAR(300))

INSERT INTO #TABLE
SELECT     C.ContractLineID, P.ProductName, C.SvcContractID, C.ProductID, C.LineNumber, C.SerialNumber, C.UnitsType, C.AllottedUnits, C.Price, C.Discount, 
                      C.NetPrice, C.SvcFrequencyID, C.SvcFrequencyName, CONVERT(datetime, C.SvcStartDate) AS SvcStartDate,   CONVERT(datetime, C.SvcEndDate) 
                      AS SvcEndDate, C.CompanyGUID, C.GUID, C.CreatedBy, C.CreatedDate, C.ModifiedBy, C.ModifiedDate,S.ScheduleID,S.Name,S.StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,
				S.FreqRelativeInterval,S.FreqRecurrenceFactor, CONVERT(datetime,S.StartDate) as StartDate ,case when S.EndDate='' then null else convert(Datetime, S.EndDate) end as EndDate ,S.StartTime,S.EndTime,C.Employeeid,R.USERNAME ResourceName,R.USERNAME ResourceCode ,C.voucherno,C.invDocDetailID ,C.StatusID  as CLStatus,
				C.Parts,C.MaxAmount
FROM         CRM_ContractLines AS C LEFT OUTER JOIN
                      INV_Product AS P ON P.ProductID = C.ProductID
                      left join COM_Schedules S
                      on S.ScheduleID=C.ScheduleID 
                      left join
                      ADM_USERS R ON C.Employeeid =R.USERID
 WHERE     (C.SvcContractID = @SvcContractID)
 
 
 ALTER TABLE #TABLE ADD ID INT IDENTITY(1,1),Consumed float default(0),Balance float default(0)
 DECLARE @COUNT INT,@I INT,@PRODUCT BIGINT,@SERIALNO NVARCHAR(300),@CONTRACTLINE INT,@SVCCONTRACT INT,@Consumed float,
 @ALLOTED float
 SELECT @I=1, @COUNT=COUNT(*) FROM #TABLE
 WHILE @I<=@COUNT
 BEGIN
 
 SELECT @ALLOTED=AllottedUnits,@PRODUCT=PRODUCTID,@SERIALNO=SerialNumber,@SVCCONTRACT=SvcContractID ,@CONTRACTLINE=ContractLineID FROM #TABLE WHERE ID=@I
   
   SELECT @Consumed=ISNULL(COUNT(*),0) FROM CRM_CASES WHERE SvcContractID=@SVCCONTRACT AND PRODUCTID=@PRODUCT AND
   SERIALNUMBER = @SERIALNO AND StatusID=431 AND ContractLineID=@CONTRACTLINE 
 
UPDATE #TABLE SET Consumed=@Consumed,Balance=@ALLOTED-@Consumed WHERE ID=@I
 SET @I=@I+1
 END
 SELECT * FROM #TABLE
 
 Select * from CRM_ServiceContractextd where SvcContractID=@SvcContractID
 

 
				
				
				

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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END

SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
