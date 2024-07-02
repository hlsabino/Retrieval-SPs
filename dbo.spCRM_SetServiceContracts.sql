USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_SetServiceContracts]
	@SvcContractID [int],
	@SvcDate [datetime],
	@DocID [varchar](100),
	@StatusID [int],
	@ContractTemplID [int],
	@CustomerID [int],
	@StartDate [float],
	@EndDate [float],
	@Description [nvarchar](max),
	@ServiceContractXML [varchar](max),
	@ScheduleBillingXml [varchar](max),
	@ServiceContractExtraXml [varchar](max),
	@IsGroup [bit],
	@SelectedNodeID [int],
	@CompanyGUID [nvarchar](50),
	@UserName [nvarchar](50),
	@GUID [varchar](50),
	@CreatedBy [nvarchar](50),
	@UserID [int] = 0,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON   
 BEGIN TRANSACTION  
 BEGIN TRY  

    DECLARE @Dt FLOAT, @lft INT,@rgt INT,@TempGuid nvarchar(50),@Selectedlft INT,@Selectedrgt INT,@HasAccess bit,
	@IsDuplicateNameAllowed bit,@IsBOMCodeAutoGen bit  ,@IsIgnoreSpace bit  ,  
  @Depth int,@ParentID INT,@SelectedIsGroup bit , @XML XML,@ParentCode nvarchar(200),@UpdateSql nvarchar(max),
  @IsSCCodeAutoGen bit  ,@BillingSchXML XML,@ExtraField XML
     Declare @RowCount int
				  declare @Count int
				  declare @ContarctLineID int
				  declare @ScheduleID int
				  declare @BillingSchID int
				   
    CREATE TABLE #tblServiceContracts
				(rowno int ,
				SvcContractID int ,
			   ProductID int, 
			   LineNumber int,
			   SerialNumber   varchar(max),
			   UnitsType int,
			   AllottedUnits int,
			   Price float,
			   Discount float,
			   NetPrice float,
			   SvcFrequencyID int,
			   SvcFrequencyName nvarchar(max),
			   SvcStartDate datetime,
			   SvcEndDate datetime,
			   CompanyGUID varchar(100),
			   GUID varchar(100),
			   CreatedBy varchar(100),
			   CreatedDate float, 
			   ModifiedBy varchar(100),
			   ModifiedDate float,
			   CostcenterID INT,
			   ContractLineID INT,
			   ScheduleID INT,
			    invDocdetailID int,
			   voucherno varchar(100),
			   employeeid int,
			  servicePrice float,
			   CLStatus int,
		        Name	nvarchar(200),
				StatusID	int,
				FreqType	int,
				FreqInterval	int,
				FreqSubdayType	int,
				FreqSubdayInterval	int,
				FreqRelativeInterval	int,
				FreqRecurrenceFactor	int,
				schStartDate	nvarchar(100),
				schEndDate	nvarchar(100),
				StartTime	nvarchar(100),
				EndTime	nvarchar(100),
				Message	nvarchar(MAX),
				Description	nvarchar(MAX),Parts INT,
				MAXAmount float,
			   )


    SELECT @IsDuplicateNameAllowed=Value FROM COM_CostCenterPreferences WITH(nolock) WHERE COSTCENTERID=84 and  Name='DuplicateNameAllowed'    
  SELECT @IsSCCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=84 and  Name='CodeAutoGen'    
  SELECT @IsIgnoreSpace=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=84 and  Name='IgnoreSpaces'   
