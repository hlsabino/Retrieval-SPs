USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_ScheduleEvents]
	@Date [datetime],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;

	DECLARE @ScheduleID INT, @FreqType INT, @FreqInterval INT, @FreqSubdayType INT, @FreqSubdayInterval INT, @FreqRelativeInterval INT, @FreqRecurrenceFactor INT, 
			@StartDate NVARCHAR(20), @EndDate NVARCHAR(20), @StartTime NVARCHAR(20), @EndTime NVARCHAR(20), @Message NVARCHAR(MAX),@days int,@retVal int

	DECLARE @Tbl AS TABLE(ID INT IDENTITY(1,1) NOT NULL,ScheduleID INT, FreqType INT, FreqInterval INT, FreqSubdayType INT, FreqSubdayInterval INT, FreqRelativeInterval INT, FreqRecurrenceFactor INT,
			StartDate NVARCHAR(20), EndDate NVARCHAR(20), StartTime NVARCHAR(20), EndTime NVARCHAR(20), Message NVARCHAR(MAX))

	DECLARE @Dt1 NVARCHAR(20),@Dt2 DATETIME
	DECLARE @StDate DATETIME,@EDate DATETIME
	DECLARE @DtNextFrom DATETIME,@DtNextTo DATETIME,@I INT,@COUNT INT
	SET  @DtNextFrom=@Date
	select @days=Value from ADM_GlobalPreferences with(nolock) where name='Post Events For Next'
	SET  @DtNextTo=dateadd(day,@days,@Date)
	--print @DtNextFrom
	--print @DtNextTo
	--SET @Dt1=replace(replace(replace(CONVERT(NVARCHAR(19),@DtFrom,20),'-',''),':',''),' ','')
	--SET @Dt2=replace(replace(replace(CONVERT(NVARCHAR(19),@DtTo,20),'-',''),':',''),' ','')
	--dateadd(day,-2,getdate())
	
	INSERT INTO @Tbl
	SELECT ScheduleID, FreqType, FreqInterval, FreqSubdayType, FreqSubdayInterval, FreqRelativeInterval, FreqRecurrenceFactor, StartDate, 
              EndDate,(CASE WHEN StartTime='NaN:NaN:NaN' THEN '00:00:00' ELSE StartTime END) StartTime,
              (CASE WHEN EndTime='NaN:NaN:NaN' THEN '00:00:00' ELSE EndTime END) EndTime, Message
	FROM COM_Schedules WITH(NOLOCK)
	WHERE StatusID=1-- AND Scheduleid=254
	--WHERE EndDate IS NULL OR CONVERT(DATETIME,EndDate)>=@DtFrom
	--WHERE (@DtFrom BETWEEN CONVERT(DATETIME,StartDate)<=@DtFrom)
	-- CONVERT(DATETIME,StartDate)<=@DtFrom AND (CONVERT(DATETIME,EndDate)>=@DtFrom OR EndDate IS NULL)

	
	--SELECT * FROM @Tbl

	SELECT @I=1, @COUNT=COUNT(*) FROM @Tbl

	WHILE(@I<=@COUNT)
	BEGIN
		SELECT @ScheduleID=ScheduleID, @FreqType=FreqType, @FreqInterval=FreqInterval, @FreqSubdayType=FreqSubdayType, 
			   @FreqSubdayInterval=FreqSubdayInterval, @FreqRelativeInterval=FreqRelativeInterval, @FreqRecurrenceFactor=FreqRecurrenceFactor,
			   @StartDate=StartDate, @EndDate=EndDate, @StartTime=StartTime, @EndTime=EndTime, @Message=Message,
			   @StDate=CONVERT(DATETIME,@StartDate+' '+@StartTime,120),
			   @EDate=CASE WHEN @EndDate IS NULL THEN NULL ELSE CONVERT(DATETIME,EndDate+' '+StartTime,120) END
		FROM @Tbl WHERE ID=@I

		--SELECT @StDate START,@EDate [END],@DtNextFrom NextFrom,@DtNextTo NextTo
		
		--IF (@StDate BETWEEN @DtNextTo AND @DtNextFrom) OR 

		IF @FreqType=1--ONCE
		BEGIN
			IF NOT EXISTS (SELECT ScheduleID FROM COM_SchEvents WITH(NOLOCK) WHERE @ScheduleID=ScheduleID)
			BEGIN	
				IF (@StDate BETWEEN @DtNextFrom AND @DtNextTo)
				BEGIN
					INSERT INTO COM_SchEvents(ScheduleID,EventTime,Message,StatusID,StartFlag,StartDate,EndDate,CompanyGUID,[GUID],CreatedBy,CreatedDate)
					VALUES(@ScheduleID,CONVERT(FLOAT,@StDate),@Message,1,0,CONVERT(FLOAT,@StDate),CONVERT(FLOAT,@StDate),
					'CompanyGUID',NEWID(),'ADMIN',CONVERT(FLOAT,GETDATE()))
				END
			END
		END
		ELSE IF @FreqType=4--DAILY
		BEGIN
			--SELECT 'DAILY',@StDate START,@EDate [END],@DtNextFrom NextFrom,@DtNextTo NextTo,* FROM @Tbl WHERE ID=@I
			WHILE(@StDate <= @DtNextTo AND (@EDate IS NULL OR @StDate<=@EDate))
            BEGIN               	
				IF (@StDate BETWEEN @DtNextFrom AND @DtNextTo)
				BEGIN
					IF NOT EXISTS (SELECT ScheduleID FROM COM_SchEvents WITH(NOLOCK) WHERE @ScheduleID=ScheduleID AND EventTime=CONVERT(FLOAT,@StDate))
						INSERT INTO COM_SchEvents(ScheduleID,EventTime,Message,StatusID,StartFlag,StartDate,EndDate,CompanyGUID,[GUID],CreatedBy,CreatedDate)
						VALUES(@ScheduleID,CONVERT(FLOAT,@StDate),@Message,1,0,CONVERT(FLOAT,@StDate),CONVERT(FLOAT,@StDate),
						'CompanyGUID',NEWID(),'ADMIN',CONVERT(FLOAT,GETDATE()))
				END

				SET @StDate=DATEADD(day,@FreqInterval,@StDate)
            END
		END
		ELSE IF @FreqType=8--WEEKLY
		BEGIN
			--SELECT 'WEEKLY',@StDate START,@EDate [END],@DtNextFrom NextFrom,@DtNextTo NextTo,* FROM @Tbl WHERE ID=@I		
			
			DECLARE @STR NVARCHAR(10)
			SET @STR=''
	
			IF @FreqInterval>=64
			BEGIN
				SET @FreqInterval=@FreqInterval-64
				SET @STR='1'+@STR
			END
			ELSE
				SET @STR='0'+@STR

			IF @FreqInterval>=32
			BEGIN
				SET @FreqInterval=@FreqInterval-32
				SET @STR='1'+@STR
			END
			ELSE
				SET @STR='0'+@STR

			IF @FreqInterval>=16
			BEGIN
				SET @FreqInterval=@FreqInterval-16
				SET @STR='1'+@STR
			END
			ELSE
				SET @STR='0'+@STR

			IF @FreqInterval>=8
			BEGIN
				SET @FreqInterval=@FreqInterval-8
				SET @STR='1'+@STR
			END
			ELSE
				SET @STR='0'+@STR		

			IF @FreqInterval>=4
			BEGIN
				SET @FreqInterval=@FreqInterval-4
				SET @STR='1'+@STR
			END
			ELSE
				SET @STR='0'+@STR
			
			IF @FreqInterval>=2
			BEGIN
				SET @FreqInterval=@FreqInterval-2
				SET @STR='1'+@STR
			END
			ELSE
				SET @STR='0'+@STR

			IF @FreqInterval>=1
			BEGIN
				SET @FreqInterval=@FreqInterval-1
				SET @STR='1'+@STR
			END
			ELSE
				SET @STR='0'+@STR

			WHILE(@StDate <= @DtNextTo AND (@EDate IS NULL OR @StDate<=@EDate))
            BEGIN            
				 
				--SELECT @StDate, SUBSTRING(@STR, datepart(weekday,@StDate),1), datepart(weekday,@StDate)
				
				IF SUBSTRING(@STR, datepart(weekday,@StDate),1)='1' AND (@StDate BETWEEN @DtNextFrom AND @DtNextTo)
				BEGIN
					IF NOT EXISTS (SELECT ScheduleID FROM COM_SchEvents WITH(NOLOCK) WHERE @ScheduleID=ScheduleID AND EventTime=CONVERT(FLOAT,@StDate))
						INSERT INTO COM_SchEvents(ScheduleID,EventTime,Message,StatusID,StartFlag,StartDate,EndDate,CompanyGUID,[GUID],CreatedBy,CreatedDate)
						VALUES(@ScheduleID,CONVERT(FLOAT,@StDate),@Message,1,0,CONVERT(FLOAT,@StDate),CONVERT(FLOAT,@StDate),
						'CompanyGUID',NEWID(),'ADMIN',CONVERT(FLOAT,GETDATE()))
				END

				SET @StDate=DATEADD(day,1,@StDate)

				IF datepart(weekday,@StDate)=1 AND @FreqInterval>1--If Sunday
				BEGIN
					SET @StDate=DATEADD(day,@FreqInterval*7,@StDate)
				END
            END
		END--End of Weekly
		ELSE IF @FreqType=16--Monthly
		BEGIN
			declare @CntDay INT
			if @FreqInterval<DAY(@StDate)
			begin
				set @StDate=DATEADD(MONTH,1,@StDate)
				begin try
					SET @StDate=CONVERT(DATETIME, CONVERT(NVARCHAR,@FreqInterval)+' '+ { fn MONTHNAME(@StDate) }+' '+CONVERT(NVARCHAR,YEAR(@StDate)))
				end try
				begin catch
				end catch
            end
			else
			begin
				set @CntDay=@FreqInterval
				while(1=1)
				begin
					begin try
						set @StDate=CONVERT(DATETIME, CONVERT(NVARCHAR,@CntDay)+' '+ { fn MONTHNAME(@StDate) }+' '+CONVERT(NVARCHAR,YEAR(@StDate)))
						break
					end try
					begin catch
						set @CntDay=@CntDay-1
					end catch
				end
			end
			
			--SELECT 'Monthly',@StDate START,@EDate [END],@DtNextFrom NextFrom,@DtNextTo NextTo,* FROM @Tbl WHERE ID=@I

			WHILE(@StDate <= @DtNextTo AND (@EDate IS NULL OR @StDate<=@EDate))
            BEGIN  
				IF (@StDate BETWEEN @DtNextFrom AND @DtNextTo)
				BEGIN
					IF NOT EXISTS (SELECT ScheduleID FROM COM_SchEvents WITH(NOLOCK) WHERE @ScheduleID=ScheduleID AND EventTime=CONVERT(FLOAT,@StDate))
						INSERT INTO COM_SchEvents(ScheduleID,EventTime,Message,StatusID,StartFlag,StartDate,EndDate,CompanyGUID,[GUID],CreatedBy,CreatedDate)
						VALUES(@ScheduleID,CONVERT(FLOAT,@StDate),@Message,1,0,CONVERT(FLOAT,@StDate),CONVERT(FLOAT,@StDate),
						'CompanyGUID',NEWID(),'ADMIN',CONVERT(FLOAT,GETDATE()))
				END

				SET @StDate=DATEADD(month,@FreqRecurrenceFactor,@StDate)
				
				if (@FreqInterval!=DAY(@StDate))
				begin
					set @CntDay=@FreqInterval
					while(1=1)
					begin
						begin try
							set @StDate=CONVERT(DATETIME, CONVERT(NVARCHAR,@CntDay)+' '+ { fn MONTHNAME(@StDate) }+' '+CONVERT(NVARCHAR,YEAR(@StDate)))
							break
						end try
						begin catch
							set @CntDay=@CntDay-1
						end catch
					end
				end
            END         
          

		END--End of Monthly
		ELSE IF @FreqType=32--Monthly Relative
		BEGIN
			--SELECT 'Monthly Relative',@StDate START,@EDate [END],@DtNextFrom NextFrom,@DtNextTo NextTo,* FROM @Tbl WHERE ID=@I

			DECLARE @Dt DATETIME
			DECLARE @TblDates AS TABLE(ID INT IDENTITY(1,1) NOT NULL,dt datetime)
			
			IF @FreqInterval=8
			BEGIN
				if @FreqRelativeInterval=1
				begin
					if DAY(@StDate)<>1
					begin
						SET @StDate=CONVERT(DATETIME, '01 '+ { fn MONTHNAME(@StDate) }+' '+CONVERT(NVARCHAR,YEAR(@StDate))+' '+@StartTime,120)						
						SET @StDate=DATEADD(MONTH,1,@StDate)
					end
					
					WHILE(@StDate <= @DtNextTo AND (@EDate IS NULL OR @StDate<=@EDate))
					BEGIN 			
						IF (@StDate BETWEEN @DtNextFrom AND @DtNextTo)
						BEGIN
							IF NOT EXISTS (SELECT ScheduleID FROM COM_SchEvents WITH(NOLOCK) WHERE @ScheduleID=ScheduleID AND EventTime=CONVERT(FLOAT,@StDate))
								INSERT INTO COM_SchEvents(ScheduleID,EventTime,Message,StatusID,StartFlag,StartDate,EndDate,CompanyGUID,[GUID],CreatedBy,CreatedDate)
								VALUES(@ScheduleID,CONVERT(FLOAT,@StDate),@Message,1,0,CONVERT(FLOAT,@StDate),CONVERT(FLOAT,@StDate),
								'CompanyGUID',NEWID(),'ADMIN',CONVERT(FLOAT,GETDATE()))
						END

						SET @StDate=DATEADD(month,@FreqRecurrenceFactor,@StDate)
					END
				end
				else if @FreqRelativeInterval=16
				begin
					
					SET @StDate=CONVERT(DATETIME, '01 '+ { fn MONTHNAME(@StDate) }+' '+CONVERT(NVARCHAR,YEAR(@StDate))+' '+@StartTime,120)
					SET @StDate=DATEADD(Day,-1,DATEADD(MONTH,1,@StDate))
					
					WHILE(@StDate <= @DtNextTo AND (@EDate IS NULL OR @StDate<=@EDate))
					BEGIN 			
						IF (@StDate BETWEEN @DtNextFrom AND @DtNextTo)
						BEGIN
							IF NOT EXISTS (SELECT ScheduleID FROM COM_SchEvents WITH(NOLOCK) WHERE @ScheduleID=ScheduleID AND EventTime=CONVERT(FLOAT,@StDate))
								INSERT INTO COM_SchEvents(ScheduleID,EventTime,Message,StatusID,StartFlag,StartDate,EndDate,CompanyGUID,[GUID],CreatedBy,CreatedDate)
								VALUES(@ScheduleID,CONVERT(FLOAT,@StDate),@Message,1,0,CONVERT(FLOAT,@StDate),CONVERT(FLOAT,@StDate),
								'CompanyGUID',NEWID(),'ADMIN',CONVERT(FLOAT,GETDATE()))
						END
						SET @StDate=DATEADD(day,-1,DATEADD(month,@FreqRecurrenceFactor,DATEADD(day,1,@StDate)))
					END
					
					 --select @StDate, * from COM_SchEvents where scheduleid=242
				end
				
			END
			ELSE
			BEGIN
				SET @Dt=@StDate
				INSERT INTO @TblDates(dt)
				SELECT dateadd(day,n*@FreqInterval,dd) dates--,datename(weekday,dd)
				FROM (SELECT mm+1-datepart(weekday,mm) dd
				FROM (SELECT dateadd(month,datediff(month,0,@Dt),0) mm) d) d
				cross join
				(select 0 n union
				select 1 n union
				select 2 n union
				select 3 n union
				select 4 n ) n
				where datediff(month,@Dt,dateadd(day,n*7,dd))=0
				
				IF @FreqRelativeInterval=1
				BEGIN
					SELECT @Dt=dt FROM @TblDates WHERE ID=1
				END
				ELSE IF @FreqRelativeInterval=2
				BEGIN
					SELECT @Dt=dt FROM @TblDates WHERE ID=2
				END
				ELSE IF @FreqRelativeInterval=4
				BEGIN
					SELECT @Dt=dt FROM @TblDates WHERE ID=3
				END
				ELSE IF @FreqRelativeInterval=8
				BEGIN
					SELECT @Dt=dt FROM @TblDates WHERE ID=4
				END
				ELSE IF @FreqRelativeInterval=16
				BEGIN
					SELECT TOP 1 @Dt=dt FROM @TblDates ORDER BY ID DESC
				END
				
				SET @Dt=dateadd(hour,datepart(hour,@StDate),@Dt)
				SET @Dt=dateadd(minute,datepart(minute,@StDate),@Dt)
				SET @Dt=dateadd(second,datepart(second,@StDate),@Dt)
				
				IF @StDate>@Dt
				begin
					SET @I=@I+1
					CONTINUE--BREAK
				end
				
				SET @StDate=@Dt

				WHILE(@StDate <= @DtNextTo AND (@EDate IS NULL OR @StDate<=@EDate))
				BEGIN 			
					IF (@StDate BETWEEN @DtNextFrom AND @DtNextTo)
					BEGIN
						IF NOT EXISTS (SELECT ScheduleID FROM COM_SchEvents WITH(NOLOCK) WHERE @ScheduleID=ScheduleID AND EventTime=CONVERT(FLOAT,@StDate))
							INSERT INTO COM_SchEvents(ScheduleID,EventTime,Message,StatusID,StartFlag,StartDate,EndDate,CompanyGUID,[GUID],CreatedBy,CreatedDate)
							VALUES(@ScheduleID,CONVERT(FLOAT,@StDate),@Message,1,0,CONVERT(FLOAT,@StDate),CONVERT(FLOAT,@StDate),
							'CompanyGUID',NEWID(),'ADMIN',CONVERT(FLOAT,GETDATE()))
					END

					SET @StDate=DATEADD(month,@FreqRecurrenceFactor,@StDate)
				END
			END

		END--End of Monthly Relative


		SET @I=@I+1
	END

