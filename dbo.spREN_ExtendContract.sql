USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_ExtendContract]
	@ContractID [int],
	@NoofMonths [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION          
BEGIN TRY            
SET NOCOUNT ON; 
		declare @enddate datetime,@dur int,@rent float,@sql nvarchar(max),@rentNodeID int,@PartDim int,@PDID int,@cnt int,@i int,@SNO BIGINT,@Seq int
		declare @schduleid int,@ccid int,@dt float,@NodeID int,@Dimesion int
		set @dt=convert(float,getdate())
		set @PDID=0
		set @PartDim=0
		select @PartDim=value from adm_globalpreferences WITH(NOLOCK)
		WHere name ='DepositLinkDimension' and value is not null and value<>'' and isnumeric(value)=1

		exec [spDOC_GetNode] @PartDim,'Rent',0,0,1,'GUID','Admin',1,1,@rentNodeID output

		select @enddate=convert(datetime,EndDate),@dur=RecurDuration,@SNO=SNO  from REN_Contract WITH(NOLOCK)
		where contractid=@ContractID
		
		set @enddate=dateadd(M,@NoofMonths,@enddate)
		
		update REN_Contract
		set EndDate=convert(float,@enddate),RecurDuration=RecurDuration+@NoofMonths,ModifiedBy=@UserName,ModifiedDate=@dt
		where contractid=@ContractID
		
		
		select  @NodeID = CCNodeID, @Dimesion=CCID from REN_CONTRACT WITH(NOLOCK) where ContractID=@ContractID  
		if (@Dimesion > 50000 and @NodeID is not null and @NodeID>1)  
		begin 
			set @sql=''
			select @sql='update '+f.tablename+' set '+l.SysColumnName+'='''+convert(nvarchar,@enddate,100)+''' where NodeID='+convert(nvarchar(max),@NodeID) FROM COM_DocumentBatchLinkDetails A  with(nolock)
			JOIN ADM_CostCenterDef B with(nolock) ON B.CostCenterColID=A.BatchColID AND B.CostCenterID=A.CostCenterID   
			JOIN ADM_CostCenterDef L with(nolock) ON L.CostCenterColID=A.CostCenterColIDBase AND L.CostCenterID=A.LinkDimCCID   
			join adm_features f with(nolock) ON f.featureid=L.CostCenterID
			WHERE A.CostCenterID=95 and A.LinkDimCCID=@Dimesion and L.SysColumnName is not null and L.SysColumnName!='' and B.SysColumnName is not null and B.SysColumnName='EndDate'
			
			if(@sql<>'')
				exec(@sql)
		END
		
		if exists(select contractid from REN_ContractParticularsDetail WITH(NOLOCK)
		where contractid=@ContractID and convert(datetime,ToDate)=@enddate)
		BEGIN
			select @rent=Amount,@dur=Distribute,@PDID=ParticularNodeID from REN_ContractParticularsDetail WITH(NOLOCK)
			where contractid=@ContractID and convert(datetime,ToDate)=@enddate	
			
			set @rent=@rent/@dur		
			set @rent=round((@rent*@NoofMonths),2)
			
			update REN_ContractParticularsDetail
			set Distribute=Distribute+@NoofMonths,Amount=@rent+Amount,ActAmount=ActAmount+@rent
			where ParticularNodeID=@PDID
		END
		ELSE
		BEGIN			
			select @rent=Amount from REN_ContractParticulars WITH(NOLOCK)
			where contractid=@ContractID and CCNodeID=@rentNodeID
			
			set @rent=@rent/@dur		
			set @rent=round((@rent*@NoofMonths),2)
			
			update REN_ContractParticulars
			set Amount=@rent+Amount,RentAmount=@rent+RentAmount
			where contractid=@ContractID and CCNodeID=@rentNodeID			 
		END
		
		select @schduleid=a.ScheduleID,@ccid=DM.CostCenterID from REN_ContractDocMapping DM WITH(NOLOCK)
		join COM_CCSchedules a WITH(NOLOCK) on DM.CostCenterID=a.CostCenterID		
		join COM_SchEvents b WITH(NOLOCK) on a.ScheduleID=b.ScheduleID
		where a.NodeID=DM.DocID and DM.ContractID = @ContractID 
		and (DM.TYPE = 1 OR DM.TYPE IS NULL) and (DM.isaccdoc = 0 OR DM.IsAccDoc  IS NULL )
		order by EventTime
		
		update COM_Schedules
		set EndDate=convert(float,@enddate),Occurrence=Occurrence+@NoofMonths
		where ScheduleID=@schduleid
		
		select @enddate=convert(datetime,max(EventTime)),@Seq=max(AttachmentID) from COM_SchEvents WITH(NOLOCK)
		where ScheduleID=@schduleid
		
		set @cnt=@NoofMonths
		set @i=0
		while(@i<@cnt)
		BEGIN
			set @i=@i+1
			set @Seq=@Seq+1
			set @enddate=dateadd(M,1,@enddate)
			
			INSERT INTO COM_SchEvents(ScheduleID,EventTime,Message,StatusID,StartFlag,StartDate,EndDate,CompanyGUID,[GUID],CreatedBy,CreatedDate,
			SubCostCenterID,NODEID,AttachmentID)
			select @schduleid,CONVERT(FLOAT,@enddate),'Contract',1,0,CONVERT(FLOAT,@enddate),CONVERT(FLOAT,@enddate),
			@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()),@ccid,@SNO,@Seq
		END	
		
		
		if exists(SELECT  *  FROM [COM_COSTCENTERPreferences] with(nolock)     
		WHERE CostCenterID=95  AND NAME='AllowAudit' and (VALUE='true' or VALUE='1'))		
		BEGIN 	
			--INSERT INTO HISTROY   
			EXEC [spCOM_SaveHistory]  
				@CostCenterID =95,    
				@NodeID =@ContractID,
				@HistoryStatus ='Extend',
				@UserName=@UserName,
				@DT=@dt  
		END

COMMIT TRANSACTION
SET NOCOUNT OFF;
    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)         
WHERE ErrorNumber=100 AND LanguageID=@LangID 
RETURN @ContractID            
END TRY            
BEGIN CATCH      
	          
		IF ERROR_NUMBER()=50000        
		BEGIN 
			IF ISNUMERIC(ERROR_MESSAGE())<>1			
				SELECT ERROR_MESSAGE() ErrorMessage,ERROR_NUMBER() ErrorNumber
			ELSE  
				SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)         
				WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID        
		END        
		ELSE IF ERROR_NUMBER()=547        
		BEGIN        
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
			FROM COM_ErrorMessages WITH(nolock)        
			WHERE ErrorNumber=-110 AND LanguageID=@LangID        
		END        
		ELSE IF ERROR_NUMBER()=2627        
		BEGIN        
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
			FROM COM_ErrorMessages WITH(nolock)        
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
