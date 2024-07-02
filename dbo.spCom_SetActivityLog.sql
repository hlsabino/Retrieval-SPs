USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_SetActivityLog]
	@ActivityID [int],
	@Date [datetime],
	@status [int],
	@Reason [nvarchar](max),
	@Longitude [nvarchar](200),
	@Latitude [nvarchar](200),
	@Address1 [nvarchar](256),
	@Address2 [nvarchar](256),
	@City [nvarchar](64),
	@State [nvarchar](64),
	@Country [nvarchar](64),
	@PinCode [nvarchar](32),
	@CompanyGUID [nvarchar](max),
	@UserName [nvarchar](300),
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON 
BEGIN TRANSACTION
BEGIN TRY
	
	declare @id int,@dur float,@OldStat int
	set @dur=0
	if(@status in(1,2))
	BEGIN
		insert into CRM_ActivityLog(ActivityID,StartDate,StLongitude,StLatitude,StAddress1,StAddress2,StCity,StState,StCountry,StPinCode)
		Values(@ActivityID,convert(float,@Date),@Longitude,@Latitude,@Address1,@Address2,@City,@State,@Country,@PinCode)
		
		if(@status=1)
			update CRM_Activities
			set ActStartDate=convert(float,@Date),statusid=9
			where ActivityID=@ActivityID
		else
			update CRM_Activities
			set statusid=9
			where ActivityID=@ActivityID
				
	END
	ELSE if(@status in(15))
	BEGIN		
		select @id= ActivityLogID from CRM_ActivityLog WITH(NOLOCK)
		where ActivityID=@ActivityID
		order by ActivityLogID
		
		update CRM_ActivityLog
		set EndDate=convert(float,@Date),
		Remarks=@Reason,
		EnLongitude=@Longitude,
		EnLatitude=@Latitude,
		EnAddress1=@Address1,
		EnAddress2=@Address2,
		EnCity=@City,
		EnState=@State,
		EnCountry=@Country,
		EnPinCode=@PinCode
		where ActivityLogID=@id
		
		select @dur=sum(datediff(n,convert(datetime,startdate),convert(datetime,enddate))) from CRM_ActivityLog WITH(NOLOCK)
		where ActivityID=@ActivityID
		
		update CRM_Activities
		set statusid=@status,ActendDate=convert(float,@Date),TotalDuration=@dur
		where ActivityID=@ActivityID				
	END
	ELSE if(@status in(3,4))
	BEGIN
	
		select @id= ActivityLogID from CRM_ActivityLog WITH(NOLOCK)
		where ActivityID=@ActivityID
		order by ActivityLogID
		
		select  @OldStat=statusid,@dur=TotalDuration from  CRM_Activities WITH(NOLOCK)
		where ActivityID=@ActivityID
		
		if (@status=4 and @OldStat=8)		
		BEGIN
			select  @Date=convert(datetime,ActendDate) from  CRM_Activities WITH(NOLOCK)
			where ActivityID=@ActivityID
		END
		ELSE
		BEGIN
			update CRM_ActivityLog
			set EndDate=convert(float,@Date),
			Remarks=@Reason,
			EnLongitude=@Longitude,
			EnLatitude=@Latitude,
			EnAddress1=@Address1,
			EnAddress2=@Address2,
			EnCity=@City,
			EnState=@State,
			EnCountry=@Country,
			EnPinCode=@PinCode
			where ActivityLogID=@id
		
			select @dur=sum(datediff(n,convert(datetime,startdate),convert(datetime,enddate))) from CRM_ActivityLog WITH(NOLOCK)
			where ActivityID=@ActivityID
		END
		if(@status=4)
			update CRM_Activities
			set ActendDate=convert(float,@Date),statusid=413,TotalDuration=@dur
			where ActivityID=@ActivityID
		else
			update CRM_Activities
			set statusid=12,TotalDuration=@dur
			where ActivityID=@ActivityID
			
	END	
	ELSE if(@status=10)
	BEGIN
		select convert(datetime,StartDate) StartDate,convert(datetime,EndDate) EndDate,Remarks 
		,StLatitude,StAddress1,StAddress2,StCity,StState,StCountry,StPinCode
		,EnLatitude,EnAddress1,EnAddress2,EnCity,EnState,EnCountry,EnPinCode
		from CRM_ActivityLog WITH(NOLOCK)
		where ActivityID=@ActivityID
	END	
	
COMMIT TRANSACTION
SELECT ErrorMessage,ErrorNumber,@dur duration FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=100 AND LanguageID=@LangID  
SET NOCOUNT OFF;    
RETURN @ActivityID
END TRY    
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
  WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
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
 ROLLBACK TRANSACTION  
 SET NOCOUNT OFF    
 RETURN -999     
END CATCH
GO
