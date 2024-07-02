USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPAY_EmployeeImportDetails]
	@Flag [int],
	@Where [nvarchar](max),
	@ParentCCID [int] = 0,
	@UserID [int] = 1,
	@LangId [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY   
SET NOCOUNT ON;

DECLARE @CostCenterId INT,@ResourceMax INT,@strQry NVarchar(max),@Doj DateTime, @TableName NVarchar(max), @Count1 int, @str1 nvarchar(max),@StatusID int 
SET @strQry=''
SET @str1=''
SET @CostCenterId=50051

if(@Flag=0)--STATUS 
begin
	if((select count(*) from Com_Status with(nolock) where CostCenterID=50051 and Status=@Where)<=0)
	begin
		EXEC [spCOM_SetInsertResourceData] @Where,@Where,'Payroll','Admin',1,@ResourceMax output
		INSERT INTO COM_Status(CostCenterID,FeatureID,RESOURCEID,Status,IsUserDefined,CompanyGUID,GUID,CreatedBy,CreatedDate)     
		VALUES(@CostCenterId,@CostCenterId,@ResourceMax,@Where,0,'',NEWID(),'Admin',CONVERT(FLOAT,GETDATE()))  --INSERT ACTIVE STAUS FOR FEATURE  
	end
	select * from Com_Status with(nolock) where CostCenterID=50051 and Status=@Where
end

else if(@Flag=1)--LOOKUP
begin
	if((select count(*) from Com_Lookup with(nolock) where Name=@Where and Lookuptype=@ParentCCID)<=0)
	begin
		EXEC [spCOM_SetInsertResourceData] @Where,@Where,'Payroll','Admin',1,@ResourceMax output
		INSERT INTO COM_Lookup(LookupType,Name,ResourceID,Status,CompanyGUID,GUID,CreatedBy,CreatedDate)  
		VALUES(@ParentCCID,@Where,@ResourceMax,1,'',NEWID(),'Admin',convert(float,getdate()))  
	end
	select * from Com_Lookup with(nolock) where Name=@Where and Lookuptype=@ParentCCID
end

else if(@Flag=2)--GROUP
begin
	if((select count(*) from Com_CC50051 with(nolock) where Name=@Where and IsGroup=1)<=0)
	begin
		SET @Doj=convert(datetime,getdate())
		SET @strQry='Name=N'''+ CONVERT(VARCHAR,@Where)  +''','
		SET @strQry=@strQry+'EmpType=''0'',DOJ=''0'',Gender='''',ccAlpha3=''0'',ccAlpha2=''1/1/1900 10:54:05 AM'',FHName=N'''',MaritalStatus='''',Nationality='''',Religion='''',PayType='''',ContactNo=N'''',Email=N'''',EmgContactNo=N'''',EmgContactName=N'''',WeeklyOff1=''None'',WeeklyOff2=''None'',IsAllowOT=''No'',NextAppraisalDate=NULL,CanCreateUser=''No'',RoleID='''',IsManager=''No'',CurrencyID=''0'',PaymentMode=''Cash'',iBank=''0'',BankAccNo=N'''',IBANNo=N'''',PANNo=N'''',PFNo=N'''',ESINo=N'''',PassportNo=N'''',PassportIssDate=NULL,PassportExpDate=NULL,VisaNo=N'''',VisaIssDate=NULL,VisaExpDate=NULL,IqamaNo=N'''',IqamaIssDate=NULL,IqamaExpDate=NULL,ContractNo=N'''',ContractIssDate=NULL,ContractExpDate=NULL,ContractExtendDate=NULL,IDNo=N'''',IDIssDate=NULL,IDExpDate=NULL,LicenseNo=N'''',LicenseIssDate=NULL,LicenseExpDate=NULL,MedicalNo=N'''',MedicalIssDate=NULL,MedicalExpDate=NULL,ccAlpha1=N'''',OpLeavesAsOn=NULL,OpLOPAsOn=NULL,OpLOPDays=N''0'',OpVacationDays=N''0'',OpVacationSalary=N''0'',OpTickets=N''0'',ALCalculation=N'''',VacationPeriod=''Yearly'',VacDaysPeriod=''Yearly'',VacDaysPerMonth=''0'',TktAdults=N''0'',TktChildren=N''0'',TktInfants=N''0'',TktDestination=N'''',TktAirClass='''',SalaryAccID=''0'',PayableAccID=''0'','
		print @strQry
		print @Doj
		exec spPAY_SetEmployee   0 ,@Where,@Where ,@Where ,250 ,50104 ,@DOJ,null ,0 ,'Male',0 ,null ,'' ,'' ,'' ,'' ,'' , @strQry,'IsManual=0,SeriesEnd=0,SeriesStart=0,' ,'' ,'' ,'' ,'',0 ,'' ,'' ,2 ,True ,'' ,1 ,0 ,'admin','' ,'admin' ,1 ,1 ,1 
	end
	select * from Com_CC50051 with(nolock) where Name=@Where and IsGroup=1
end

else if (@Flag=3)--DIMENSIONS/ACCOUNTS
begin
	select @TableName=ParentCostCenterSysName from adm_costcenterdef with(nolock) where costcenterid=50051 and parentCostCenterID=@ParentCCID 
	IF(@Where='All' and @ParentCCID=50053)
	BEGIN
		set @Where='***ALL***'
	END
	set @str1='@count1 int output' 
	if(@ParentCCID=2)
	begin 
		set @strQry='set @count1=(select count(*) from '+ convert(varchar,@TableName)+' WITH(nolock) where AccountName = '''+@Where+''')'  
	end
	else
	begin
		set @strQry='set @count1=(select count(*) from '+ convert(varchar,@TableName)+' WITH(nolock) where Name = '''+@Where+''' or Code = '''+@Where+''')'  
	end
	print @strQry
	exec sp_executesql @strQry, @str1, @count1 OUTPUT    
	
	if(@count1<=0)
	begin
	print 't'
		set @StatusID=(select top 1 StatusID from COM_Status with(nolock) where costcenterid=@ParentCCID)
		if(@ParentCCID=2)
		begin
			exec spACC_SetAccount  0 ,@Where ,@Where ,@Where ,2 ,@StatusID ,1 ,False ,0 ,0 ,0 ,0 ,1 ,2 ,3 ,4 ,5 ,0 ,0 ,False ,0 ,0 ,0 ,0 ,0 ,'admin' ,'' ,'' ,'admin' ,'' ,'' ,'' ,'' ,'' ,'' ,'' ,'<ASSIGNMAPXML Dimension="0" Action="ASSIGN"><ASSIGN></ASSIGN></ASSIGNMAPXML>' ,0 ,1 ,1 ,1 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,0 ,'' ,0 ,NULL ,False ,0 ,NULL ,False
		end
		else
		begin
			exec spCOM_SetCostCenter  0 ,2 ,False ,@Where,@Where ,@Where ,3 ,2,0 ,0 ,0 ,0 ,@StatusID ,'' ,'','' ,'' ,'' ,'' ,NULL ,'' ,@ParentCCID ,'admin' ,'' ,'admin' ,0 ,1 ,1 ,1 ,NULL ,0 ,0 ,NULL ,NULL ,False
		end
	end
	set @strQry=''
	if(@ParentCCID=2)
	begin 
		set @strQry='select AccountID NodeID,AccountCode Code,AccountName Name from '+ convert(varchar,@tableName)+' WITH(nolock) where AccountName = '''+@Where+''''  
	end
	else
	begin
		set @strQry='select * from '+ convert(varchar,@tableName)+' WITH(nolock) where Name = '''+@Where+''' or Code = '''+@Where+''''  
--		print  (@strQry)
	end
	print @strQry
	EXEC sp_executesql @strQry
end
	
SET NOCOUNT OFF;  
--RETURN 1  
END TRY  
BEGIN CATCH    
  --Return exception info [Message,Number,ProcedureName,LineNumber]    
  IF ERROR_NUMBER()=50000  
  BEGIN  
   SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
  END  
  ELSE  
  BEGIN  
   SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
   FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
  END   
SET NOCOUNT OFF    
RETURN -999     
END CATCH
GO
