USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spRen_GetUnitReservationDetails]
	@UnitID [int],
	@Date [datetime] = NULL,
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN
SET NOCOUNT ON;

	Declare @TabUnits Table(ID INT ,UDate datetime,DayName nvarchar(100),UnitID INT,UnitName nvarchar(300),TenantName nvarchar(300),Availability nvarchar(100),UTime nvarchar(50))
	Declare @UnitName nvarchar(300)
	Declare @MonthStart datetime,@MonthEnd	datetime
	
	Select @UnitName=Name from  REN_Units where UnitID=@UnitID
	SET @MonthStart= CONVERT(VARCHAR,YEAR(CONVERT(DATETIME,@Date)))+'-' + DATENAME(MONTH,DATEADD(MONTH,month(convert(datetime,@Date)),-1))+'-' +'01'	
	set @MonthStart=@MonthStart+ ' 12:00:00.000'
	SET @MonthEnd=  dateadd(m,1,@monthStart-1)

	;WITH DATERANGE AS
			(
			SELECT @MonthStart AS DT,1 AS ID
			UNION ALL
			SELECT DATEADD(DD,1,DT),DATERANGE.ID+1 FROM DATERANGE WHERE ID<=DATEDIFF("d",convert(varchar,@MonthStart,101),convert(varchar,@MonthEnd,101))
			)
			
	INSERT INTO @TabUnits
		SELECT ROW_NUMBER() OVER (ORDER BY DT) AS ID,DT AS UDATE,DATENAME(DW,DT) AS DAY,@UnitID,@UnitName,'','','' FROM DATERANGE
					
					
		DECLARE @RC AS INT,@IC AS INT,@TRC AS INT,@DTT AS DATETIME,@Tenant nvarchar(300),@UST AS DATETIME,@UET AS DATETIME
		SET @IC=1
		SELECT @TRC=COUNT(*) FROM @TabUnits
		WHILE(@IC<=@TRC)
		BEGIN
			SET @Tenant=''
			SELECT @DTT=UDate FROM @TabUnits WHERE ID=@IC

		    SELECT @Tenant=Isnull(T.FirstName,'')+' '+Isnull(T.MiddleName,'' )+' '+Isnull(T.LastName,''),@UST=Convert(DateTime,R.StartDate),@UET=Convert(DateTime,R.EndDate) FROM REN_Contract R,REN_Tenant T 
					WHERE R.TenantID=T.TenantID and R.UnitId=@UnitID and convert(datetime,@DTT) between CONVERT(DATETIME,R.StartDate) and CONVERT(DATETIME,R.EndDate)

  		    UPDATE @TabUnits SET TenantName=ISNULL(@Tenant,''),Availability=Case ISNULL(@Tenant,'') WHEN '' THEN 'Available' ELSE 'Not Available' END WHERE CONVERT(DATETIME,UDate)=CONVERT(DATETIME,@DTT)  							 

  		    IF(CONVERT(NVARCHAR,CONVERT(DATETIME,@DTT),106)=CONVERT(NVARCHAR,CONVERT(DATETIME,@UST),106))
  				UPDATE @TabUnits SET UTime=CONVERT(NVARCHAR,CONVERT(DATETIME,@UST),108) WHERE CONVERT(NVARCHAR,CONVERT(DATETIME,UDate),106)=CONVERT(NVARCHAR,CONVERT(DATETIME,@UST),106)
  		    IF(CONVERT(NVARCHAR,CONVERT(DATETIME,@DTT),106)=CONVERT(NVARCHAR,CONVERT(DATETIME,@UET),106))
				UPDATE @TabUnits SET UTime=CONVERT(NVARCHAR,CONVERT(DATETIME,@UET),108) WHERE CONVERT(NVARCHAR,CONVERT(DATETIME,UDate),106)=CONVERT(NVARCHAR,CONVERT(DATETIME,@UET),106)

  		    SET @Tenant=''

  		    SELECT @Tenant='Reserved',@UST=Convert(DateTime,StartDate),@UET=Convert(DateTime,EndDate) FROM REN_Quotation
					WHERE CostCenterID=129 and UnitID=@UnitID and convert(datetime,@DTT) between CONVERT(DATETIME,StartDate) and CONVERT(DATETIME,EndDate)

			IF(ISNULL(@Tenant,'')<>'')
  				UPDATE @TabUnits SET TenantName=ISNULL(@Tenant,''),Availability=Case ISNULL(@Tenant,'') WHEN '' THEN 'Available' ELSE 'Not Available' END WHERE CONVERT(DATETIME,UDate)=CONVERT(DATETIME,@DTT) AND ISNULL(TenantName,'')=''

 		    IF(CONVERT(NVARCHAR,CONVERT(DATETIME,@DTT),106)=CONVERT(NVARCHAR,CONVERT(DATETIME,@UST),106))
  				UPDATE @TabUnits SET UTime=CONVERT(NVARCHAR,CONVERT(DATETIME,@UST),108) WHERE CONVERT(NVARCHAR,CONVERT(DATETIME,UDate),106)=CONVERT(NVARCHAR,CONVERT(DATETIME,@UST),106)
  		    IF(CONVERT(NVARCHAR,CONVERT(DATETIME,@DTT),106)=CONVERT(NVARCHAR,CONVERT(DATETIME,@UET),106))
				UPDATE @TabUnits SET UTime=CONVERT(NVARCHAR,CONVERT(DATETIME,@UET),108) WHERE CONVERT(NVARCHAR,CONVERT(DATETIME,UDate),106)=CONVERT(NVARCHAR,CONVERT(DATETIME,@UET),106)
		SET @IC=@IC+1
		END
		
		SELECT * FROM @TabUnits	

SET NOCOUNT OFF;  						
END
GO