DECLARE	@LineStatus INT, @SvcStartDate datetime,@return_value int,@IsLeadCodeAutoGen bit  ,@CaseNumber NVARCHAR(300),@PRODUCTID INT,@SERIALNUMBER NVARCHAR(300),
@Assigned INT
								
  
  IF @SvcContractID = 0--------START INSERT RECORD-----------    
    BEGIN

				IF @IsDuplicateNameAllowed IS NOT NULL AND @IsDuplicateNameAllowed=0    
				 BEGIN    
						  IF @IsIgnoreSpace IS NOT NULL AND @IsIgnoreSpace=1    
								  BEGIN    --2
								   IF @SvcContractID=0    
								   BEGIN    --1
											 IF EXISTS (SELECT SvcContractID FROM CRM_ServiceContract WITH(nolock) WHERE replace(DocID,' ','')=replace(@DocID,' ',''))    
											  BEGIN    
											  RAISERROR('-108',16,1)    
											  END    
									END     --11
						   ELSE    
									BEGIN    
									  IF EXISTS (SELECT SvcContractID FROM CRM_ServiceContract WITH(nolock) WHERE replace(DocID,' ','')=replace(@DocID,' ','') AND SvcContractID  =@SvcContractID)    
									  BEGIN    
									  RAISERROR('-108',16,1)         
									  END    
									END    
				   END    
				  ELSE    
						   BEGIN    
						   IF @SvcContractID=0    
									BEGIN    
											  IF EXISTS (SELECT SvcContractID FROM CRM_ServiceContract WITH(nolock) WHERE DocID=@DocID)    
											  BEGIN    
											  RAISERROR('-108',16,1)    
											  END    
									END    
							ELSE    
									 BEGIN    
											   IF EXISTS (SELECT SvcContractID FROM CRM_ServiceContract WITH(nolock) WHERE DocID=@DocID AND SvcContractID  =@SvcContractID)    
											   BEGIN    
											   RAISERROR('-108',16,1)    
											   END    
									 END    
						   END  
				  END  

				SET @Dt=convert(float,getdate())
		 		 SELECT @SelectedIsGroup=IsGroup,
				 @Selectedlft =lft,
				 @Selectedrgt=rgt,
				 @ParentID=ParentID,
				 @Depth=Depth    
			     from CRM_ServiceContract with(NOLOCK) where SvcContractID=@SelectedNodeID    

				if(@SelectedIsGroup is null and @IsGroup=0)     
				select    @SelectedIsGroup=IsGroup,
				@Selectedlft =lft,
				@Selectedrgt=rgt,
				@ParentID=ParentID,
				@Depth=Depth    
				from CRM_ServiceContract with(NOLOCK) where ParentID =0    

			 

				 if(@SelectedIsGroup = 1)--Adding Node Under the Group    
				 BEGIN    
				  UPDATE CRM_ServiceContract SET rgt = rgt + 2 WHERE rgt > @Selectedlft;    
				  UPDATE CRM_ServiceContract SET lft = lft + 2 WHERE lft > @Selectedlft;    
				  set @lft =  @Selectedlft + 1    
				  set @rgt = @Selectedlft + 2    
				  set @Depth = @Depth + 1    
				 END    
			   else if(@SelectedIsGroup = 0)--Adding Node at Same level    
				 BEGIN    
				  UPDATE CRM_ServiceContract SET rgt = rgt + 2 WHERE rgt > @Selectedrgt;    
				  UPDATE CRM_ServiceContract SET lft = lft + 2 WHERE lft > @Selectedrgt;    
				  set @lft =  @Selectedrgt + 1    
				  set @rgt = @Selectedrgt + 2     
				 END    
			   else  --Adding Root    
				 BEGIN    
				  set @lft =  1    
				  set @rgt = 2     
				  set @Depth = 0    
				  set @ParentID =0    
      
				 END   

     --GENERATE CODE    
			   IF @IsSCCodeAutoGen IS NOT NULL AND @IsSCCodeAutoGen=1 AND @SvcContractID=0    
				BEGIN    
				 SELECT @ParentCode=DocID    
				 FROM CRM_ServiceContract WITH(NOLOCK) WHERE SvcContractID=@ParentID      
    
				 --CALL AUTOCODEGEN    
				EXEC [spCOM_SetCode] 84,@ParentCode,@DocID OUTPUT      
				END   
				
				
			set 	@BillingSchXML=@ScheduleBillingXml
			
				if(@ScheduleBillingXml='' )
				begin
			set @BillingSchID =null
					 	 insert into 
				  CRM_ServiceContract([Date], DocID, StatusID, ContractTemplID, CustomerID,StartDate, EndDate, Description,BillingScheduleID, 
				 Depth, ParentID, lft, rgt, IsGroup, CompanyGUID, GUID, CreatedBy, CreatedDate, ModifiedBy, ModifiedDate)
				 values
				 (convert(float,@SvcDate),@DocID,@StatusID,@ContractTemplID,@CustomerID,@StartDate,@EndDate,@Description,@BillingSchID,@Depth  
					,@SelectedNodeID  
					,@lft  
					,@rgt  
					,@IsGroup  
					,@CompanyGUID  
					,newid()  
					,@CreatedBy  
					,convert(float,getdate())
					  ,@CreatedBy  
					,convert(float,getdate())
					)   
						SET @SvcContractID=SCOPE_IDENTITY()   

						set @ExtraField=@ServiceContractExtraXml

							INSERT INTO CRM_ServiceContractextd(SvcContractID,[CreatedBy],[CreatedDate])
				VALUES(@SvcContractID, @CreatedBy, convert(float,getdate()))


	set @UpdateSql='update CRM_ServiceContractextd
				SET '+@ServiceContractExtraXml+' [ModifiedBy] ='''+ @CreatedBy
				+''',[ModifiedDate] =' + convert(nvarchar,convert(float,getdate())) +' WHERE SvcContractID='+Convert(varchar(100), @SvcContractID)
				exec(@UpdateSql)


				end
				else
				begin
				INSERT INTO COM_Schedules(Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,
					FreqRelativeInterval,FreqRecurrenceFactor,StartDate,EndDate,StartTime,EndTime,Message,
				    CompanyGUID,GUID,CreatedBy,CreatedDate)
				    select 'Document',
				    1,
				    X.value('@FreqType','int'),
				    X.value('@FreqInterval','int'),
				    X.value('@FreqSubdayType','int'),
				    X.value('@FreqSubdayInterval','int'),
				    X.value('@FreqRelativeInterval','int'),
				    X.value('@FreqRecurrenceFactor','int'),
				    CONVERT(DATETIME,X.value('@CStartDate','nvarchar(100)'),102),
				    CONVERT(DATETIME,X.value('@CEndDate','nvarchar(100)'),102),
				    X.value('@StartTime','nvarchar(100)'),
				    X.value('@EndTime','nvarchar(100)'),
				    X.value('@Message','nvarchar(100)'),
				   @CompanyGUID,
				   NEWID(),
				   @CreatedBy,
				   convert(float,getdate())
				   
				  FROM @BillingSchXML.nodes('/ScheduleBillingXml/Row') as Data(X)
				  
			set @BillingSchID=SCOPE_IDENTITY();
			
	 
         
     
					SET @SvcContractID=SCOPE_IDENTITY()   
 