COMMIT TRANSACTION  

select distinct ACC.VoucherNo,E.GUID SchGUID,E.SchEventID,CS.CostCenterID,CS.NodeID,CONVERT(datetime,floor(E.EventTime)) EventTime,S.RecurMethod--,S.RecurAutoPost,ACC.WorkFlowID,ACC.PostRecurWithApproval
from COM_SchEvents E WITH(NOLOCK) 
join COM_CCSchedules CS with(nolock) on E.ScheduleID=CS.ScheduleID
join COM_Schedules S with(nolock) on S.ScheduleID=E.ScheduleID
join INV_DocDetails ACC with(nolock) on ACC.DocID=CS.NodeID -- ACC.PostRecurWithApproval=2
where E.statusid=1 and ACC.CostCenterID=CS.CostCenterID
and CS.CostCenterID>40000 and CS.CostCenterID<50000 and E.EventTime< getdate()
and S.RecurAutoPost in(2,3) 
--E.SchEventID=593 (ACC.WorkFlowID>0 and ACC.PostRecurWithApproval=2) or 
order by EventTime

BEGIN TRANSACTION  
declare @TblAutoDocs as table(ID int identity(1,1),SchEventID INT,CostCenterID int,docid INT,EventTime datetime,RecurMethod tinyint)
declare @SchEventID INT,@CostCenterID int,@docid INT,@EventTime datetime,@VoucherNo nvarchar(50),@RecurMethod tinyint
insert @TblAutoDocs
select distinct E.SchEventID,CS.CostCenterID,CS.NodeID,CONVERT(datetime,floor(E.EventTime)) EventTime,S.RecurMethod--,S.RecurAutoPost,ACC.WorkFlowID,ACC.PostRecurWithApproval
from COM_SchEvents E WITH(NOLOCK) 
join COM_CCSchedules CS with(nolock) on E.ScheduleID=CS.ScheduleID
join COM_Schedules S with(nolock) on S.ScheduleID=E.ScheduleID
join Acc_DocDetails ACC with(nolock) on ACC.DocID=CS.NodeID -- ACC.PostRecurWithApproval=2
where E.statusid=1 and ACC.CostCenterID=CS.CostCenterID
and CS.CostCenterID>40000 and CS.CostCenterID<50000 and E.EventTime< getdate()
and ((ACC.WorkFlowID>0 and ACC.PostRecurWithApproval=2) or (S.RecurAutoPost=2 and (ACC.WorkFlowID is null or ACC.WorkFlowID=0 or ACC.WorkFlowLevel is null)))
--E.SchEventID=593
order by EventTime

--select * from @TblAutoDocs

SELECT @I=1, @COUNT=COUNT(*) FROM @TblAutoDocs
WHILE(@I<=@COUNT)
BEGIN
	select @SchEventID=SchEventID,@CostCenterID=CostCenterID,@docid=docid,@EventTime=EventTime,@VoucherNo=null,@RecurMethod=RecurMethod
	FROM @TblAutoDocs WHERE ID=@I
	
	--select @SchEventID,@CostCenterID,@docid,@EventTime
	
	EXEC @retVal=[spDOC_SetRecurDocument] @CostCenterID,@docid,@EventTime,@RecurMethod,'CompanyGUID','AUTO-POST',@UserID,@LangID,@VoucherNo output
	--select @VoucherNo
	if(@retVal=-999)
		return -999
	
	if @VoucherNo is not null and len(@VoucherNo)>0
	begin
		update COM_SchEvents
		set statusid=2,PostedVoucherNo=@VoucherNo
		where SchEventID=@SchEventID
	end
	
	SET @I=@I+1
END

COMMIT TRANSACTION 
SET NOCOUNT OFF;  

RETURN 1  
END TRY  
BEGIN CATCH 
	if(@retVal=-999)
		return -999 
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
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
