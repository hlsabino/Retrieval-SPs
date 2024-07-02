USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDoc_ProjectPlan]
	@InvDocDetID [int],
	@DocID [int],
	@CostCenterID [int],
	@DimensionID [int],
	@DimensionNodeID [int],
	@ProjectXML [nvarchar](max),
	@CompanyGUID [varchar](50),
	@UserName [nvarchar](50),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION        
BEGIN TRY        
SET NOCOUNT ON;      
	
	declare @retVal INT,@CNT FLOAT,@SQL NVARCHAR(MAX),@NodeID INT,@XML xml,@Groups NVARCHAR(MAX),@Roles NVARCHAR(MAX),@Users NVARCHAR(MAX)
	declare @cctablename nvarchar(50),@Fldname nvarchar(50),@Val nvarchar(50)
	
	select @cctablename=tablename from ADM_Features WITH(NOLOCK) where FeatureID=@DimensionID

	set @XML=@ProjectXML
	declare @Preftab table (Name nvarchar(100),Value nvarchar(max)) 	
	
	insert into @Preftab
	SELECT Name,Value FROM ADM_GlobalPreferences with(nolock)
	WHERE Name IN ('PMLevel1Dimension','PMLevel2Dimension','PMLevel3Dimension','PMTaskDimension','ProjPlanDim')
	
	SET @SQL='select @NodeID=dcalpha10 from com_docTextData WITH(NOLOCK) WHERE InvDocDetailsID ='+CONVERT(NVARCHAR,@InvDocDetID)
	--print @SQL
	EXEC sp_executesql @SQL,N'@NodeID INT OUTPUT',@NodeID output

	set @Groups='set CCNID'+CONVERT(NVARCHAR,(@DimensionID-50000))+'='+CONVERT(NVARCHAR,@NodeID)
	
	set @CNT=0
	WHILE(@CNT<3)
	BEGIN
		set @CNT=@CNT+1
		set @retVal=0
		select @retVal=Value from @Preftab where Name='PMLevel'+CONVERT(NVARCHAR,@CNT)+'Dimension' and isnumeric(Value)=1
		if (@retVal>50000)
		BEGIN
		   set @Groups=@Groups+',CCNID'+CONVERT(NVARCHAR,(@retVal-50000))+'=dcCCNID'+CONVERT(NVARCHAR,(@retVal-50000))
		END
	END	
	
	set @retVal=0
	select @retVal=Value from @Preftab where Name='PMTaskDimension' and isnumeric(Value)=1
	if (@retVal>50000)
	BEGIN	
	   set @Groups=@Groups+',CCNID'+CONVERT(NVARCHAR,(@retVal-50000))+'=dcCCNID'+CONVERT(NVARCHAR,(@retVal-50000))	
	END
	
	set @retVal=0
	select @retVal=Value from @Preftab where Name='ProjPlanDim' and isnumeric(Value)=1
	if (@retVal>50000)
	BEGIN	
	   set @Groups=@Groups+',CCNID'+CONVERT(NVARCHAR,(@retVal-50000))+'=dcCCNID'+CONVERT(NVARCHAR,(@retVal-50000))	
	END
	
	SET @SQL='UPDATE COM_CCCCData '+@Groups+'
	 From COM_DocCCData c WITH(NOLOCK)
	 WHERE InvDocDetailsID ='+CONVERT(NVARCHAR,@InvDocDetID) +' and COSTCENTERID='+CONVERT(NVARCHAR,@DimensionID)+' AND NodeID='+CONVERT(NVARCHAR,@DimensionNodeID)
	--print @SQL
	EXEC(@SQL)
	
	set @SQL='UPDATE COM_DocTextData 
	set dcAlpha25=(case when (dcAlpha25 is null or dcAlpha25='''') then dcAlpha15 else dcAlpha25 end)
	,dcAlpha26=(case when (dcAlpha26 is null or dcAlpha26='''') then dcAlpha16 else dcAlpha26 end)
	WHERE InvDocDetailsID='+CONVERT(NVARCHAR,@InvDocDetID)
	EXEC(@SQL)
	
	set @Fldname=''
	SELECT @Fldname=PrefValue FROM [com_documentpreferences] with(nolock)
	where prefname='MandAttachfld' and PrefValue<>''
	if(@Fldname<>'')
	BEGIN
		set @Val=''
		set @SQL='select @Val='+@Fldname+' from COM_DocTextData WITH(NOLOCK)		
		WHERE InvDocDetailsID='+CONVERT(NVARCHAR,@InvDocDetID)
		EXEC sp_executesql @SQL,N'@Val nvarchar(50) OUTPUT',@Val output
		if(@Val in('true','1','Yes'))
			set @SQL='DebitDays=1'
		else
			set @SQL='DebitDays=0'	
	END
	ELSE
		set @SQL='DebitDays=0'
		
	
	set @CNT=0
	WHILE(@CNT<26)
	BEGIN
		set @CNT=@CNT+1
		set @SQL=@SQL+',[ccAlpha'+CONVERT(NVARCHAR,@CNT)+'] = C.[dcAlpha'+CONVERT(NVARCHAR,@CNT)+']'
	end
	
		
	SET @SQL='UPDATE '+@cctablename+' 
		set '+@SQL+'
	 From COM_DocTextData c WITH(NOLOCK)
	 WHERE C.InvDocDetailsID ='+CONVERT(NVARCHAR,@InvDocDetID) +' AND NodeID='+CONVERT(NVARCHAR,@DimensionNodeID)
	print @SQL
	EXEC(@SQL)
	
	--set @actid=0
	--select @actid=ActivityID from CRM_Activities with(NOLOCK)
	--where CostCenterID=@DimensionID and NodeID=@DimensionNodeID
	--if(@actid=0)
	--BEGIN
	--	INSERT INTO CRM_Activities( ActivityTypeID, ScheduleID, CostCenterID, NodeID, StatusID, Subject, Priority,  
	--		Location, IsAllDayActivity,  
	--		  CustomerID, Remarks,  ActualCloseDate,ActualCloseTime, StartDate,EndDate,StartTime,EndTime, CompanyGUID, GUID,  CreatedBy, CreatedDate,CustomerType,AssignUserID)
	--		VALUES (@ActivityTypeID,@ScheduleID,@CCID,@NID,@STATUS,@SUBJECT,@PRIORITY,@LOCATION,@IsAllDayActivity,@CUSTOMERID,@REMARKS
	--		,CONVERT(FLOAT,@CLOSEDATE),@CLOSETIME,CONVERT(FLOAT,@STARTDATE),CONVERT(FLOAT,@ENDDATE),@STARTTIME,@ENDTIME,@CompanyGUID,NEWID(),@UserName,CONVERT(FLOAT,GETDATE()),@CUSTOMERTYPE,@AssignedUser)
	--		 set @ACTIVIYID=scope_identity()  
	--END
	--ELSE
	--BEGIN

		
	--END	
	
	DECLARE @TblApp AS TABLE(G nvarchar(max))
	set @Groups=''
	set @Roles=''
	set @Users=''
	select @Groups=X.value('@Groups','varchar(max)'),@Roles=X.value('@Roles','varchar(max)'),@Users=X.value('@Users','varchar(max)')
	from @xml.nodes('/ProjectPlanXML/AssignXML') as Data(X)
	
	INSERT INTO @TblApp(G)
	EXEC [SPSplitString] @Groups,','
	

	insert into INV_DocExtraDetails(InvDocDetailsID,[Type],[RefID])
	select @InvDocDetID,6,G from @TblApp
	
	delete from @TblApp
	INSERT INTO @TblApp(G)
	EXEC [SPSplitString] @Roles,','

	insert into INV_DocExtraDetails(InvDocDetailsID,[Type],[RefID])
	select @InvDocDetID,7,G from @TblApp
	
	delete from @TblApp
	INSERT INTO @TblApp(G)
	EXEC [SPSplitString] @Users,','
	
	insert into INV_DocExtraDetails(InvDocDetailsID,[Type],[RefID])
	select @InvDocDetID,8,G from @TblApp
	
	select @Groups=X.value('@Dependencies','varchar(max)')
	from @xml.nodes('/ProjectPlanXML') as Data(X)

    delete from @TblApp
	INSERT INTO @TblApp(G)
	EXEC [SPSplitString] @Groups,','
	
	insert into INV_DocExtraDetails(InvDocDetailsID,[Type],Fld1)
	select @InvDocDetID,9,G from @TblApp
	
	EXEC spCOM_SetNotifEvent 153,@CostCenterID,@DocID,@CompanyGUID,@UserName,@UserID,@RoleID   

     
COMMIT TRANSACTION          
SET NOCOUNT OFF;       
END TRY        
BEGIN CATCH  
	IF(@retVal=-999)
		RETURN -999      
 IF ERROR_NUMBER()=50000      
 BEGIN          
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=1      
 END      
 ELSE      
 BEGIN      
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine      
  FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=1      
 END      
 ROLLBACK TRANSACTION      
 SET NOCOUNT OFF        
 RETURN -999         
END CATCH
GO