INSERT INTO COM_CCSchedules(CostCenterID,NodeID,ScheduleID,CreatedBy,CreatedDate)
		        VALUES(84,@SvcContractID,@BillingSchID,@UserName,@Dt) 
		        
					
                   end
		 
				    SET @XML=@ServiceContractXML
				   
				   insert into #tblServiceContracts(rowno,SvcContractID ,
			   ProductID, 
			   LineNumber ,
			   SerialNumber ,
			   UnitsType ,
			   AllottedUnits ,
			   Price ,
			   Discount ,
			   NetPrice ,
			   SvcFrequencyID ,
			   SvcFrequencyName ,
			   SvcStartDate ,
			   SvcEndDate ,
			   CompanyGUID ,
			   GUID ,
			   CreatedBy ,
			   CreatedDate, 
			   ModifiedBy ,
			   ModifiedDate,
			    CostcenterID ,
			    ContractLineID,
			   ScheduleID,
			   invDocdetailID,
			   voucherno,
			   employeeid,
			   servicePrice,
			   CLStatus,
		        Name,
				StatusID,
				FreqType,
				FreqInterval,
				FreqSubdayType,
				FreqSubdayInterval,
				FreqRelativeInterval,
				FreqRecurrenceFactor,
				schStartDate,
				schEndDate,
				StartTime,
				EndTime,
				Message,
				Description,Parts,MaxAmount 
			   			   )
				 SELECT  X.value('@rowno','int'),
				  @SvcContractID,
				 X.value('@ProductID','int'),
				 X.value('@LineNumber','int'),     
				X.value('@SerialNumber','varchar(100)'),
				X.value('@UnitsType','int'),
				X.value('@AllottedUnits','int'),    
				X.value('@Price','float'),
				X.value('@Discount','float'),
				X.value('@NetPrice','float'),
				X.value('@SvcFrequencyID','int'),
				 X.value('@SvcFrequencyName','nvarchar(100)'), 
			  convert(float, X.value('@SvcStartDate','datetime')),
			  convert(float,  X.value('@SvcEndDate','datetime')),
				  @CompanyGUID ,
				 @Guid,
				  @UserName,
				 @Dt,
				 @UserName,
				  @Dt  ,   
				84 ,
				X.value('@ContractLineID','int'),
			    X.value('@ScheduleID','int'),
				X.value('@InvDocDetailID','int'),
				X.value('@VoucherNo','varchar(100)'),
				X.value('@EmployeeID','int'),
				X.value('@ServicePrice','float'),
					X.value('@Status','int'),
				'Document',				
				X.value('@SchStatus','int'),
				 X.value('@FreqType','int'),
				 X.value('@FreqInterval','int'),
				 X.value('@FreqSubdayType','int'),
				 X.value('@FreqSubdayInterval','int'),
				 X.value('@FreqRelativeInterval','int'),
				 X.value('@FreqRecurrenceFactor','int'),
				 X.value('@CStartDate','nvarchar(100)'),
				 X.value('@CEndDate','nvarchar(100)'),
				 X.value('@StartTime','nvarchar(100)'),
				 X.value('@EndTime','nvarchar(100)'),
				 X.value('@Message','nvarchar(100)'),
				 X.value('@Description','nvarchar(100)'),
				  X.value('@Parts','int'),
				   X.value('@MaxAmount','Float')
				  FROM @XML.nodes('/ServiceContractXml/Row') as Data(X)   
				   WHERE  X.value('@ContractLineID','int')=0
				 

 
				   select @RowCount=Count(*) from #tblServiceContracts 
				   set @Count=1
				  
				   while(@Count<=@RowCount)
				   begin
				   
				  select @ContarctLineID =ContractLineID,@ScheduleID=ScheduleID from #tblServiceContracts
			       where rowno=@Count  

			          if(@ContarctLineID is null or @ContarctLineID=0)
		      	   begin
		      	   
		      	  if(@ScheduleID>-1)
		      	  begin
					INSERT INTO COM_Schedules(Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,
					FreqRelativeInterval,FreqRecurrenceFactor,StartDate,EndDate,StartTime,EndTime,Message,
				    CompanyGUID,GUID,CreatedBy,CreatedDate)
				    (select Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,FreqRelativeInterval,
				    FreqRecurrenceFactor,convert(varchar(20),schStartDate),convert(varchar(20),schEndDate),StartTime,EndTime,Message,CompanyGUID,GUID,
				   CreatedBy,CreatedDate 
			       from #tblServiceContracts
			       where rowno=@Count)
					SET @ScheduleID=SCOPE_IDENTITY()
					end
					else
					begin
					set @ScheduleID =null
					end
					

		   	insert into CRM_ContractLines(SvcContractID ,
			   ProductID, 
			   LineNumber ,
			   SerialNumber ,
			   UnitsType ,
			   AllottedUnits ,
			   Price ,
			   Discount ,
			   NetPrice ,
			   SvcFrequencyID ,
			   SvcFrequencyName ,
			   SvcStartDate ,
			   SvcEndDate ,
			   ScheduleID,
			   invdocdetailID,
			   voucherno,
			   employeeid,
			   serviceprice,
			   StatusID,
			   CompanyGUID ,
			   GUID ,
			   CreatedBy ,
			   CreatedDate, 
			   ModifiedBy ,
			   ModifiedDate,Parts,MaxAmount)(select SvcContractID ,ProductID,LineNumber,SerialNumber,UnitsType ,
			   AllottedUnits,Price,Discount,NetPrice,SvcFrequencyID,SvcFrequencyName ,
			 convert(float,SvcStartDate) ,convert(float, SvcEndDate),@ScheduleID,invdocdetailid,voucherno,employeeid,serviceprice,CLStatus,CompanyGUID,GUID,CreatedBy,CreatedDate,ModifiedBy,
			   ModifiedDate,Parts,MAXAmount 
			   from #tblServiceContracts
			   where rowno=@Count);
			   SET @ContarctLineID=SCOPE_IDENTITY()
			   


				if(@ScheduleID>-1 and @ScheduleID is not null)
				   begin
			 
				INSERT INTO COM_CCSchedules(CostCenterID,NodeID,ScheduleID,CreatedBy,CreatedDate)
		        VALUES(84,@ContarctLineID,@ScheduleID,@UserName,@Dt) 
		        end
			   end
			   
			   --ADDED CODE ON AUG 24 2012 BY HAFEEZ
	
			  select @LineStatus=STATUSID,
			  @SvcStartDate=SvcStartDate,@Assigned=employeeid,@PRODUCTID=ProductID,@SERIALNUMBER=SerialNumber  from CRM_ContractLines where ContractLineID=@ContarctLineID
						 
			IF @SvcContractID<>0
			BEGIN				
				IF((SELECT COUNT(*) FROM CRM_ContractTemplate WHERE ContractTemplID IN (
				SELECT ContractTemplID FROM CRM_SERVICECONTRACT WHERE SVCCONTRACTID=@SvcContractID))>0)
				BEGIN 
				
					DECLARE @BILLINGTYPE INT,@RCOUNT INT,@DURATION INT,@TEMPDATE DATETIME,@CustomerName NVARCHAR(MAX),@ACTIVITYLIST NVARCHAR(MAX)
					SELECT @BILLINGTYPE=BillFrequencyID,@DURATION=
					CASE WHEN DurationMonths=1 THEN 3  WHEN DurationMonths=2 THEN 6
					WHEN DurationMonths=3 THEN 12 WHEN DurationMonths=4 THEN 24 ELSE 0 END FROM CRM_ContractTemplate WHERE ContractTemplID IN (
					SELECT ContractTemplID FROM CRM_SERVICECONTRACT WHERE SVCCONTRACTID=@SvcContractID)
					 
					IF @BILLINGTYPE=1 --FOR MONTHLY
					BEGIN
						SET @RCOUNT=1
						  
						
						IF @SvcStartDate IS NULL OR @SvcStartDate<>''
						 SET @TEMPDATE=@SvcStartDate				
						ELSE
						SET @TEMPDATE=@SvcDate
						--SET @STARTTIME=substring(convert(varchar,@CaseDate,108),1,2)
					 
						WHILE @RCOUNT<=@DURATION
						BEGIN
								SELECT @CustomerName=CustomerCode+'-'+ CustomerName FROM CRM_CUSTOMER WHERE CustomerID=@CustomerID
								
									
									  SELECT @IsLeadCodeAutoGen=Value FROM COM_CostCenterPreferences  WITH(nolock) WHERE COSTCENTERID=73 and  Name='CodeAutoGen'  
	 
									 IF  @IsLeadCodeAutoGen=0   
									 BEGIN     
									    SET @CaseNumber=CONVERT(VARCHAR,@RCOUNT)+ '-' + CONVERT(VARCHAR(200),@DocID) + '-' + CONVERT(VARCHAR(200),(select PRODUCTCODE  from INV_PRODUCT WHERE PRODUCTID=@PRODUCTID)) + '-' +
										CONVERT(VARCHAR(200),@SERIALNUMBER)  + '-' + 
										CONVERT(VARCHAR(300),@CustomerName)
									END 
								 
									EXEC	@return_value = [dbo].[spCRM_SetCases]
									@CaseID = 0,@CaseNumber=@CaseNumber
									,@CaseDate=@TEMPDATE,@CUSTOMER=@CustomerID,@StatusID=432,
									@IsGroup = 0,@SelectedNodeID = 0,
									@PRODUCTID =@PRODUCTID,
									@SERIALNUMBER = @SERIALNUMBER,@SVCCONTRACTID=@SvcContractID,@CONTRACTLINEID=@ContarctLineID,
									@BillingMethod=138,
									@Assigned=@Assigned,
									 @CompanyGUID=@COMPANYGUID,@GUID=GUID,
									@UserName=@UserName,@UserID=@UserID
									
									IF @IsLeadCodeAutoGen=0 
									SELECT @CaseNumber=[CaseNumber] FROM [CRM_Cases] WHERE CASEID=@return_value
									
									INSERT INTO CRM_Activities(ActivityTypeID, ScheduleID, CostCenterID, NodeID, StatusID, Subject, Priority,  
									Location, IsAllDayActivity,  
									  CustomerID, Remarks,  ActualCloseDate,ActualCloseTime, StartDate,EndDate,StartTime,EndTime, CompanyGUID, GUID,  CreatedBy, CreatedDate)
									VALUES (1,0,73,@return_value,412,@CaseNumber,2,'-',1,
									@CustomerName,'Auto Generate Event for '+convert(varchar,@DURATION)+' months'
									,null,'',CONVERT(FLOAT,@TEMPDATE),CONVERT(FLOAT,@TEMPDATE),'11:00 AM','11:30 AM',@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()))
									 SET @ACTIVITYLIST = @ACTIVITYLIST + CONVERT(VARCHAR,SCOPE_IDENTITY()) +','
									 
										SET @RCOUNT=@RCOUNT+1
										SET @TEMPDATE=DATEADD(MONTH,1,@TEMPDATE)
										
						END
					END
				END 
			END	
			   
			   --UPDATE CASES STATUS TO CANCELLED IF CONTRACTLINE STATUS IS INACTIVE
			   IF @LineStatus=396
			   BEGIN 
					BEGIN 
					
							UPDATE CRM_CASES SET StatusID=431 WHERE SvcContractID=@SvcContractID AND PRODUCTID=@PRODUCTID AND
							SERIALNUMBER = @SERIALNUMBER AND StatusID=432 AND ContractLineID=@ContarctLineID
					
					END
			   END
 
			        set @Count=@Count+1
				   end

 


   end
   

 
else
begin

	SET @Dt=convert(float,getdate())
	 
		      SELECT @TempGuid=[GUID] from CRM_ServiceContract  WITH(NOLOCK)     
				WHERE SvcContractID=@SvcContractID  
       select @TempGuid as GUID,@SvcContractID as ID,@Guid as test
			IF(@TempGuid!=@Guid)--IF RECORD ALREADY UPDATED BY SOME OTHER USER i.e DIRTY READ      
				BEGIN     
				select 'NOt equal' as Testa 
				 RAISERROR('-101',16,1)     
				END      
				ELSE      
				 BEGIN    
				  	 select   @BillingSchID=BillingScheduleID from CRM_ServiceContract where  SvcContractID=@SvcContractID   
				 
				 if not exists(select SvcContractID  from CRM_ServiceContractextd where SvcContractID=@SvcContractID)
				 begin
				 		INSERT INTO CRM_ServiceContractextd(SvcContractID,[CreatedBy],[CreatedDate])
				VALUES(@SvcContractID, @UserName, convert(float,getdate()))
				 end

	set @UpdateSql='update CRM_ServiceContractextd 
				SET '+@ServiceContractExtraXml+' [ModifiedBy] ='''+ @CreatedBy
				+''',[ModifiedDate] =' + convert(nvarchar,convert(float,getdate())) +' WHERE SvcContractID='+Convert(varchar(100), @SvcContractID)
				exec(@UpdateSql)


				 
				 if(@BillingSchID is null )
				 		 begin
				 		 set 	@BillingSchXML=@ScheduleBillingXml
				
				if(@ScheduleBillingXml<>'')
				begin
				INSERT INTO COM_Schedules(Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,
					FreqRelativeInterval,FreqRecurrenceFactor,StartDate,EndDate,StartTime,EndTime,Message,
				    CompanyGUID,GUID,CreatedBy,CreatedDate)
				    select 'Document',
				    1,
				    X.value('@FreqType','int'),
				    X.value('@FreqInterval','int'),
				    X.value('@FreqSubdayType','int'),
				    X.value('@FreqSubdayInterval','int'),
				    X.value('@FreqRelativeInterval','int'),
				    X.value('@FreqRecurrenceFactor','int'),
				    X.value('@CStartDate','nvarchar(100)'),
				    X.value('@CEndDate','nvarchar(100)'),
				    X.value('@StartTime','nvarchar(100)'),
				    X.value('@EndTime','nvarchar(100)'),
				    X.value('@Message','nvarchar(100)'),
				   @CompanyGUID,
				   NEWID(),
				   @CreatedBy,
				   convert(float,getdate())
				   
				  FROM @BillingSchXML.nodes('/ScheduleBillingXml/Row') as Data(X)
				  	set @BillingSchID=SCOPE_IDENTITY();
				  	 INSERT INTO COM_CCSchedules(CostCenterID,NodeID,ScheduleID,CreatedBy,CreatedDate)
		        VALUES(84,@SvcContractID,@BillingSchID,@UserName,@Dt) 
		        end
		        
				  UPDATE CRM_ServiceContract  
				 SET 
				   [Date]=convert(float,@SvcDate), 
				   DocID=@DocID, 
				   StatusID=@StatusID, 
				   ContractTemplID=@ContractTemplID, 
				   CustomerID=@CustomerID,
				   StartDate=@StartDate, 
				   EndDate=@EndDate, 
				   Description=@Description, 
				   BillingScheduleID=@BillingSchID,
				   [GUID] = @Guid,
				   [ModifiedBy] = @UserName,
				   [ModifiedDate] = @Dt
				 where SvcContractID=@SvcContractID  
				 
				  end
					else
					begin
					UPDATE CRM_ServiceContract  
				 SET 
				   [Date]=convert(float,@SvcDate), 
				   DocID=@DocID, 
				   StatusID=@StatusID, 
				   ContractTemplID=@ContractTemplID, 
				   CustomerID=@CustomerID,
				   StartDate=@StartDate, 
				   EndDate=@EndDate, 
				   Description=@Description, 
				   [GUID] = @Guid,
				   [ModifiedBy] = @UserName,
				   [ModifiedDate] = @Dt
				 where SvcContractID=@SvcContractID  
					end
		
			
				 
				 SET @XML=@ServiceContractXML
 
				  
				 
				    DELETE FROM CRM_ContractLines    
					WHERE [SvcContractID]  =@SvcContractID and ContractLineID not IN(SELECT X.value('@ContractLineID','int')    
					FROM @XML.nodes('/ServiceContractXml/Row') as Data(X)    
					WHERE X.value('@ContractLineID','int')>0) 
					
			 
				 	DELETE FROM COM_CCSchedules    
					WHERE NodeID not IN(SELECT X.value('@ContractLineID','int')    
					FROM @XML.nodes('/ServiceContractXml/Row') as Data(X)    
					WHERE isnull(X.value('@ContractLineID','int'),0)>0) and CostCenterID =84  
					     	
					DELETE FROM COM_Schedules    where ScheduleID not in (select ScheduleID from COM_CCSchedules)	
	                     
	                SET @XML=@ServiceContractXML
	                     
	                insert into #tblServiceContracts(rowno,SvcContractID ,
							   ProductID, 
							   LineNumber ,
							   SerialNumber ,
							   UnitsType ,
							   AllottedUnits ,
							   Price ,
							   Discount ,
							   NetPrice ,
							   SvcFrequencyID ,
							   SvcFrequencyName ,
							   SvcStartDate ,
							   SvcEndDate ,
							   CompanyGUID ,
							   GUID ,
							   CreatedBy ,
							   CreatedDate, 
							   ModifiedBy ,
							   ModifiedDate,
								CostcenterID ,
								ContractLineID,
							   ScheduleID,
							    invDocdetailID,
							   voucherno,
							   employeeid,
							   servicePrice,
							   CLStatus,
								Name,
								StatusID,
								FreqType,
								FreqInterval,
								FreqSubdayType,
								FreqSubdayInterval,
								FreqRelativeInterval,
								FreqRecurrenceFactor,
								schStartDate,
								schEndDate,
								StartTime,
								EndTime,
								Message,
								Description, Parts,
								MaxAmount
			   							   )
								 SELECT  X.value('@rowno','int'),
								  @SvcContractID,
								 X.value('@ProductID','int'),
								 X.value('@LineNumber','int'),     
								X.value('@SerialNumber','varchar(100)'),
								X.value('@UnitsType','int'),
								X.value('@AllottedUnits','int'),    
								X.value('@Price','float'),
								X.value('@Discount','float'),
								X.value('@NetPrice','float'),
								X.value('@SvcFrequencyID','int'),
								 X.value('@SvcFrequencyName','nvarchar(100)'), 
							  convert(float, X.value('@SvcStartDate','datetime')),
							  convert(float,  X.value('@SvcEndDate','datetime')),
								  @CompanyGUID ,
								 @Guid,
								  @UserName,
								 @Dt,
								 @UserName,
								  @Dt  ,   
								84 ,
								X.value('@ContractLineID','int'),
								X.value('@ScheduleID','int'),
									X.value('@InvDocDetailID','int'),
				X.value('@VoucherNo','varchar(100)'),
				X.value('@EmployeeID','int'),
				X.value('@ServicePrice','float'),
					X.value('@Status','int'),
								'Document',
								 X.value('@SchStatus','int'),
								 X.value('@FreqType','int'),
								 X.value('@FreqInterval','int'),
								 X.value('@FreqSubdayType','int'),
								 X.value('@FreqSubdayInterval','int'),
								 X.value('@FreqRelativeInterval','int'),
								 X.value('@FreqRecurrenceFactor','int'),
								 X.value('@CStartDate','nvarchar(100)'),
								 X.value('@CEndDate','nvarchar(100)'),
								 X.value('@StartTime','nvarchar(100)'),
								 X.value('@EndTime','nvarchar(100)'),
								 X.value('@Message','nvarchar(100)'),
								 X.value('@Description','nvarchar(100)'),
								  X.value('@Parts','int'),
								   X.value('@MaxAmount','Float')
								  FROM @XML.nodes('/ServiceContractXml/Row') as Data(X)   
								   WHERE  X.value('@ContractLineID','int')=0
								   
		 

				   select @RowCount=Count(*) from #tblServiceContracts 
				   set @Count=1
				  
				   while(@Count<=@RowCount)
				   begin
				   
				     select @ContarctLineID =ContractLineID,@ScheduleID=ScheduleID from #tblServiceContracts
			         where rowno=@Count

			          if(@ContarctLineID is null or @ContarctLineID=0)
		      	         begin
		      	   
		      	   	  if(@ScheduleID=0)
		      			  begin
							INSERT INTO COM_Schedules(Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,
							FreqRelativeInterval,FreqRecurrenceFactor,StartDate,EndDate,StartTime,EndTime,Message,
							CompanyGUID,GUID,CreatedBy,CreatedDate)
							(select Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,FreqRelativeInterval,
							FreqRecurrenceFactor,convert(varchar(20),schStartDate),convert(varchar(20),schEndDate),StartTime,EndTime,Message,CompanyGUID,GUID,
						   CreatedBy,CreatedDate 
						   from #tblServiceContracts
						   where rowno=@Count)
							SET @ScheduleID=SCOPE_IDENTITY()
							end
							
					  insert into CRM_ContractLines(SvcContractID ,
						   ProductID, 
						   LineNumber ,
						   SerialNumber ,
						   UnitsType ,
						   AllottedUnits ,
						   Price ,
						   Discount ,
						   NetPrice ,
						   SvcFrequencyID ,
						   SvcFrequencyName ,
						   SvcStartDate ,
						   SvcEndDate ,
						   ScheduleID,
						     invDocdetailID,
							   voucherno,
							   employeeid,
							   servicePrice,
							   StatusID,
						   CompanyGUID ,
						   GUID ,
						   CreatedBy ,
						   CreatedDate, 
						   ModifiedBy ,
						   ModifiedDate,Parts,MaxAmount)(select SvcContractID ,ProductID,LineNumber,SerialNumber,UnitsType ,
						   AllottedUnits,Price,Discount,NetPrice,SvcFrequencyID,SvcFrequencyName ,
						 convert(float,SvcStartDate) ,convert(float, SvcEndDate),@ScheduleID ,invdocdetailid,voucherno,employeeid,serviceprice,CLStatus
						 ,CompanyGUID,GUID,CreatedBy,CreatedDate,ModifiedBy,
						   ModifiedDate ,Parts,MaxAmount
						   from #tblServiceContracts
						   where rowno=@Count);
			    
				    SET @ContarctLineID=SCOPE_IDENTITY()
					 select @LineStatus=STATUSID,
					 @SvcStartDate=SvcStartDate,@Assigned=employeeid,@PRODUCTID=ProductID,@SERIALNUMBER=SerialNumber  from CRM_ContractLines where ContractLineID=@ContarctLineID
			  
			  			   --UPDATE CASES STATUS TO CANCELLED IF CONTRACTLINE STATUS IS INACTIVE
						   IF @LineStatus=396
						   BEGIN 
								BEGIN 
								
										UPDATE CRM_CASES SET StatusID=431 WHERE SvcContractID=@SvcContractID AND PRODUCTID=@PRODUCTID AND
										SERIALNUMBER = @SERIALNUMBER AND StatusID=432 AND ContractLineID=@ContarctLineID
								
								END
						
							END
			  
					if(@ScheduleID>-1)
				   begin
				 
						INSERT INTO COM_CCSchedules(CostCenterID,NodeID,ScheduleID,CreatedBy,CreatedDate)
						VALUES(84,@ContarctLineID,@ScheduleID,@UserName,@Dt) 
					end		   
		 		        	        
			   end
			          set @Count=@Count+1
                      end  -- new records 
  
  
                     delete from #tblServiceContracts
                     insert into #tblServiceContracts(rowno,SvcContractID ,    
			   ProductID, 
			   LineNumber ,
			   SerialNumber ,
			   UnitsType ,
			   AllottedUnits ,
			   Price ,
			   Discount ,
			   NetPrice ,
			   SvcFrequencyID ,
			   SvcFrequencyName ,
			   SvcStartDate ,
			   SvcEndDate ,
			   CompanyGUID ,
			   GUID ,
			   CreatedBy ,
			   CreatedDate, 
			   ModifiedBy ,
			   ModifiedDate,
			    CostcenterID ,
			    ContractLineID,
			   ScheduleID,
			     invDocdetailID,
							   voucherno,
							   employeeid,
							   servicePrice,
							   CLStatus,
		        Name,
				StatusID,
				FreqType,
				FreqInterval,
				FreqSubdayType,
				FreqSubdayInterval,
				FreqRelativeInterval,
				FreqRecurrenceFactor,
				schStartDate,
				schEndDate,
				StartTime,
				EndTime,
				Message,
				Description ,Parts,MaxAmount
			   			   )
				 SELECT  ROW_NUMBER() over (order by (select 1)) ,
				  @SvcContractID,
				 X.value('@ProductID','int'),
				 X.value('@LineNumber','int'),     
				X.value('@SerialNumber','varchar(100)'),
				X.value('@UnitsType','int'),
				X.value('@AllottedUnits','int'),    
				X.value('@Price','float'),
				X.value('@Discount','float'),
				X.value('@NetPrice','float'),
				X.value('@SvcFrequencyID','int'),
				 X.value('@SvcFrequencyName','nvarchar(100)'), 
			  convert(float, X.value('@SvcStartDate','datetime')),
			  convert(float,  X.value('@SvcEndDate','datetime')),
				  @CompanyGUID ,
				 @Guid,
				  @UserName,
				 @Dt,
				 @UserName,
				  @Dt  ,   
				84 ,
				X.value('@ContractLineID','int'),
			    X.value('@ScheduleID','int'),
					X.value('@InvDocDetailID','int'),
				X.value('@VoucherNo','varchar(100)'),
				X.value('@EmployeeID','int'),
				X.value('@ServicePrice','float'),
					X.value('@Status','int'),
		        'Document',
				 X.value('@SchStatus','int'),
				 X.value('@FreqType','int'),
				 X.value('@FreqInterval','int'),
				 X.value('@FreqSubdayType','int'),
				 X.value('@FreqSubdayInterval','int'),
				 X.value('@FreqRelativeInterval','int'),
				 X.value('@FreqRecurrenceFactor','int'),
				 X.value('@CStartDate','nvarchar(100)'),
				 X.value('@CEndDate','nvarchar(100)'),
				 X.value('@StartTime','nvarchar(100)'),
				 X.value('@EndTime','nvarchar(100)'),
				 X.value('@Message','nvarchar(100)'),
				 X.value('@Description','nvarchar(100)'),
				   X.value('@Parts','int'),
								   X.value('@MaxAmount','Float')
				  FROM @XML.nodes('/ServiceContractXml/Row') as Data(X)   
				   WHERE  X.value('@ContractLineID','int')>0
				   
				     select @RowCount=Count(*) from #tblServiceContracts 
				     set @Count=1
				   
				    while(@Count<=@RowCount)
				     begin
				       select @ContarctLineID =ContractLineID ,@ScheduleID=ScheduleID from #tblServiceContracts
			            where rowno=@Count

                       update COM_Schedules set 
								Name=S.Name,
								StatusID=S.StatusID,
								FreqType=S.FreqType,
								FreqInterval=S.FreqInterval,
								FreqSubdayType=S.FreqSubdayType,
								FreqSubdayInterval=S.FreqSubdayInterval,
								FreqRelativeInterval=S.FreqRelativeInterval,
								FreqRecurrenceFactor=S.FreqRecurrenceFactor,
								StartDate=S.schStartDate,
								EndDate=S.schEndDate,
								StartTime=S.StartTime,
								EndTime=S.EndTime,
								Message=S.Message,
								CompanyGUID=S.CompanyGUID
								,GUID=S.GUID
								,ModifiedBy=S.ModifiedBy
								from COM_Schedules C,#tblServiceContracts S
								where  c.ScheduleID  =S.ScheduleID 
								and S.ContractLineID= @ContarctLineID
						
     	     	      if(@ScheduleID=0)
			            begin
					    
			    			INSERT INTO COM_Schedules(Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,
							FreqRelativeInterval,FreqRecurrenceFactor,StartDate,EndDate,StartTime,EndTime,Message,
							CompanyGUID,GUID,CreatedBy,CreatedDate)
							(select Name,StatusID,FreqType,FreqInterval,FreqSubdayType,FreqSubdayInterval,FreqRelativeInterval,
							FreqRecurrenceFactor,convert(varchar(20),schStartDate),convert(varchar(20),schEndDate),StartTime,EndTime,Message,CompanyGUID,GUID,
							CreatedBy,CreatedDate 
							from #tblServiceContracts
							where rowno=@Count)
							SET @ScheduleID=SCOPE_IDENTITY()
					       
						   INSERT INTO COM_CCSchedules(CostCenterID,NodeID,ScheduleID,CreatedBy,CreatedDate)
						   VALUES(84,@ContarctLineID,@ScheduleID,@UserName,@Dt) 
		        
			           end

				      update CRM_ContractLines
				        set
				           ProductID=S.ProductID, 
						   LineNumber=S.LineNumber ,
						   SerialNumber=S.SerialNumber ,
						   UnitsType=S.UnitsType ,
						   AllottedUnits=S.AllottedUnits ,
						   Price=S.Price ,
						   Discount=S.Discount ,
						   ScheduleID=@ScheduleID,
						     invDocdetailID=S.invDocdetailID,
							   voucherno=S.voucherno,
							   employeeid=S.employeeid,
							   servicePrice=S.servicePrice,
							   StatusID=S.CLStatus,
						   NetPrice=S.NetPrice ,
						   SvcFrequencyID=S.SvcFrequencyID ,
						   SvcFrequencyName=S.SvcFrequencyName ,
						   SvcStartDate =convert(float,S.SvcStartDate),
						   SvcEndDate=convert(float, S.SvcEndDate) ,
						   CompanyGUID =S.CompanyGUID,Parts=S.Parts,MaxAmount=S.MaxAmount,
						   GUID =S.GUID,
						   ModifiedBy=S.ModifiedBy ,
						   ModifiedDate=S.ModifiedDate
						   from CRM_ContractLines C,#tblServiceContracts S
						   where   C.SvcContractID=S.SvcContractID and 
						   C.ContractLineID=@ContarctLineID and S.ContractLineID=@ContarctLineID
						   
						      select @LineStatus=STATUSID,
						 @SvcStartDate=SvcStartDate,@Assigned=employeeid,@PRODUCTID=ProductID,@SERIALNUMBER=SerialNumber  from CRM_ContractLines where ContractLineID=@ContarctLineID
			  
			  			   --UPDATE CASES STATUS TO CANCELLED IF CONTRACTLINE STATUS IS INACTIVE
						   IF @LineStatus=396
						   BEGIN 
								BEGIN 
										  
										UPDATE CRM_CASES SET StatusID=431 WHERE SvcContractID=@SvcContractID AND PRODUCTID=@PRODUCTID AND
										SERIALNUMBER = @SERIALNUMBER AND StatusID=432 AND ContractLineID=@ContarctLineID
								
								END
						
							END
							
							
			       set @Count=@Count+1;
				     
				     end
				     
			 
 
				 
					   END  

  		
  
    
  END   
  --validate Data External function
		DECLARE @tempCCCode NVARCHAR(200)
		set @tempCCCode=''
		select @tempCCCode=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=84 and Mode=9
		if(@tempCCCode<>'')
		begin
			exec @tempCCCode 84,@SvcContractID,@UserID,@LangID
		end   
 COMMIT TRANSACTION  
 SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID    
SET NOCOUNT OFF;      
RETURN @SvcContractID  
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
