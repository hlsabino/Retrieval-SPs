USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_GetCostCenterSummary]
	@GridViewID [int],
	@Position [int],
	@PageSize [int],
	@WhereCondition [nvarchar](max),
	@DivisionWhere [nvarchar](max) = NULL,
	@LocationWhere [nvarchar](max) = NULL,
	@lft [int],
	@DocDate [datetime] = null,
	@DueDate [datetime] = null,
	@LinkDefID [nvarchar](50) = NULL,
	@UserID [int] = 1,
	@LangID [int] = 1,
	@direction [int] = 0,
	@SearchSeqNo [int] = 0,
	@PendingList [bit] = 0,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY                
SET NOCOUNT ON                
                
	--Declaration Section                
	Declare @HasAccess bit,@CostCenterID int,@Primarycol varchar(150),@CostCenterTableName nvarchar(50),@CC int,@isproj int                
	Declare @TableName nvarchar(50),@ColCostCenterPrimary varchar(50),@SQL nvarchar(max),@AttachUserWiseQuery nvarchar(max),@Where nvarchar(max)              
	Declare @CostCenterColID INT,@Cnt int,@I INT,@STRJOIN nvarchar(max),@strColumns nvarchar(max),@IsExtraCostCenterDisplayed BIT                
	DECLARE @tempgroup nvarchar(max), @Dt float,@QtyDec nvarchar(5),@AmtDec nvarchar(5),@Depth nvarchar(max)=''             
	Declare @SysColumnName nvarchar(50), @UserColumnName nvarchar(50), @ColumnDataType nvarchar(50),@IsColumnUserDefined BIT,@ColumnCostCenterID INT                
	declare @Pcol nvarchar(500),@IsContDisplayed bit,@IsAddressDisplayed bit,@IsCode bit,@TFDIm int,@TfUAD BIT,@userAssignedDims nvarchar(max)
	DECLARE @PREFSALES NVARCHAR(100),@RestrictionWhere nvarchar(max),@FORMAT nvarchar(10)        
	declare @Dimensionlist nvarchar(max),@IsUserWiseExists bit,@IsGroupUserWiseExists bit,@Accountlist nvarchar(max)
	DECLARE @TFuserAssignedDims nvarchar(max),@TFuserAssignedDim INT,@R INT,@TDC INT,@TABNAME NVARCHAR(100),@TFJoinCond NVARCHAR(MAX),@TFUADIM INT
	DECLARE @MAPSQL nvarchar(max)=''
	SELECT @QtyDec=isnull(VALUE,2) FROM ADM_GLOBALPREFERENCES with (nolock) WHERE NAME='DecimalsinQty' and isnumeric(VALUE)=1    
	SELECT @AmtDec=isnull(VALUE,2) FROM ADM_GLOBALPREFERENCES with (nolock) WHERE NAME='DecimalsinRate' and isnumeric(VALUE)=1       
	SELECT @FORMAT=VALUE FROM ADM_GLOBALPREFERENCES with (nolock) WHERE NAME='Commas'
	
	--Check for manadatory paramters                
	if(@GridViewID < 1)                
		RAISERROR('-100',16,1)
	          
	--Get CostCenterID by GridviewID                
	SELECT @Where=SearchFilter ,@CostCenterID=FeatureID FROM ADM_GridView  WITH(NOLOCK)                
	WHERE  GridViewID=@GridViewID
	
	--User acces check                
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,2)                
    
    DECLARE @TblUsers TABLE(iUserID int)
    DECLARE @TblUserDims TABLE(ID INT IDENTITY(1,1),iUserID int)
    DECLARE @TblUserDimlist TABLE(ID INT IDENTITY(1,1),iUserID int) 
      
    SELECT @Dimensionlist=isnull(VALUE,0) FROM ADM_GLOBALPREFERENCES with (nolock) WHERE NAME='Dimension List'  
	set @IsUserWiseExists=0 
	
	INSERT INTO @TblUsers    
	exec spsplitstring @Dimensionlist,','  
	
	IF(EXISTS(SELECT * FROM @TblUsers WHERE iUserID=@CostCenterID)) --CHECK FOR USER WISE     
		SET @IsUserWiseExists=1         
	
	INSERT INTO @TblUserDimlist    
	exec spsplitstring @Dimensionlist,',' 
	
	delete from @TblUsers
	
	SET @Dimensionlist=''
	SELECT @Dimensionlist=isnull(VALUE,0) FROM ADM_GLOBALPREFERENCES with (nolock) WHERE NAME='DimensionGroup List'    
	set @IsGroupUserWiseExists=0
	
	INSERT INTO @TblUsers    
	exec spsplitstring @Dimensionlist,',' 
	
	IF(@IsUserWiseExists=1 AND EXISTS(SELECT * FROM @TblUsers WHERE iUserID=@CostCenterID)) --CHECK FOR USER WISE     
		SET @IsGroupUserWiseExists=1   
	
	set @TfUAD=0
	set @TFUADIM=0
	SELECT @TFDIm=isnull(VALUE,0) FROM ADM_GLOBALPREFERENCES with (nolock) WHERE NAME='TFDim' and isnumeric(VALUE)=1    
	if(@TFDIm>50000  or @TFDIm=92 or @TFDIm=93 or @TFDIm=94)
	BEGIN
		SET @Dimensionlist=''
		SELECT @Dimensionlist=isnull(VALUE,0) FROM ADM_GLOBALPREFERENCES with (nolock) WHERE NAME='TFUserAssignedDims'    
		
		delete from @TblUsers
		
		INSERT INTO @TblUsers    
		exec spsplitstring @Dimensionlist,',' 
		
		INSERT INTO @TblUserDims    
		exec spsplitstring @Dimensionlist,',' 
		
		IF EXISTS(SELECT * FROM @TblUsers WHERE iUserID=@CostCenterID)
			SET @TfUAD=1  
		IF EXISTS(SELECT * FROM @TblUserDimlist WHERE iUserID=@TFDIm)
			SET @TFUADIM=1  
		
		--User Wise Dimensions - Tree filter on user assigned dimension
		SELECT @TDC=COUNT(*) FROM @TblUserDims
		IF(@TDC>0 AND @TFUADIM=1 AND @TFDIm=@CostCenterID)
		BEGIN
			SET @TFJoinCond=''
			set @TFuserAssignedDims=''
			IF( @CostCenterID=94)
				set @TFJoinCond=@TFJoinCond+' JOIN  COM_CCCCData CCM1 WITH(NOLOCK) ON CCM1.CostCenterID='+convert(nvarchar,@CostCenterID)+'  AND CCM1.NodeID=B.TenantID '
			ELSE IF( @CostCenterID=92)
				set @TFJoinCond=@TFJoinCond+' JOIN  COM_CCCCData CCM1 WITH(NOLOCK) ON CCM1.CostCenterID='+convert(nvarchar,@CostCenterID)+'  AND CCM1.NodeID=B.NodeID '
			ELSE IF( @CostCenterID=93)
				set @TFJoinCond=@TFJoinCond+' JOIN  COM_CCCCData CCM1 WITH(NOLOCK) ON CCM1.CostCenterID='+convert(nvarchar,@CostCenterID)+'  AND CCM1.NodeID=A.UnitID '
			ELSE
				set @TFJoinCond=@TFJoinCond+' JOIN  COM_CCCCData CCM1 WITH(NOLOCK) ON CCM1.CostCenterID='+convert(nvarchar,@CostCenterID)+'  AND CCM1.NodeID=CMI.NodeID '
			SET @R=1
			WHILE(@R<=@TDC)
			BEGIN
				IF((SELECT Count(*) FROM @TblUserDims D, COM_CostCenterCostCenterMap U with(nolock)  where U.ParentCostCenterID=7 and U.ParentNodeID=convert(nvarchar,@userid) AND D.iUserID=U.CostCenterID and D.ID=@R)>0)
				BEGIN
					SELECT @TFuserAssignedDim=iUserID FROM @TblUserDims WHERE ID=@R
					SELECT @TABNAME= TableName FROM ADM_Features with(nolock) WHERE FeatureID=@TFuserAssignedDim 
					IF(@TFuserAssignedDim>50000)
					BEGIN
						IF(@R=1)
						BEGIN
							SET @TFuserAssignedDims=CONVERT(NVARCHAR(MAX),@TFuserAssignedDim)
							--SET @TFJoinCond=@TFJoinCond+' JOIN '+ CONVERT(NVARCHAR,@TABNAME) +' CCD'+CONVERT(NVARCHAR,@TFuserAssignedDim-50000)+' with(nolock) on  CCMU.CostCenterID IN ('+convert(nvarchar,@TFuserAssignedDim)+') and CCMU.NodeID=CCD'+CONVERT(NVARCHAR,@TFuserAssignedDim-50000)+'.NodeID AND  CCM1.CCNID'+CONVERT(NVARCHAR,@TFuserAssignedDim-50000)+'=CCD'+CONVERT(NVARCHAR,@TFuserAssignedDim-50000)+'.NodeID '							
							SET @TFJoinCond=@TFJoinCond+' JOIN '+ CONVERT(NVARCHAR,@TABNAME) +' CCD'+CONVERT(NVARCHAR,@TFuserAssignedDim-50000)+' with(nolock) on    CCM1.CCNID'+CONVERT(NVARCHAR,@TFuserAssignedDim-50000)+'=CCD'+CONVERT(NVARCHAR,@TFuserAssignedDim-50000)+'.NodeID '							
						END
						ELSE
						BEGIN
							IF (ISNULL(@TFuserAssignedDims,'')='')
								SET @TFuserAssignedDims=CONVERT(NVARCHAR(MAX),@TFuserAssignedDim)
							ELSE
								SET @TFuserAssignedDims=@TFuserAssignedDims+','+CONVERT(NVARCHAR(MAX),@TFuserAssignedDim)
							SET @TFJoinCond=@TFJoinCond+' JOIN  COM_CostCenterCostCenterMap CCMUU'+ CONVERT(NVARCHAR,@R) +' with(nolock) on CCMUU'+ CONVERT(NVARCHAR,@R) +'.ParentCostCenterID = 7 and CCMUU'+ CONVERT(NVARCHAR,@R) +'.ParentNodeID='+convert(nvarchar,@userid)+''
							SET @TFJoinCond=@TFJoinCond+' JOIN '+ CONVERT(NVARCHAR,@TABNAME) +' CCD'+CONVERT(NVARCHAR,@TFuserAssignedDim-50000)+' with(nolock) on  CCMUU'+ CONVERT(NVARCHAR,@R) +'.CostCenterID IN ('+convert(nvarchar,@TFuserAssignedDim)+') and CCMUU'+ CONVERT(NVARCHAR,@R) +'.NodeID=CCD'+CONVERT(NVARCHAR,@TFuserAssignedDim-50000)+'.NodeID AND  CCM1.CCNID'+CONVERT(NVARCHAR,@TFuserAssignedDim-50000)+'=CCD'+CONVERT(NVARCHAR,@TFuserAssignedDim-50000)+'.NodeID '
						END
					END
				END
			SET @R=@R+1					
			END
		END
		delete from @TblUserDims
		delete from @TblUserDimlist
		--
		delete from @TblUsers	
	END
	 
	if(@CostCenterID>50000 and @CostCenterID=(select value from adm_globalpreferences WITH(NOLOCK)
		where name='ProjectManagementDimension' and isnumeric(value)=1))
		set @isproj=1
	else
		set @isproj=0
		
	SET @Dt=convert(float,getdate())              
	set @tempgroup=''              
	SET @strColumns =''                
	SET @STRJOIN =''                
    
    --Get TableName of CostCenter                         
	SELECT @TableName=TableName,@Pcol=isnull('A.'+PrimaryKey,'A.NodeID ') FROM ADM_Features with(nolock) WHERE FeatureID=@CostCenterID
	if(@CostCenterID between 40000 and 50000 )                
		set @Pcol='A.DocID  '

	SET @STRJOIN='FROM '+@TableName+' A WITH(NOLOCK) '
	if (@CostCenterID >50000 AND @UserID!=1 AND (@isproj=1 or (@IsGroupUserWiseExists=0 AND @IsUserWiseExists=1)))
		set @STRJOIN=@STRJOIN+' join '+@TableName+' CG WITH(NOLOCK) on A.lft between CG.lft and CG.rgt ' 
		
	if(@Where is not null and @Where like '%grp.%')
		set @STRJOIN=@STRJOIN+' join '+@TableName+' Grp WITH(NOLOCK) on a.lft between Grp.lft and Grp.rgt '

	--Control Accounts Filter
	set @Accountlist=''
	declare @TRC INT,@RC INT,@AccGrpID int,@sWhere nvarchar(max)
	SET @RC=1
	set @sWhere=''
	if @CostCenterID=2 and @WhereCondition is not null
	begin
		if(@WhereCondition like '%#DEBTORTEE#%')
		begin
			set @STRJOIN=@STRJOIN+' join '+@TableName+' Gp WITH(NOLOCK) on a.lft between Gp.lft and Gp.rgt '
			select @Accountlist= isnull(Value,'') from adm_globalpreferences with(nolock) where Name='DebtorsControlGroup'
			
			if(@Accountlist!='')
				set @sWhere= ' (Gp.AccountID in( '+convert(nvarchar(500),@Accountlist)+')) '
			
			set @WhereCondition=replace(@WhereCondition,'#DEBTORTEE#',@sWhere) 
			set @MAPSQL=' and CA.AccountTypeID=7'
		end
		else if(@WhereCondition like '%#CREDITORTEE#%')
		begin
		set @STRJOIN=@STRJOIN+' join '+@TableName+' Gp WITH(NOLOCK) on a.lft between Gp.lft and Gp.rgt '
			select @Accountlist= isnull(Value,'') from adm_globalpreferences with(nolock) where Name='CreditorsControlGroup'
			
			if(@Accountlist!='')
				set @sWhere= ' (Gp.AccountID in( '+convert(nvarchar(500),@Accountlist)+')) '
			
			set @WhereCondition=replace(@WhereCondition,'#CREDITORTEE#',@sWhere) 
			set @MAPSQL=' and CA.AccountTypeID=6'
		end
		else if(@WhereCondition like '%#DEBITORCREDITORTEE#%')
		begin
			--DebtorsControlGroup
			set @STRJOIN=@STRJOIN+' join '+@TableName+' Gp WITH(NOLOCK) on a.lft between Gp.lft and Gp.rgt '
			select @Accountlist= isnull(Value,'') from adm_globalpreferences with(nolock) where Name='DebtorsControlGroup'
			select @tempgroup= isnull(Value,'') from adm_globalpreferences with(nolock) where Name='CreditorsControlGroup'
			
			if(@tempgroup!='' and @Accountlist!='')
			begin
				set @sWhere= '(Gp.AccountID in( '+convert(nvarchar(500),@Accountlist)+','+@tempgroup+'))'
				
				set @Depth=',CASE WHEN A.AccountID in( '+convert(nvarchar(500),@Accountlist)+','+@tempgroup+') THEN 1 ELSE A.Depth END Depth '
			end
			else if(@Accountlist!='')
				set @sWhere= '(Gp.AccountID in( '+convert(nvarchar(500),@Accountlist)+'))'
			else if(@tempgroup!='')
				set @sWhere= '(Gp.AccountID in( '+convert(nvarchar(500),@tempgroup)+'))'	
		 	
			set @WhereCondition=replace(@WhereCondition,'#DEBITORCREDITORTEE#',@sWhere)
			set @tempgroup=''
			set @MAPSQL=' and CA.AccountTypeID in (7,6) '
		end
		else if(@WhereCondition like '%#COATEE#%')
		begin
			set @WhereCondition=replace(@WhereCondition,'#COATEE#','(a.AccountTypeID not in (7,6))')
			set @MAPSQL=' and CA.AccountTypeID not in (7,6)'
		end
	end
	
	if @SearchSeqNo>0
	begin
		set @SysColumnName=N''
		set @SQL='select @lft=lft-1 from '+@TableName+' A WITH(NOLOCK) where '+@Pcol+'='+convert(nvarchar, @SearchSeqNo)
		EXEC sp_executesql @SQL,N'@lft INT OUTPUT',@lft OUTPUT
		set @SQL=''	  
	end
  
    IF @IsUserWiseExists=1 
    BEGIN
		DECLARE @TEMPCOL NVARCHAR(100)
		SET @TEMPCOL=REPLACE(@Pcol,'A.','')
		SET @AttachUserWiseQuery = '  LEFT JOIN (select test.LeadID,Grp.lft,Grp.rgt from
		(select ASS.CCNODEID LeadID from CRM_Assignment ASS with(nolock) where ISFROMACTIVITY=0 and ASS.CCID='+convert(varchar,@CostCenterID)+' AND IsTeam=0 and UserID in (select UserID from @TABLE)
		union
		select ASSS.CCNODEID from CRM_Assignment ASSS with(nolock) where ISFROMACTIVITY=0 and ASSS.CCID='+convert(varchar,@CostCenterID)+' AND ASSS.ISGROUP=1 AND ASSS.teamnodeid IN (SELECT GID FROM COM_GROUPS R with(nolock) inner join @TABLE T on R.UserID=T.USERID )
		union
		select ASROLE.CCNODEID from CRM_Assignment ASROLE with(nolock) where ISFROMACTIVITY=0 and ASROLE.CCID='+convert(varchar,@CostCenterID)+' AND ASROLE.IsRole=1 AND ASROLE.teamnodeid IN (SELECT ROLEID FROM ADM_UserRoleMap R with(nolock) inner join @TABLE T on R.UserID=T.USERID) 
		union
		select ASTEAM.CCNODEID from CRM_Assignment ASTEAM with(nolock) where ISFROMACTIVITY=0 and ASTEAM.CCID='+convert(varchar,@CostCenterID)+' AND ASTEAM.IsTeam=1 AND ASTEAM.teamnodeid IN (SELECT teamid FROM crm_teams R with(nolock) inner join @TABLE T on R.UserID=T.USERID WHERE isowner=0 )  
		) as test 
		join '+@TableName+' Grp WITH(NOLOCK) on (test.LeadID=Grp.'+@TEMPCOL+' and Grp.'+@TEMPCOL+'<>1)  ) as  TBL on (a.lft between TBL.lft and TBL.rgt) '
    END  
    ELSE 
		SET @AttachUserWiseQuery=''        
	---------------------------------------------------------------------------------------------------------------------------------------	       
	if(@CostCenterID=2)                
		set @Primarycol='A.AccountID as NodeID,A.AccountTypeID as TypeID '                
	else if(@CostCenterID=12)                
		set @Primarycol='A.CurrencyID as NodeID,0 as TypeID '               
	else if(@CostCenterID=101)                
		set @Primarycol='A.BudgetDefID as NodeID,0 as TypeID '
	
	else if(@CostCenterID=3)                
		set @Primarycol='A.ProductID as NodeID ,A.ProductTypeID as TypeID ' 
	else if(@CostCenterID=11)                
		set @Primarycol='A.UOMID as NodeID,0 as TypeID ' 
	else if(@CostCenterID=16)                
		set @Primarycol='A.BatchID as NodeID,0 as TypeID '            
	   
	else if(@CostCenterID=72)                
		set @Primarycol='A.AssetID as NodeID,0 as TypeID '
	else if(@CostCenterID=74)                
		set @Primarycol=', A.AssetClassID as NodeID, 0 as TypeID  '              
    else if(@CostCenterID=75)                
		set @Primarycol=', A.DeprBookID as NodeID, 0 as TypeID   '               
    else if(@CostCenterID=77)                
		set @Primarycol=', A.PostingGroupID as NodeID ,0 as TypeID  '
		
    else if(@CostCenterID=76)                
		set @Primarycol='A.BOMID as NodeID,A.BOMTypeID as TypeID '               
    else if(@CostCenterID=78)                
		set @Primarycol='A.MFGOrderID as NodeID,a.OrderTypeID  as TypeID '              
    else if(@CostCenterID=80)                 
		set @Primarycol='A.ResourceID as NodeID,0 as TypeID ' 
		       
	else if(@CostCenterID=84)                
		set @Primarycol='A.SvcContractID as NodeID,0 as TypeID ' 
			            
    else if(@CostCenterID=65)              
		set @Primarycol=' A.ContactID as NodeID, 0 as TypeID   '  
    else if(@CostCenterID=73)                
		set @Primarycol=' A.CaseID as NodeID,0 as TypeID   ' 
	else if(@CostCenterID=83)                
		set @Primarycol=' A.CUSTOMERID as NodeID,0 as TypeID '               
	else if(@CostCenterID=86)                
		set @Primarycol=' A.LeadID as NodeID,0 as TypeID   ' 
    else if(@CostCenterID=88)                
		set @Primarycol=' A.CampaignID as NodeID,0 as TypeID '                 
    else if(@CostCenterID=89)                
		set @Primarycol='A.OpportunityID as NodeID,0 as TypeID ' 
		
    else if(@CostCenterID=92)                
		set @Primarycol=' A.NodeID as NodeID,0 as TypeID '             
	else if(@CostCenterID=93)                
		set @Primarycol=' A.UnitID as NodeID,0 as TypeID '
    else if(@CostCenterID=94)                
		set @Primarycol=' A.TenantID as NodeID,0 as TypeID '          
    else if(@CostCenterID=95 OR @CostCenterID =104)                
		set @Primarycol=' A.ContractID as NodeID,A.StatusID as TypeID  '               
    else if(@CostCenterID=103 OR @CostCenterID =129)                
		set @Primarycol=' A.QuotationID as NodeID,0 as TypeID '
			 
	else if(@CostCenterID=6)                
		set @Primarycol='A.RoleID as NodeID,0 as TypeID '               
	else if(@CostCenterID=7)                
		set @Primarycol='A.UserID as NodeID,0 as TypeID,ROLE.RoleType '              
	else if(@CostCenterID=113)                
		set @Primarycol='A.StatusID as NodeID  '               
	else if(@CostCenterID=200)                
		set @Primarycol='A.StaticReportType,A.ReportID as NodeID,A.ReportTypeID as TypeID '
	else if(@CostCenterID=199)                
		set @Primarycol='A.WType,A.ID as NodeID,A.WType as TypeID '
	else if(@CostCenterID=90)                
		set @Primarycol=' A.SFReportID as NodeID,ReportTypeID as TypeID   ' 
    else if(@CostCenterID in (41,47,48))                
		set @Primarycol='A.TemplateID as NodeID,0 as TypeID '              
	else if(@CostCenterID between 40000 and 50000 )                
		set @Primarycol='A.DocID  as NodeID,0 as TypeID '         
    else if(@CostCenterID=50052)
		set @Primarycol='A.NodeID, 0 as TypeID,CreditLimit as GroupFlag '
	else 
		set @Primarycol='A.NodeID, 0 as TypeID ' 	
	---------------------------------------------------------------------------------------------------------------------------------------       
	if(@CostCenterID=2)--ACCOUNTS              
		SET @STRJOIN=@STRJOIN+'LEFT JOIN ACC_AccountsExtended X with(nolock) ON A.AccountID=X.AccountID  '  
	ELSE if(@CostCenterID=72)--Asset                   
		SET @STRJOIN=@STRJOIN+'LEFT JOIN ACC_AssetsExtended X with(nolock) ON A.AssetID=X.AssetID   '  
		
	ELSE if(@CostCenterID=3)--PRODUCTS                
		SET @STRJOIN=@STRJOIN+'LEFT JOIN INV_ProductExtended X with(nolock) ON A.ProductID=X.ProductID  '               
	
	ELSE if(@CostCenterID=76)--BOM                   
		SET @STRJOIN=@STRJOIN+'LEFT JOIN PRD_BillOfMaterialExtended X with(nolock) ON A.BOMID=X.BOMID   '               
	ELSE if(@CostCenterID=78)--                   
		SET @STRJOIN=@STRJOIN+'LEFT JOIN PRD_MFGOrderExtd X with(nolock) ON A.MFGOrderID=X.MFGOrderID   ' 
		
	ELSE if(@CostCenterID=65)--contact                   
		SET @STRJOIN=@STRJOIN+'LEFT JOIN COM_ContactsExtended X with(nolock) ON A.ContactID=X.ContactID   ' 
	ELSE if(@CostCenterID=73)--CRM-Cases                   
		SET @STRJOIN=@STRJOIN+'left JOIN CRM_CasesExtended X with(nolock) ON A.CaseID=X.CaseID   '
	ELSE if(@CostCenterID=83)--cusetomer                   
		SET @STRJOIN=@STRJOIN+'LEFT JOIN CRM_CustomerExtended X with(nolock) ON A.CustomerId=X.CustomerId   '        
	ELSE if(@CostCenterID=86)--CRM-Lead                   
		SET @STRJOIN=@STRJOIN+' LEFT JOIN CRM_LeadsExtended X with(nolock) ON x.leadid=A.LEADID  
		LEFT JOIN CRM_CONTACTS CON with(nolock) ON CON.FEATUREPK=A.LEADID AND CON.FEATUREID=86 ' 
	ELSE if(@CostCenterID=88)--Campaign                   
		SET @STRJOIN=@STRJOIN+'LEFT JOIN CRM_CampaignsExtended X with(nolock) ON A.CampaignID=X.CampaignID   '    
	ELSE if(@CostCenterID=89)--CRM-Opportunities                    
		SET @STRJOIN=@STRJOIN+' LEFT JOIN CRM_OpportunitiesExtended X with(nolock) ON A.OpportunityID=X.OpportunityID
		LEFT JOIN CRM_CONTACTS CON with(nolock) ON CON.FEATUREPK=A.OpportunityID AND CON.FEATUREID=89 ' 
	
	ELSE if(@CostCenterID=92)--Property                   
		SET @STRJOIN=@STRJOIN+'LEFT JOIN REN_PropertyExtended X with(nolock) ON A.NodeID=X.NodeID '              
	ELSE if(@CostCenterID=93)--Unit                   
		SET @STRJOIN=@STRJOIN+'LEFT JOIN REN_UnitsExtended X with(nolock) ON A.UnitID=X.UnitID '              
	ELSE if(@CostCenterID=94)--Tenant                   
		SET @STRJOIN=@STRJOIN+'LEFT JOIN REN_TenantExtended X with(nolock) ON A.TenantID=X.TenantID   '     
	ELSE if(@CostCenterID=95 OR @CostCenterID =104)--Contract                   
		SET @STRJOIN=@STRJOIN+'LEFT JOIN REN_ContractExtended X with(nolock) ON A.ContractID=X.NodeID   '     
	ELSE if(@CostCenterID=103 OR @CostCenterID =129)--Quotation                   
		SET @STRJOIN=@STRJOIN+'LEFT JOIN REN_Quotationextended X with(nolock) ON A.QuotationID=X.QuotationID '     
	ELSE if(@CostCenterID between 40000 and 50000)                
	begin              
		if exists(select DocumentType from ADM_DocumentTypes with(nolock) where CostCenterID=@CostCenterID and  IsInventory=1) 
		BEGIN             
			SET @STRJOIN=@STRJOIN+' JOIN COM_DocCCData DCM WITH(NOLOCK) ON DCM.InvDocDetailsID=A.InvDocDetailsID '    
			SET @STRJOIN=@STRJOIN+' JOIN COM_DocTextData DTM WITH(NOLOCK) ON DTM.InvDocDetailsID=A.InvDocDetailsID ' 
		END            
		else     
		BEGIN         
			SET @STRJOIN=@STRJOIN+' JOIN COM_DocCCData DCM WITH(NOLOCK) ON DCM.ACCDocDetailsID=A.ACCDocDetailsID '   
			SET @STRJOIN=@STRJOIN+' JOIN COM_DocTextData DTM WITH(NOLOCK) ON DTM.ACCDocDetailsID=A.ACCDocDetailsID '     
		END          
	end 
	---------------------------------------------------------------------------------------------------------------------------------------
	--Create temporary table to read xml data into table                
	DECLARE @tblList TABLE(ID int identity(1,1) PRIMARY KEY,CostCenterColID INT,Descr nvarchar(500),IsCode bit)                  

	--Read CostCenterColUMNS FROM  GridViewColumns into temporary table                
	IF(@GridViewID = 280 AND @CostCenterID=40011)
	BEGIN           
		INSERT INTO @tblList                
		SELECT CostCenterColID,[Description],IsCode 
		FROM ADM_GridViewColumns with(nolock)
		WHERE GridViewID=@GridViewID AND ColumnType=2
		ORDER BY ColumnOrder   
	END
	ELSE
	BEGIN		
		INSERT INTO @tblList                
		SELECT CostCenterColID,[Description],IsCode 
		FROM ADM_GridViewColumns with(nolock)
		WHERE GridViewID=@GridViewID 
		ORDER BY ColumnOrder 
	END 

	--Set loop initialization varaibles                
	SELECT @I=1, @Cnt=count(*) FROM @tblList                  

	SET @IsExtraCostCenterDisplayed=0                
	SET @IsContDisplayed=0
	SET @IsAddressDisplayed=0
	SET @CC=0                 
	WHILE(@I<=@Cnt)                  
	BEGIN             
		SELECT @CostCenterColID=CostCenterColID,@IsCode=IsCode FROM @tblList WHERE ID=@I       
		           
		--select @CostCenterColID
		SET @I=@I+1                
		SET @ColumnCostCenterID=0                
		SET @SysColumnName=''                  
		SET @IsColumnUserDefined=0                
		IF(@CostCenterColID>0)
			SELECT @SysColumnName=SysColumnName,@UserColumnName =usercolumnname,@ColumnDataType=ColumnDataType,@IsColumnUserDefined=IsColumnUserDefined,@ColumnCostCenterID=ColumnCostCenterID                
			FROM ADM_CostCenterDef WITH(nolock) 
			WHERE CostCenterColID=@CostCenterColID 
			
		declare @isProduct INT
		if(@CostCenterID=16)
			select @isProduct=CostCenterColID from ADM_CostCenterDef with(nolock) where CostCenterColID=@CostCenterColID and CostCenterID=3
		else
			set @isProduct=0
		   
		SET @strColumns=@strColumns+','                
		if(@ColumnCostCenterID=113)
			set @ColumnCostCenterID=0
		
		if(@CostCenterColID< 0 and -(@CostCenterColID)>50000)
		begin 
			declare @assignedtablename nvarchar(200), @name nvarchar(100)
			select @assignedtablename=tablename, @name =Name from ADM_Features with(nolock) where FeatureID=-@CostCenterColID
			SET @strColumns=@strColumns+' dbo.[fnRPT_AssignedData] ('+convert(nvarchar,(@CostCenterID)) +', '+@Pcol+', '+convert(nvarchar,(-(@CostCenterColID)))+','''+@assignedtablename+''') as [' +@name+']'
		end

		if(@CostCenterColID=137 and @CostCenterID=101)
		begin 
			SET @strColumns=@strColumns+' STUFF((select '', ''+D.DocumentAbbr from ADM_DocumentBudgets DB with(nolock) 
			inner join ADM_DocumentTypes D with(nolock) on DB.CostCenterID=D.CostCenterID
			where BudgetID=A.BudgetDefID FOR XML PATH('''')) ,1,2,'''') AssignedDocuments'
		end	
	            
		if(@CostCenterID=86 and (@SysColumnName='SalutationID' or @SysColumnName='RoleLookupID' or @SysColumnName='SourceLookUpID' or 
		@SysColumnName='RatinglookupID' or @SysColumnName='IndustryLookUpID' ))
			set @ColumnCostCenterID=0
		
		IF(@SysColumnName='AccountGroup')
		BEGIN
			SET @strColumns=@strColumns+'(select AccountName from ACC_Accounts WITH(NOLOCK) where AccountID=a.parentid) as '  +@SysColumnName    
		END
		ELSE IF(@ColumnCostCenterID IS NOT NULL AND @ColumnCostCenterID>0)--IF COSTCENTER COLUMN                
		BEGIN 
			SELECT @CostCenterTableName= TableName FROM ADM_Features with(nolock) WHERE FeatureID=@ColumnCostCenterID 
			
			--if extra cc column to be displayed -------------------------------------------------------------------------------------------------------------------------------
			IF(@IsExtraCostCenterDisplayed=0 AND @IsColumnUserDefined=1) 
			BEGIN 
				SET @IsExtraCostCenterDisplayed=1                
				if(@CostCenterID=3)--PRODUCTS                
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData PCM WITH(NOLOCK) ON PCM.NodeID=A.ProductID AND PCM.CostCenterID='+convert(nvarchar(10),@CostCenterID)              
				ELSE if(@CostCenterID=2)--ACCOUNTS                
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData ACM WITH(NOLOCK) ON ACM.NodeID=A.AccountID AND ACM.CostCenterID='+convert(nvarchar(10),@CostCenterID)                
				ELSE if(@CostCenterID=16)--Batch            
				begin       
					if (@isProduct>0)
						SET @STRJOIN=@STRJOIN+' left JOIN INV_Product BP WITH(NOLOCK) ON BP.PRODUCTID=A.PRODUCTID 
						LEFT JOIN COM_CCCCDATA BPCC WITH(NOLOCK) ON BP.PRODUCTID=BPCC.NODEID AND BPCC.COSTCENTERID=3'
					ELSE                
						SET @STRJOIN=@STRJOIN+'  left  JOIN COM_CCCCDATA BCM WITH(NOLOCK) ON BCM.NODEID=A.BatchID AND BCM.COSTCENTERID='+convert(nvarchar(10),@CostCenterID)               
				end               
				ELSE if(@CostCenterID=101)--BUDGET                
					SET @STRJOIN=@STRJOIN+' left JOIN COM_BudgetDef BUD WITH(NOLOCK) ON BUD.BudgetDefID=A.BudgetDefID '                

				ELSE if(@CostCenterID=72)--Asset                
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData CCM WITH(NOLOCK) ON CCM.NodeID=A.AssetID and CCM.COSTCENTERID='+convert(nvarchar(10),@CostCenterID)   
				                 
				ELSE if(@CostCenterID=76)--BOM                
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData CCM WITH(NOLOCK) ON CCM.NodeID=A.BOMID AND CCM.CostCenterID='+convert(nvarchar(10),@CostCenterID)  
					              
				ELSE if(@CostCenterID=65)--Customer              
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData CONTACT WITH(NOLOCK) ON CONTACT.NodeID=A.CONTACTID  and CONTACT.CostCenterID='+convert(nvarchar(10),@CostCenterID)
				ELSE if(@CostCenterID=73)--CRM-Cases                
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData Cases WITH(NOLOCK) ON Cases.NodeID=A.CaseID AND Cases.CostCenterID='+convert(NVARCHAR(10),@CostCenterID)
				ELSE if(@CostCenterID=81)--Contract Template                
					SET @STRJOIN=@STRJOIN+' left JOIN CRM_ContractTemplate CTemp WITH(NOLOCK) ON CTemp.ContractTemplID=A.ContractTemplID '
				ELSE if(@CostCenterID=83)--Customer              
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData CUSTOMER WITH(NOLOCK) ON CUSTOMER.NodeID=A.CUSTOMERID  and CUSTOMER.CostCenterID='+convert(nvarchar(10),@CostCenterID)                
				ELSE if(@CostCenterID=86)--CRM-Lead                
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData Lead WITH(NOLOCK) ON Lead.NodeID=A.LeadID  and Lead.CostCenterID='+convert(nvarchar(10),@CostCenterID)
				ELSE if(@CostCenterID=88)       
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData CCM WITH(NOLOCK) ON CCM.NodeID=A.CampaignID AND CCM.CostCenterID='+convert(nvarchar(10),@CostCenterID)                
				ELSE if(@CostCenterID=89)--CRM-Opportunity                
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData Opp WITH(NOLOCK) ON Opp.NodeID=A.OpportunityID and Opp.CostCenterID='+convert(nvarchar(10),@CostCenterID)
				
				ELSE if(@CostCenterID=93)       
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData CCM WITH(NOLOCK) ON CCM.NodeID=A.UNITID AND CCM.CostCenterID='+convert(nvarchar(10),@CostCenterID) 
				ELSE if(@CostCenterID=94)       
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData CCM WITH(NOLOCK) ON CCM.NodeID=A.TenantID AND CCM.CostCenterID='+convert(nvarchar(10),@CostCenterID)                          
				ELSE if(@CostCenterID=95 OR @CostCenterID =104)       
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData CCM WITH(NOLOCK) ON CCM.NodeID=A.ContractID AND CCM.CostCenterID='+convert(nvarchar(10),@CostCenterID)                
				ELSE if(@CostCenterID=103 OR @CostCenterID =129)       
					SET @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData CCM WITH(NOLOCK) ON CCM.NodeID=A.QuotationID AND CCM.CostCenterID='+convert(nvarchar(10),@CostCenterID)
					
				ELSE if(@CostCenterID not between 40000 and 50000 OR @CostCenterID  = 92  )       
				begin
					if (@CostCenterID >50000 AND @UserID!=1 AND (@isproj=1 or (@IsGroupUserWiseExists=0 AND @IsUserWiseExists=1)))
						set @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData CCM WITH(NOLOCK) ON CCM.NodeID=CG.NodeID AND CCM.CostCenterID='+convert(nvarchar(10),@CostCenterID)                
					else
						set @STRJOIN=@STRJOIN+' left JOIN COM_CCCCData CCM WITH(NOLOCK) ON CCM.NodeID=A.NodeID AND CCM.CostCenterID='+convert(nvarchar(10),@CostCenterID)                
				end 
			END    
			--Set Primary Column------------------------------------------------------------------------------------------------------------------------------------------------     
			if(@ColumnCostCenterID=3) 
			BEGIN                      
				set @ColCostCenterPrimary='ProductID'     
				if(@CostCenterID=16)
				BEGIN
					if(@UserColumnName='ProductID' or @UserColumnName='Product Name')
						SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.ProductName as CCNAME'+CONVERT(NVARCHAR(10),@CC)       
					else if(@UserColumnName='ProductCode')
						SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.ProductCode as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
					else if(@UserColumnName='BarcodeID')
						SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BarcodeID as CCNAME'+CONVERT(NVARCHAR(10),@CC)           
					ELSE IF(@UserColumnName='QOH'  )                        
					BEGIN                        
						SET @strColumns=@strColumns +'(SELECT isnull(sum(Quantity*VoucherType),0) FROM INV_DocDetails i  WITH(NOLOCK)   
						WHERE BatchID= A.BatchID AND  (VoucherType=1 OR VoucherType=-1)) as QtyonHand'                   
					END 
				END	      
				else
				begin
					if @IsCode=1
						SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.ProductCode as CCNAME'+CONVERT(NVARCHAR(10),@CC)  
					else
						SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.ProductName as CCNAME'+CONVERT(NVARCHAR(10),@CC)   
				end             
			END                
			ELSE if(@ColumnCostCenterID=2)                
			BEGIN           
				set @ColCostCenterPrimary='AccountID'       
				if @IsCode=1      
					SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.AccountCode as CCNAME'+CONVERT(NVARCHAR(10),@CC)     
				else
					SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.AccountName as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END                
			ELSE if(@ColumnCostCenterID=11)                
			BEGIN                            
				set @ColCostCenterPrimary='UOMID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.UnitName as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END                
			ELSE if(@ColumnCostCenterID=12)                
			BEGIN                             
				set @ColCostCenterPrimary='CurrencyID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.NAME as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END               
			ELSE if(@ColumnCostCenterID=17)                
			BEGIN                             
				set @ColCostCenterPrimary='BarcodeID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BarcodeName as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END                
			ELSE if(@ColumnCostCenterID=16)                
			BEGIN                            
				set @ColCostCenterPrimary='BatchID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BatchNumber as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END              
			ELSE if(@ColumnCostCenterID=101)                
			BEGIN                
				set @ColCostCenterPrimary='BudgetDefID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BudgetName as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END     
			
			ELSE if(@ColumnCostCenterID=92)                
			BEGIN                
				set @ColCostCenterPrimary='NodeID'  
				if @IsCode=1
					set @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR,@CC)+'.CODE as CCNAME'+CONVERT(NVARCHAR,@CC) 
				else              
					SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Name as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END             
			ELSE if(@ColumnCostCenterID=93)                
			BEGIN 
			               
				set @ColCostCenterPrimary='UnitID'                
				if(@CostCenterID=103)
					SET @strColumns=@strColumns+' case when a.multiName is not null and a.multiName<>'''' then a.multiName else  CC'+CONVERT(NVARCHAR(10),@CC)+'.Name end as CCNAME'+CONVERT(NVARCHAR(10),@CC)
				ELSE
				BEGIN
					if @IsCode=1
						set @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR,@CC)+'.CODE as CCNAME'+CONVERT(NVARCHAR,@CC) 
					else 
						SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Name as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
				END
			END
			ELSE if(@ColumnCostCenterID=94)                
			BEGIN                
				set @ColCostCenterPrimary='TenantID' 
				if @IsCode=1
					set @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR,@CC)+'.TenantCODE as CCNAME'+CONVERT(NVARCHAR,@CC) 
				else               
					SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.FirstName as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END                  
			ELSE if(@ColumnCostCenterID=95 OR @ColumnCostCenterID=104)                
			BEGIN                
				set @ColCostCenterPrimary='ContractID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.ContractPrefix as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END               
			ELSE if(@ColumnCostCenterID=103 OR @ColumnCostCenterID=129)                
			BEGIN                
				set @ColCostCenterPrimary='QuotationID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Prefix as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END               
			
			ELSE if(@ColumnCostCenterID=73)                
			BEGIN                
				set @ColCostCenterPrimary='CaseID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.CaseNumber as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END           
			ELSE if(@ColumnCostCenterID=81)                
			BEGIN                
				set @ColCostCenterPrimary='ContractTemplID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.CTemplName as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END 
			ELSE if(@ColumnCostCenterID=83)                
			BEGIN                
				set @ColCostCenterPrimary='CustomerID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.CustomerName as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END               
			ELSE if(@ColumnCostCenterID=86)                
			BEGIN                
				set @ColCostCenterPrimary='LeadID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Company as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END              
			ELSE if(@ColumnCostCenterID=89)                
			BEGIN                
				set @ColCostCenterPrimary='OpportunityID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.Subject as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END               
			                
			ELSE if(@ColumnCostCenterID=72)                
			BEGIN                
				set @ColCostCenterPrimary='AssetID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.AssetName as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END                
			ELSE if(@ColumnCostCenterID=76)                
			BEGIN                
				set @ColCostCenterPrimary='BOMID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.BOMName as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END   
			ELSE if(@ColumnCostCenterID=80)                
			BEGIN                
				set @ColCostCenterPrimary='ResourceID'                
				SET @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR(10),@CC)+'.ResourceName as CCNAME'+CONVERT(NVARCHAR(10),@CC)                
			END                 
			              
			ELSE if(@ColumnCostCenterID=50002 and @CostCenterID=93 and @SysColumnName='LocationID')
			BEGIN 
				SET @strColumns=@strColumns+'CCL.NAME as  '+@SysColumnName
				SET @STRJOIN=@STRJOIN+' left JOIN Com_location CCL WITH(NOLOCK) ON A.'+@SysColumnName+'= CCL.NodeID'  
			END     
			else    
			BEGIN                
				set @ColCostCenterPrimary='NodeID'
				if @IsCode=1
					set @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR,@CC)+'.CODE as CCNAME'+CONVERT(NVARCHAR,@CC) 
				else
					set @strColumns=@strColumns+'CC'+CONVERT(NVARCHAR,@CC)+'.NAME as CCNAME'+CONVERT(NVARCHAR,@CC) 
			END                
            --------------------------------------------------------------------------------------------------------------------------------------------------------------------    
			IF(@IsColumnUserDefined=0) 
			BEGIN  
				IF(@CostCenterID=76)--BOM                
				BEGIN     
					if(@SysColumnName='LocationID' or @SysColumnName='DivisionID' or @SysColumnName='ProductID')
						SET @STRJOIN=@STRJOIN+' LEFT JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
						+' WITH(NOLOCK) ON A.'+@SysColumnName+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' '
					else if (@SysColumnName='UOMID')
						SET @STRJOIN=@STRJOIN+' LEFT JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
						+' WITH(NOLOCK) ON a.UOMID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+''
					else
						SET @STRJOIN=@STRJOIN+' LEFT JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
						+' WITH(NOLOCK) ON a.BOMID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND a.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)                
				END 
				else if(@SysColumnName='ProductGroup' OR @SysColumnName='IsGroup')                 
					SET @STRJOIN=@STRJOIN+' left JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
					+' WITH(NOLOCK) ON A.ParentID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary            
				else 
					SET @STRJOIN=@STRJOIN+' left JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
					+' WITH(NOLOCK) ON A.'+@SysColumnName+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary                
			END                
			ELSE IF(@CostCenterID=2)--ACCOUNTS                
			BEGIN                
				SET @STRJOIN=@STRJOIN+' left JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
				+' WITH(NOLOCK) ON ACM.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary              
			END                
			ELSE IF(@CostCenterID=3)--PRODUCTS                
			BEGIN                
				SET @STRJOIN=@STRJOIN+' left JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
				+' WITH(NOLOCK) ON PCM.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary              
			END                
			ELSE IF(@CostCenterID=16)--Batch                
			BEGIN                
				if(@isProduct>0 )
					SET @STRJOIN=@STRJOIN+' left JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
					+' WITH(NOLOCK) ON BPCC.CCNID'+CONVERT(NVARCHAR(10), (@ColumnCostCenterID-50000)) +'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+'  '              
				else
					SET @STRJOIN=@STRJOIN+' left JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)  
					+' WITH(NOLOCK) ON BCM.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary              
			END                   
			ELSE IF(@CostCenterID=101)--BUDGET                
			BEGIN                
				SET @STRJOIN=@STRJOIN+' LEFT JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
				+' WITH(NOLOCK) ON BUD.BudgetDefID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND BUD.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)                
			END           
			--ELSE IF(@CostCenterID=95)--CONTRACT                
			--   BEGIN                
			--    SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
			--     +' WITH(NOLOCK) ON CNT.ContractID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND CNT.ContractID='+convert(NVARCHAR(10),@ColumnCostCenterID)                

			--   END              
			ELSE IF(@CostCenterID in (103,129))--Quotation                
			BEGIN                
				SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
				+' WITH(NOLOCK) ON CNT.ContractID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND CNT.ContractID='+convert(NVARCHAR(10),@ColumnCostCenterID)                
			END              
			ELSE IF(@CostCenterID=104)--Quotation                
			BEGIN                
				SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
				+' WITH(NOLOCK) ON CNT.ContractID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND CNT.ContractID='+convert(NVARCHAR(10),@ColumnCostCenterID)                
			END        

			ELSE IF(@CostCenterID=89)--CRM-Opportunity               
			BEGIN                
				SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
				+' WITH(NOLOCK) ON Opp.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+'  '                
			END                
			ELSE IF(@CostCenterID=73)--CRM-Case               
			BEGIN                
				SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
				+' WITH(NOLOCK) ON Cases.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' '                
			END    
			ELSE IF(@CostCenterID=86)--CRM-Leads               
			BEGIN                
				if(@ColumnCostCenterID=44)
					SET @STRJOIN=@STRJOIN+' LEFT  JOIN Com_lookup CC'+CONVERT(NVARCHAR(10),@CC)                
					+' WITH(NOLOCK) ON x.'+CONVERT(NVARCHAR,@SysColumnName)+'= CONVERT(NVARCHAR,CC'+CONVERT(NVARCHAR(10),@CC)+'.Nodeid) '                
				else
					SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
					+' WITH(NOLOCK) ON Lead.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+'  '                
			END               
			ELSE IF(@CostCenterID=71)--ASSET                
			BEGIN                
				SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
				+' WITH(NOLOCK) ON ASS.AssetID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND ASS.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)                
			END   
			ELSE IF(@CostCenterID=81)--Contract Template                
			BEGIN                
				SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
				+' WITH(NOLOCK) ON CTemp.ContractTemplID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' AND CTemp.CostCenterID='+convert(NVARCHAR(10),@ColumnCostCenterID)                
			END              
			ELSE IF(@CostCenterID=83)--Customer                
			BEGIN                
				SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
				+' WITH(NOLOCK) ON CUSTOMER.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+'  '      
			END              
			ELSE IF(@CostCenterID=65)--Customer                
			BEGIN                
				SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
				+' WITH(NOLOCK) ON CONTACT.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+'  '      
			END                   
			ELSE IF(@CostCenterID between 40000 and 50000)--Document                
			BEGIN                
				if exists(select DocumentType from ADM_DocumentTypes with(nolock) where CostCenterID=@CostCenterID and  IsInventory=1)
				begin
					if(@ColumnCostCenterID>50000)              
						SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
						+' WITH(NOLOCK) ON DCM.DCCCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+'  '  
					ELSE 
						SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
						+' WITH(NOLOCK) ON DTM.'+@SysColumnName+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+'  '  
				end     
				else              
					SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
					+' WITH(NOLOCK) ON DCM.ACCDocDetailsID= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary+' '              
			END               
			ELSE if(@ColumnCostCenterID=2 and @SysColumnName like 'ccAlpha%' and @CostCenterID between 50000 and 50090)
			BEGIN
				SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
				+' WITH(NOLOCK) ON A.'+@SysColumnName+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary              
			END
			ELSE --OTHER COSTCENTERS                
			BEGIN       
				if(@ColumnCostCenterID=3)
					SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
					+' WITH(NOLOCK) ON CCM.Productid>0 and CCM.Productid= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary              
				else
					SET @STRJOIN=@STRJOIN+' LEFT  JOIN '+@CostCenterTableName +' CC'+CONVERT(NVARCHAR(10),@CC)                
					+' WITH(NOLOCK) ON CCM.CCNID'+CONVERT(NVARCHAR,@ColumnCostCenterID-50000)+'= CC'+CONVERT(NVARCHAR(10),@CC)+'.'+@ColCostCenterPrimary              
			END                
			--------------------------------------------------------------------------------------------------------------------------------------------------------------------
			SET @CC=@CC+1                
		END    
		ELSE IF(@IsColumnUserDefined IS NOT NULL AND @IsColumnUserDefined = 1 AND @SysColumnName not like '%alpha%' and @CostCenterID not between 40000 and 50000)                 
		BEGIN 		
			  IF (@SysColumnName ='CloseBy' and @CostCenterID=73)                  
			  BEGIN                  
			  SET @strColumns=@strColumns+'CRMCB.CloseBy as '     +@SysColumnName              
			  SET @STRJOIN=@STRJOIN+'  JOIN CRM_Cases CRMCB WITH(NOLOCK) ON (A.CaseID=CRMCB.CaseID) '           
			  END 
			  ELSE IF (@SysColumnName ='CloseDate' and @CostCenterID=73)                  
			  BEGIN                  
			  SET @strColumns=@strColumns+'convert(nvarchar(12), Convert(datetime,CRMCD.CloseDate),106) as '     +@SysColumnName              
			  SET @STRJOIN=@STRJOIN+'  JOIN CRM_Cases CRMCD WITH(NOLOCK) ON (A.CaseID=CRMCD.CaseID) '           
			  END
			  ELSE
			  BEGIN
				if(@CostCenterID=2 and @SysColumnName='Level')
					SET @strColumns=@strColumns+'A.Depth as '+@SysColumnName      
				else
					SET @strColumns=@strColumns+'Cont.'+@SysColumnName      
				
			  END
			if(@IsContDisplayed=0)              
			begin              
				SET @IsContDisplayed=1              
				SET @STRJOIN=@STRJOIN+' left JOIN COM_Contacts Cont WITH(NOLOCK) ON '+@Pcol+'=Cont.FeaturePK and Cont.FeatureID='+convert(NVARCHAR(10),@CostCenterID)+' and Cont.AddressTypeID=1'              
			end              
		END                 
		ELSE IF(@IsColumnUserDefined IS NOT NULL AND @IsColumnUserDefined = 1 AND @SysColumnName like '%alpha%' AND (@CostCenterID=2 OR @CostCenterID=3 OR @CostCenterID=101 OR @CostCenterID=71 OR @CostCenterID=76 OR
		@CostCenterID=72 OR @CostCenterID=81 OR @CostCenterID=83 OR @CostCenterID=88  or @CostCenterID=89 or @CostCenterID=86 or @CostCenterID=129 
		or @CostCenterID=73 OR @CostCenterID=94 OR @CostCenterID=92 OR @CostCenterID=93 OR @CostCenterID=95 OR @CostCenterID=103 OR @CostCenterID=104))                 
		BEGIN 
			SET @strColumns=@strColumns+'X.'+@SysColumnName                 
		END          
		ELSE IF(@SysColumnName='Balance' and @IsColumnUserDefined=0)                      
		BEGIN 
			SET @strColumns=@strColumns +'round(isnull((select SUM(isnull(amount,0)) from ACC_DocDetails with(nolock) where DocDate < =' +convert(nvarchar,@Dt)+' and debitaccount in (select AccountID from ACC_Accounts with(nolock) where lft>=(select lft from ACC_Accounts with(nolock) where AccountID=A.AccountID) and rgt<= (select rgt from ACC_Accounts with(nolock) where AccountID=A.AccountID))),0)-        isnull((select SUM(isnull(amount,0)) from ACC_DocDetails with(nolock) where DocDate < =' +convert(nvarchar,@Dt)+' and creditaccount in (select AccountID from ACC_Accounts with(nolock) where lft>=  
			(select lft from ACC_Accounts with(nolock) where AccountID=A.AccountID) and rgt<= (select rgt from ACC_Accounts with(nolock) where AccountID=A.AccountID))),0),'+@AmtDec+') as Balance  '                          
		END                
		ELSE IF(@SysColumnName='QOH' and @IsColumnUserDefined=0 and @CostCenterID=3  )                        
		BEGIN     
		if(@CostCenterColID=26428 and exists(SELECT CostCenterColID FROM @tblList  
		WHERE ID=@I-1 and Descr is not null and Descr<>'Description' and Descr<>''))	
		BEGIN 
			declare @Param1 nvarchar(max),@cancelleddocs nvarchar(max),@stat nvarchar(50)
			select @cancelleddocs=Value from adm_globalPreferences WITH(NOLOCK) where  Name='HoldResCancelledDocs'    
			if(@cancelleddocs is not null and @cancelleddocs<>'')
				set @cancelleddocs=' or l.Costcenterid in('+@cancelleddocs+') '	
			else
				set @cancelleddocs=''
				
			 if exists(select Value from adm_globalPreferences WITH(NOLOCK) where  Name='ConsiderUnAppInHold' and value='true')
						set @stat=' in(371,441,369) '
					else	
						set @stat='=369 '
							
			SELECT @Param1=Descr FROM @tblList WHERE ID=@I-1
			if(@Param1 like '%QOH%')
			BEGIN
				set @Param1 = Replace(@Param1,'QOH','round((SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails i  WITH(NOLOCK)              
					join COM_DocCCData d with(nolock) on i.InvDocDetailsID=d.InvDocDetailsID              
					WHERE ProductID= A.ProductID AND IsQtyIgnored=0 AND (VoucherType=1 OR VoucherType=-1) and i.StatusID=369              
					and DocDate<='+CONVERT(nvarchar,CONVERT(float,@Dt))+'),'+@QtyDec+')')				
			END
			IF(@Param1 like '%HOLDQTY%')
			BEGIN 
				set @Param1 = Replace(@Param1,'HOLDQTY','round(( select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from               
					   (SELECT D.HoldQuantity,isnull((select sum(case when l.IsQtyIgnored=0 '+@cancelleddocs+'   then l.Quantity else l.ReserveQuantity end)
					  from INV_DocDetails l  WITH(NOLOCK) where d.InvDocDetailsID=l.LinkedInvDocDetailsID and l.StatusID'+@stat+') ,0) release              
					   FROM INV_DocDetails D WITH(NOLOCK)    INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID
					   WHERE D.ProductID=A.ProductID AND D.IsQtyIgnored=1 and D.StatusID=369   and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 AND convert(datetime,D.DocDate)<='+CONVERT(nvarchar,CONVERT(float,@Dt))+              
					  ' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp),'+@QtyDec+')')
			END   
			IF(@Param1 like '%RESERVEQTY%')
			BEGIN     					
				set @Param1 = Replace(@Param1,'RESERVEQTY','round(( select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from               
							(SELECT D.ReserveQuantity HoldQuantity,isnull((select sum(case when l.IsQtyIgnored=0 '+@cancelleddocs+'   then l.Quantity else l.ReserveQuantity end)
							from INV_DocDetails l  WITH(NOLOCK) where d.InvDocDetailsID=l.LinkedInvDocDetailsID and l.StatusID=369),0) release              
							FROM INV_DocDetails D WITH(NOLOCK)    INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID
							WHERE D.ProductID=A.ProductID AND D.IsQtyIgnored=1  and D.StatusID'+@stat+'     and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 AND convert(datetime,D.DocDate)<='+CONVERT(nvarchar,CONVERT(float,@Dt))+              
						   ' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp),'+@QtyDec+')')
			END
			IF(@Param1 like '%BalQty%')
			BEGIN     
				set @Param1 = Replace(@Param1,'BalQty','round((SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails i  WITH(NOLOCK)              
						join COM_DocCCData d with(nolock) on i.InvDocDetailsID=d.InvDocDetailsID              
						   WHERE ProductID= A.ProductID AND IsQtyIgnored=0 AND (VoucherType=1 OR VoucherType=-1) and i.StatusID=369               
						   and DocDate<='+CONVERT(nvarchar,CONVERT(float,@Dt))+'),'+@QtyDec+')')
			END
			SET @strColumns=@strColumns +@Param1+' as QtyonHand'
		END
		ELSE
		BEGIN 
			 SET @strColumns=@strColumns +'round((SELECT isnull(sum(UOMConvertedQty*VoucherType),0) FROM INV_DocDetails i  WITH(NOLOCK)              
					join COM_DocCCData d with(nolock) on i.InvDocDetailsID=d.InvDocDetailsID              
					WHERE ProductID= A.ProductID AND IsQtyIgnored=0 AND (VoucherType=1 OR VoucherType=-1)              
					and DocDate<='+CONVERT(nvarchar,CONVERT(float,@Dt))+'),'+@QtyDec+') as QtyonHand'                   
		END	   
	 END                
	 ELSE IF(@SysColumnName='HOLDQTY' and @IsColumnUserDefined=0 and @CostCenterID=3  )                        
	 BEGIN                    
		select @cancelleddocs=Value from adm_globalPreferences WITH(NOLOCK) where  Name='HoldResCancelledDocs'    
		if(@cancelleddocs is not null and @cancelleddocs<>'')
			set @cancelleddocs=' or l.Costcenterid in('+@cancelleddocs+') '	
		else
			set @cancelleddocs=''
				 
		SET @strColumns=@strColumns +'round(( select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from               
           (SELECT D.HoldQuantity,isnull((select sum(case when l.IsQtyIgnored=0 '+@cancelleddocs+'   then l.Quantity else l.ReserveQuantity end)
          from INV_DocDetails l  WITH(NOLOCK) where d.InvDocDetailsID=l.LinkedInvDocDetailsID and l.StatusID=369   ),0) release              
           FROM INV_DocDetails D WITH(NOLOCK)    INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID               
                     
           WHERE D.ProductID=A.ProductID AND D.IsQtyIgnored=1 and D.StatusID'
				 
					 if exists(select Value from adm_globalPreferences WITH(NOLOCK) where  Name='ConsiderUnAppInHold' and value='true')
						set @strColumns=@strColumns+' in(371,441,369) '
					else	
						set @strColumns=@strColumns+'=369 '
					 
					 set @strColumns=@strColumns+'     and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 AND convert(datetime,D.DocDate)<='+CONVERT(nvarchar,CONVERT(float,@Dt))+              
          ' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp),'+@QtyDec+') as HOLDQTY'                     
	END      
	ELSE IF(@SysColumnName='CommittedQty' and @IsColumnUserDefined=0 and @CostCenterID=3)                        
    BEGIN                    
		select @cancelleddocs=Value from adm_globalPreferences WITH(NOLOCK) where  Name='HoldResCancelledDocs'    
		if(@cancelleddocs is not null and @cancelleddocs<>'')
			set @cancelleddocs=' or l.Costcenterid in('+@cancelleddocs+') '	
		else
			set @cancelleddocs=''  
		SET @strColumns=@strColumns +'round(( select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from               
           (SELECT D.HoldQuantity,isnull((select sum(case when l.IsQtyIgnored=0 '+@cancelleddocs+'   then l.Quantity else l.ReserveQuantity end)
          from INV_DocDetails l  WITH(NOLOCK) where d.InvDocDetailsID=l.LinkedInvDocDetailsID    and l.StatusID=369 ),0) release              
           FROM INV_DocDetails D WITH(NOLOCK)    INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID                         
           WHERE D.ProductID=A.ProductID AND D.IsQtyIgnored=1  and D.StatusID=369  and D.DocumentType in (1,2,4,10,25,26,27)  and D.VoucherType=1 AND convert(datetime,D.DocDate)<='+CONVERT(nvarchar,CONVERT(float,@Dt))+              
          ' group by D.InvDocDetailsID,D.HoldQuantity) as t)as temp),'+@QtyDec+') as CommittedQty'                         
	END              
	ELSE IF(@SysColumnName='RESERVEQTY' and @IsColumnUserDefined=0 and @CostCenterID=3)                        
    BEGIN                 
		select @cancelleddocs=Value from adm_globalPreferences WITH(NOLOCK) where  Name='HoldResCancelledDocs'    
		if(@cancelleddocs is not null and @cancelleddocs<>'')
			set @cancelleddocs=' or l.Costcenterid in('+@cancelleddocs+') '	
		else
			set @cancelleddocs=''
		SET @strColumns=@strColumns +'round(( select isnull(sum(HoldQuantity-rel),0) from (select HoldQuantity,case when release>HoldQuantity then HoldQuantity else release end rel from               
			(SELECT D.ReserveQuantity HoldQuantity,isnull((select sum(case when l.IsQtyIgnored=0 '+@cancelleddocs+'   then l.Quantity else l.ReserveQuantity end)
			from INV_DocDetails l  WITH(NOLOCK) where d.InvDocDetailsID=l.LinkedInvDocDetailsID and l.StatusID=369             ),0) release              
			FROM INV_DocDetails D WITH(NOLOCK)    INNER JOIN COM_DocCCData DCC WITH(NOLOCK)  ON DCC.InvDocDetailsID=D.InvDocDetailsID               
		   
			WHERE D.ProductID=A.ProductID AND D.IsQtyIgnored=1  and D.StatusID'
				 
					 if exists(select Value from adm_globalPreferences WITH(NOLOCK) where  Name='ConsiderUnAppInHold' and value='true')
						set @strColumns=@strColumns+' in(371,441,369) '
					else	
						set @strColumns=@strColumns+'=369 '
					 
					 set @strColumns=@strColumns+'     and D.DocumentType in (7,9,11,12,24) and D.VoucherType=-1 AND convert(datetime,D.DocDate)<='+CONVERT(nvarchar,CONVERT(float,@Dt))+              
		   ' group by D.InvDocDetailsID,D.ReserveQuantity) as t)as temp),'+@QtyDec+') as RESERVEQTY'                  
	END               
    ELSE IF(@SysColumnName='ProductGroup' and @IsColumnUserDefined=0 and @CostCenterID=3)                        
    BEGIN    
		SET @strColumns=@strColumns+'(select productname from inv_product WITH(NOLOCK) where productid=a.parentid) as '  +@SysColumnName
    END  
	ELSE IF(@SysColumnName ='BarcodeID' and @CostCenterID=3)              
	BEGIN              
		SET @strColumns=@strColumns+'ISNULL(A.'+@SysColumnName+','''')+ISNULL(STUFF((SELECT '',''+PBC.Barcode 
		FROM INV_ProductBarcode PBC WITH(NOLOCK) 
		WHERE PBC.Barcode<>'''' AND PBC.ProductID=A.ProductID 
		FOR XML PATH('''')),1,0,''''),'''') as '+@SysColumnName                         
    END              
                  
  else if (@SysColumnName ='SalutationID' and @CostCenterID=65)              
  BEGIN              
  SET @strColumns=@strColumns+'SLookup.Name as '  +@SysColumnName              
  END    
    else if (@SysColumnName ='CustomerId' and @CostCenterID=65)              
  BEGIN              
  SET @strColumns=@strColumns+'CRM_Customer.CustomerName as '  +@SysColumnName              
  END           
   else if (@SysColumnName ='AccountID' and @CostCenterID=65)              
  BEGIN              
  SET @strColumns=@strColumns+'Acc_Accounts.AccountName as '  +@SysColumnName        
  END                
  else if (   @SysColumnName ='ContactTypeID' and @CostCenterID=65)              
  BEGIN              
  SET @strColumns=@strColumns+'CLookup.Name as '  +@SysColumnName                         
    END              
 else if ( @SysColumnName ='RoleLookupID' and @CostCenterID=65)              
  BEGIN              
  SET @strColumns=@strColumns+'RLookup.Name as '  +@SysColumnName     
  END  
   else if ( @SysColumnName ='CampaignTypeLookupID' and @CostCenterID=88)              
  BEGIN              
  SET @strColumns=@strColumns+'CTLookup.Name as '  +@SysColumnName              
  SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.CampaignTypeLookupID=CTLookup.NodeID) '              
  END           
  else if (@SysColumnName ='Country' and @CostCenterID=65)              
  BEGIN              
  SET @strColumns=@strColumns+'CTLookup.Name as '  +@SysColumnName                        
  END              
   else if (@SysColumnName ='ParentID' and @CostCenterID=65)              
  BEGIN              
  SET @strColumns=@strColumns+'Features.Name as Source'                         
  END              
   else if (@SysColumnName ='ClassID' and @CostCenterID=72)                
   BEGIN                
   SET @strColumns=@strColumns+'class.AssetClassName as  '   +@SysColumnName              
   SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_AssetClass class WITH(NOLOCK) ON (A.ClassID=class.AssetClassID) '                
   END               
   else if (@SysColumnName ='SubClassID' and @CostCenterID=72)                
   BEGIN                
   SET @strColumns=@strColumns+'subclass.AssetClassName as  ' +@SysColumnName                
   SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_AssetClass subclass WITH(NOLOCK) ON (A.SubClassID=subclass.AssetClassID) '                
   END               
   else if (@SysColumnName ='EmployeeID' and @CostCenterID=72)                
   BEGIN                
   SET @strColumns=@strColumns+'resource.ResourceName as  '+@SysColumnName                 
   SET @STRJOIN=@STRJOIN+'  LEFT JOIN PRD_Resources resource WITH(NOLOCK) ON (A.EmployeeID=resource.ResourceID) '                
   END               
   else if (@SysColumnName ='ParentAssetID' and @CostCenterID=72)                
   BEGIN                
   SET @strColumns=@strColumns+'asset.AssetName as  ' +@SysColumnName                
   SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Assets asset WITH(NOLOCK) ON (A.ParentAssetID=asset.AssetID) '                
   END               
   else if (@SysColumnName ='LocationID' and @CostCenterID=72)                
   BEGIN                
   SET @strColumns=@strColumns+'location.Name as  '  +@SysColumnName               
   SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Location location WITH(NOLOCK) ON (A.LocationID=location.NodeID) '                
   END               
   else if (@SysColumnName ='AssetDepreciationJV' and @CostCenterID=72)                
   BEGIN                
   SET @strColumns=@strColumns+'account.DocumentName as  '+@SysColumnName                 
   SET @STRJOIN=@STRJOIN+'  LEFT JOIN ADM_DocumentTypes account WITH(NOLOCK) ON (A.AssetDepreciationJV=account.CostCenterID) '                
   END               
   else if (@SysColumnName ='AssetDisposalJV' and @CostCenterID=72)                
   BEGIN                
   SET @strColumns=@strColumns+'account.DocumentName as  '+@SysColumnName                 
   SET @STRJOIN=@STRJOIN+'  LEFT JOIN ADM_DocumentTypes account WITH(NOLOCK) ON (A.AssetDisposalJV=account.CostCenterID) '                
   END                
   else if (@SysColumnName ='PostingGroupID' and @CostCenterID=72)                
   BEGIN                
   SET @strColumns=@strColumns+'postinggroup.PostGroupName as  '+@SysColumnName                 
   SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_PostingGroup postinggroup WITH(NOLOCK) ON (A.PostingGroupID=postinggroup.PostingGroupID) '                
   END               
    else if (@SysColumnName ='StatusID' and @CostCenterID=89)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookupSTATUS.Name as  Status '             
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookupSTATUS WITH(NOLOCK) ON (A.StatusID=CTLookupSTATUS.NodeID) '                
  END                  
  else if (@SysColumnName ='ProbabilityLookUpID' and @CostCenterID=89)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup.Name as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.ProbabilityLookUpID=CTLookup.NodeID) '                
  END                  
  else if (@SysColumnName ='RatingLookUpID' and @CostCenterID=89)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup.Name as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.RatingLookUpID=CTLookup.NodeID) '                
  END                 
  else if (@SysColumnName ='ReasonLookUpID' and @CostCenterID=89)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup.Name as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.ReasonLookUpID=CTLookup.NodeID) '                
  END                
  else if (@SysColumnName ='CampaignID' and @CostCenterID=89)                
  BEGIN              
        
  SET @strColumns=@strColumns+'resource.ResourceName as  '    +@SysColumnName               
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN PRD_Resources resource WITH(NOLOCK) ON (A.CampaignID=resource.ResourceID) '                
  END         
              
  else if (@SysColumnName ='SalesmanID' and  @CostCenterID=92)                
  BEGIN          
       
    SET @PREFSALES = ''    
  SELECT @PREFSALES = TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID  = (select   Value from COM_CostCenterPreferences with(nolock) where CostCenterID=92 and Name='Salesman' )    
            
  SET @strColumns=@strColumns+'Salesman.Name as  '    +@SysColumnName               
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN '+@PREFSALES+' Salesman WITH(NOLOCK) ON (A.SalesmanID =Salesman.NodeId) '                
  END      
                
  else if (@SysColumnName ='AccountantID' and @CostCenterID=92)                    
  BEGIN          
    SET @PREFSALES = ''    
  SELECT @PREFSALES = TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID  = (select   Value from COM_CostCenterPreferences with(nolock) where CostCenterID=92 and Name='Accountant' )    
    
  SET @strColumns=@strColumns+'Accountant.Name as  '    +@SysColumnName               
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN '+@PREFSALES+' Accountant WITH(NOLOCK) ON (A.AccountantID =Accountant.NodeId) '                
  END      
      
                
  else if (@SysColumnName ='LandlordID' and  @CostCenterID=92)             
  BEGIN          
   SET @PREFSALES = ''    
  SELECT @PREFSALES = TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID  = (select   Value from COM_CostCenterPreferences with(nolock) where CostCenterID=92 and Name='Landlord' )    
    
  SET @strColumns=@strColumns+'Landlord.Name as  '    +@SysColumnName               
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN '+@PREFSALES+' Landlord WITH(NOLOCK) ON (A.LandlordID =Landlord.NodeId) '                
  END  
  else if ((@SysColumnName ='StartDate' and  @CostCenterID=93)
  or  (@SysColumnName ='EndDate' and  @CostCenterID=93) or (@SysColumnName ='Tenant' and  @CostCenterID=93))
  BEGIN  
	   if (@SysColumnName ='EndDate')         
			SET @strColumns=@strColumns+'(select top 1 convert(nvarchar(12), Convert(datetime,ENDDate),106) from REN_Contract where UnitID=A.UnitID and  REN_Contract.StatusID <> 428   and    REN_Contract.StatusID <> 451 order by ENDDate desc) as  '    +@SysColumnName               
	   else if (@SysColumnName ='Tenant')                         
			SET @strColumns=@strColumns+'(select top 1 FirstName from REN_Contract CNT JOIN REN_Tenant CNTTeN WITH(NOLOCK) ON CNT.TenantID= CNTTeN.TenantID  where UnitID=A.UnitID and  CNT.StatusID <> 428   and    CNT.StatusID <> 451 order by ENDDate desc) as  '    +@SysColumnName               
       else
			SET @strColumns=@strColumns+' (select top 1 convert(nvarchar(12), Convert(datetime,StartDate),106) from REN_Contract where UnitID=A.UnitID and StatusID <> 428   and    StatusID <> 451 order by ENDDate desc) as  '    +@SysColumnName               
  END        
    
  else if (@SysColumnName ='SalesmanID' and  @CostCenterID=93)                
  BEGIN          
       
    SET @PREFSALES = ''    
  SELECT @PREFSALES = TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID  = (select   Value from COM_CostCenterPreferences with(nolock) where CostCenterID=92 and Name='Salesman' )    
            
  SET @strColumns=@strColumns+'Salesman.Name as  '    +@SysColumnName               
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN '+@PREFSALES+' Salesman WITH(NOLOCK) ON (A.SalesmanID =Salesman.NodeId) '                
  END      
                
  else if (@SysColumnName ='AccountantID' and @CostCenterID=93)                    
  BEGIN          
    SET @PREFSALES = ''    
  SELECT @PREFSALES = TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID  = (select   Value from COM_CostCenterPreferences with(nolock) where CostCenterID=92 and Name='Accountant' )    
    
  SET @strColumns=@strColumns+'Accountant.Name as  '    +@SysColumnName               
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN '+@PREFSALES+' Accountant WITH(NOLOCK) ON (A.AccountantID =Accountant.NodeId) '                
  END     
                
  else if (@SysColumnName ='LandlordID' and  @CostCenterID=93)             
  BEGIN          
   SET @PREFSALES = ''    
  SELECT @PREFSALES = TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID  = (select   Value from COM_CostCenterPreferences with(nolock) where CostCenterID=92 and Name='Landlord' )    
    
  SET @strColumns=@strColumns+'Landlord.Name as  '    +@SysColumnName               
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN '+@PREFSALES+' Landlord WITH(NOLOCK) ON (A.LandlordID =Landlord.NodeId) '                
  END     
  else if (@SysColumnName ='SalesmanID' and  @CostCenterID=95)                
  BEGIN          
    SET @PREFSALES = ''    
  SELECT @PREFSALES = TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID  = (select   Value from COM_CostCenterPreferences with(nolock) where CostCenterID=92 and Name='Salesman' )    
            
  SET @strColumns=@strColumns+'Salesman.Name as  '    +@SysColumnName               
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN '+@PREFSALES+' Salesman WITH(NOLOCK) ON (A.SalesmanID =Salesman.NodeId) '                
  END      
                
  else if ((@SysColumnName ='AccountantID' or @SysColumnName ='RentAmount') and (@CostCenterID=95 OR @CostCenterID=103 OR @CostCenterID=104 OR @CostCenterID=129 ))                    
  BEGIN    
	  if(@SysColumnName='RentAmount')
	  begin
			declare @rntid INT
			set @rntid=0
			SET @PREFSALES = ''    
			select @PREFSALES=TABLENAME from adm_globalpreferences a WITH(NOLOCK)
			join adm_features b WITH(NOLOCK) on a.value=b.featureid
			WHERE a.name ='DepositLinkDimension' and a.value is not null and isnumeric(a.value)=1
			if(@PREFSALES <> '')
			BEGIN
				SET @PREFSALES='select @rntid=nodeid from '+@PREFSALES+' WITH(NOLOCK) where name=''Rent'''
				EXEC sp_executesql @PREFSALES,N'@rntid INT OUTPUT',@rntid OUTPUT				
			END
			
		  SET @strColumns=@strColumns+' FORMAT(isnull((select sum(RentAmount) from '
		  if(@CostCenterID=95 OR @CostCenterID=104 )
		  begin
			SET @strColumns=@strColumns+'REN_ContractParticulars WITH(NOLOCK) where contractid=A.ContractID '
		   end
		  else if(@CostCenterID=103 OR @CostCenterID=129)
		  begin
			SET @strColumns=@strColumns+'REN_QuotationParticulars WITH(NOLOCK) where QuotationID=A.QuotationID '
		   end
		   SET @strColumns=@strColumns+' and CCNodeID='+convert(nvarchar(max),@rntid)+' ),0),''N0'''
		   IF(@FORMAT='Lakhs')
			SET @strColumns=@strColumns+',''en-IN'''
		   SET @strColumns=@strColumns+') as '+@SysColumnName
	  end
	  else if(@SysColumnName='AccountantID')
	  begin      
		SET @PREFSALES = ''    
		SELECT @PREFSALES = TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID  = (select   Value from COM_CostCenterPreferences with(nolock) where CostCenterID=92 and Name='Accountant' )    
		    
		SET @strColumns=@strColumns+'Accountant.Name as '+@SysColumnName               
		SET @STRJOIN=@STRJOIN+' LEFT JOIN '+@PREFSALES+' Accountant WITH(NOLOCK) ON (A.AccountantID =Accountant.NodeId) '
	  end
END      
           
  else if (@SysColumnName in('LandlordID','sno') and  @CostCenterID=95)             
  BEGIN
	   if(@SysColumnName='LandlordID')
	   BEGIN
		   SET @PREFSALES = ''    
		  SELECT @PREFSALES = TABLENAME FROM ADM_FEATURES with(nolock) WHERE FEATUREID  = (select   Value from COM_CostCenterPreferences with(nolock) where CostCenterID=92 and Name='Landlord' )    
		    
		  SET @strColumns=@strColumns+'Landlord.Name as  '    +@SysColumnName               
		  SET @STRJOIN=@STRJOIN+'  LEFT JOIN '+@PREFSALES+' Landlord WITH(NOLOCK) ON (A.LandlordID =Landlord.NodeId) '                
	  END
	  ELSE
		 SET @strColumns=@strColumns+'case when A.RefNo is not null and A.RefNo>0 then convert(nvarchar(max),A.RefNo)+''/''+convert(nvarchar(max),A.SNO) else convert(nvarchar(max),A.SNO) end as  '    +@SysColumnName                
  END      
               
  else if (@SysColumnName ='LeadID' and @CostCenterID=89)                
  BEGIN                
  SET @strColumns=@strColumns+'lead.Company as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN CRM_Leads lead WITH(NOLOCK) ON (A.LeadID=lead.LeadID) '                
  END                
  else if (@SysColumnName ='Currency' and @CostCenterID=2)                
  BEGIN                
  SET @strColumns=@strColumns+'currency.Name as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Currency currency WITH(NOLOCK) ON (A.Currency=currency.CurrencyID) '                
  END  
   else if (@SysColumnName ='PaymentTerms' and @CostCenterID=2)                
  BEGIN                
  SET @strColumns=@strColumns+'PaymentTerms.ProfileName as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN Acc_PaymentDiscountProfile PaymentTerms WITH(NOLOCK) ON (A.PaymentTerms=PaymentTerms.ProfileID) '                
  END               
  else if (@SysColumnName ='CurrencyID' and @CostCenterID=89)                
  BEGIN                
  SET @strColumns=@strColumns+'currency.Name as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Currency currency WITH(NOLOCK) ON (A.Currency=currency.CurrencyID) '                
  END               
  --else if (@SysColumnName ='AssignedTo' and @CostCenterID=73)                
  --BEGIN                
  --SET @strColumns=@strColumns+'Users.UserName as  '     +@SysColumnName              
  --SET @STRJOIN=@STRJOIN+'  LEFT JOIN ADM_Users Users WITH(NOLOCK) ON (A.AssignedTo=Users.UserID) '                
  --END               
                
 else if (@SysColumnName ='CaseTypeLookupID' and @CostCenterID=73)                  
  BEGIN                  
  SET @strColumns=@strColumns+'CTLookup.Name as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.CaseTypeLookupID=CTLookup.NodeID) '                  
  END                 
                 
 else if (@SysColumnName ='CaseOriginLookupID' and @CostCenterID=73)                  
  BEGIN                  
  SET @strColumns=@strColumns+'CTLookup3.Name as '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup3 WITH(NOLOCK) ON (A.CaseOriginLookupID=CTLookup3.NodeID) '                  
  END                
                   
  else if (@SysColumnName ='CasePriorityLookupID' and @CostCenterID=73)                  
  BEGIN                  
  SET @strColumns=@strColumns+'CTLookup1.Name as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup1 WITH(NOLOCK) ON (A.CasePriorityLookupID=CTLookup1.NodeID) '                  
  END                
  else if (@SysColumnName ='ServiceLvlLookupID' and @CostCenterID=73)                  
  BEGIN                  
  SET @strColumns=@strColumns+'CTLookup2.Name as '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup2 WITH(NOLOCK) ON (A.ServiceLvlLookupID=CTLookup2.NodeID) '                  
  END                
else if (@SysColumnName ='CustomerID' and @CostCenterID=73)                  
  BEGIN      
  SET @strColumns=@strColumns+'CASE WHEN CUSTOMERMODE=1 THEN (cust.AccountName) ELSE (CRMCUST.CUSTOMERNAME) END as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_ACCOUNTS cust WITH(NOLOCK) ON (A.CustomerID=cust.AccountID) '   
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN CRM_CUSTOMER CRMCUST WITH(NOLOCK) ON (A.CustomerID=CRMCUST.CustomerID) '                  
               
  END                  
  else if (@SysColumnName ='SvcContractID' and @CostCenterID=73)                  
  BEGIN                  
  SET @strColumns=@strColumns+'contract.DocID as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN CRM_ServiceContract contract WITH(NOLOCK) ON (A.SvcContractID=contract.SvcContractID) '                 
  END              
  else if (@SysColumnName ='ContractLineID' and @CostCenterID=73)                  
  BEGIN                  
  SET @strColumns=@strColumns+'convert(nvarchar,A.ContractLineID)+''-''+contract.ProductNAME '+' as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN INV_Product contract WITH(NOLOCK) ON (A.ProductID=contract.ProductID) '                  
  END                  
  --else if (@SysColumnName ='ProductID' and @CostCenterID=73)                  
  --BEGIN                  
  --SET @strColumns=@strColumns+'product.ProductNAME as '     +@SysColumnName              s
  --SET @STRJOIN=@STRJOIN+'  LEFT JOIN INV_Product product WITH(NOLOCK) ON (A.ProductID=product.ProductID) '                  
  --END              
  else if (@SysColumnName ='AssignedTo' and (@CostCenterID=86 or @CostCenterID=89 or @CostCenterID=83  or @CostCenterID=73))           
   BEGIN        
 SET @strColumns=@strColumns+' dbo.fnGet_GetAssignedListForFeatures('+CONVERT(nvarchar(300),@CostCenterID)+','+@Pcol+') AssignedTo '  
  END  
  else if (@SysColumnName ='AssignedFrom' and @CostCenterID=89)
   BEGIN        
 SET @strColumns=@strColumns+'(select top 1 Createdby from CRM_Assignment WITH(NOLOCK) where CCID='+CONVERT(nvarchar(300),@CostCenterID)+' and CCNODEID='+@Pcol+') AssignedFrom '  
  END    
  else if (@SysColumnName ='SourceLookUpID' and @CostCenterID=86)                  
  BEGIN                  
  SET @strColumns=@strColumns+'CTLookup.Name as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.SourceLookUpID=CTLookup.NodeID) '             
  END               
  else if (@SysColumnName ='RoleLookupID' and @CostCenterID=86)                  
  BEGIN                  
  SET @strColumns=@strColumns+'CT1Lookup.Name as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CT1Lookup WITH(NOLOCK) ON (CON.RoleLookupID=CT1Lookup.NodeID) '                  
  END                   
  else if ((@SysColumnName ='RatinglookupID' or @SysColumnName ='IndustryLookUpID') and @CostCenterID=86)                  
  BEGIN     
      if(@SysColumnName='RatinglookupID')
      begin         
		  SET @strColumns=@strColumns+'CT2Lookup.Name as  '     +@SysColumnName              
		  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CT2Lookup WITH(NOLOCK) ON (A.RatinglookupID=CT2Lookup.NodeID) '                  
	  end
	  else
	  begin         
		  SET @strColumns=@strColumns+'Industry.Name as  '     +@SysColumnName              
		  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup Industry WITH(NOLOCK) ON (A.IndustryLookUpID=Industry.NodeID) '                  
	  end
  END               
  else if (@SysColumnName ='SalutationID' and @CostCenterID=86)                  
  BEGIN                  
  SET @strColumns=@strColumns+'CT3Lookup.Name as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CT3Lookup WITH(NOLOCK) ON (CON.SalutationID=CT3Lookup.NodeID) '                  
  END               
                
   else if (@SysColumnName ='Country' and @CostCenterID=86)                  
  BEGIN                  
  SET @strColumns=@strColumns+'CT4Lookup.Name as  '     +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CT4Lookup WITH(NOLOCK) ON (CON.Country=CT4Lookup.NodeID) '                  
  END        
  else if (@CostCenterColID between 26706 and 26720)--Address Fields
  BEGIN                  
	if @IsAddressDisplayed=0
	begin
		set @IsAddressDisplayed=1
		SET @STRJOIN=@STRJOIN+'
	  LEFT JOIN COM_Address ADDS WITH(NOLOCK) ON ADDS.AddressTypeID=1 and ADDS.FeatureID='+convert(nvarchar,@CostCenterID)+' and ADDS.FeaturePK='+@Pcol
	end
	SET @strColumns=@strColumns+'ADDS.'+@SysColumnName+' as  ' +@SysColumnName                        
  END  
  else if (@SysColumnName IN ('FIRSTNAME','MiddleName','LastName','JobTitle','Phone1','Phone2','Email1','Fax','Department','Address1','Address2','Address3') and (@CostCenterID=86 or @CostCenterID=89))                  
	SET @strColumns=@strColumns+'CON.'+@SysColumnName+' as '+@SysColumnName                                           
  else if (@SysColumnName ='CampaignID' and @CostCenterID=86)                  
  BEGIN                  
	SET @strColumns=@strColumns+'Camp.Name as  '     +@SysColumnName              
	SET @STRJOIN=@STRJOIN+'  LEFT JOIN CRM_Campaigns Camp WITH(NOLOCK) ON (A.CampaignID=Camp.CampaignID) '                  
  END   
  else if (@SysColumnName ='DeprBookGroupID' and @CostCenterID=72  )              
  BEGIN                
   SET @strColumns=@strColumns+'DB.DeprBookName  as  '     +@SysColumnName                      
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_DeprBook DB WITH(NOLOCK) ON A.DeprBookGroupID=DB.DeprBookID  '   
           
  END            
  else if (@SysColumnName ='AveragingMethod' and (@CostCenterID=75 or @CostCenterID=72)  )              
  BEGIN                
  SET @strColumns=@strColumns+'Case WHen a.AveragingMethod=1 then  ''None'' else ''FullMonth'' end  as  '     +@SysColumnName                    
  END     
  else if (@SysColumnName ='DeprBookMethod' and (@CostCenterID=75 or @CostCenterID=72)  )                  
  BEGIN                
  SET @strColumns=@strColumns+'DM.Name  as  '     +@SysColumnName                      
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_DepreciationMethods DM WITH(NOLOCK) ON (A.DeprBookMethod=DM.DepreciationMethodID) '                
  END                         
                    
  else if (@SysColumnName ='PropertyTypeLookUpID' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup.Name as  ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.PropertyTypeLookUpID=CTLookup.NodeID) '                
  END                
  else if (@SysColumnName ='LandLordLookUpID' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup.Name as ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.LandLordLookUpID=CTLookup.NodeID) '                
  END                 
  else if (@SysColumnName ='BondTypeLookUpID' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup.Name as  ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.BondTypeLookUpID=CTLookup.NodeID) '                
  END                
  else if (@SysColumnName ='PropertyPositionLookUpID' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup.Name as  ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.PropertyPositionLookUpID=CTLookup.NodeID) '                
  END        
  else if (@SysColumnName ='PropertyCategoryLookUpID' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup.Name as  ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.PropertyCategoryLookUpID=CTLookup.NodeID) '                
  END                
  else if (@SysColumnName ='RentalIncomeAccountID' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'ACC.Name as ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.RentalIncomeAccountID=ACC.AccountID) '                
  END                
  else if (@SysColumnName ='RentalReceivableAccountID' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'ACC.Name as ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.RentalReceivableAccountID=ACC.AccountID) '                
  END                
  else if (@SysColumnName ='AdvanceRentAccountID' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'ACC.Name as ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.AdvanceRentAccountID=ACC.AccountID) '                
  END                
  else if (@SysColumnName ='BankAccount' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'ACC.Name as ' +@SysColumnName                
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.BankAccount=ACC.AccountID) '                
  END                
  else if (@SysColumnName ='BankLoanAccount' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'ACC.Name as ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.BankLoanAccount=ACC.AccountID) '                
  END                
  else if (@SysColumnName ='RentalAccount' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'ACC.Name as ' +@SysColumnName                
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.RentalAccount=ACC.AccountID) '                
  END                
  else if (@SysColumnName ='RentPayableAccount' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'ACC.Name as  ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.RentPayableAccount=ACC.AccountID) '                
  END                
  else if (@SysColumnName ='AdvanceRentPaid' and @CostCenterID=92)                
  BEGIN                
  SET @strColumns=@strColumns+'ACC.Name as  ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts ACC WITH(NOLOCK) ON (A.AdvanceRentPaid=ACC.AccountID) '                
  END                
                
  else if (@SysColumnName ='FloorLookUpID' and @CostCenterID=93)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup.Name as  ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.FloorLookUpID=CTLookup.NodeID) '                
  END                
  else if (@SysColumnName ='ViewLookUpID' and @CostCenterID=93)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup1.Name as ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup1 WITH(NOLOCK) ON (A.ViewLookUpID=CTLookup1.NodeID) '                
  END                 
  else if (@SysColumnName ='RentTypeID' and @CostCenterID=93)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup2.Name as  ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup2 WITH(NOLOCK) ON (A.RentTypeID=CTLookup2.NodeID) '                
  END  
  else if (@SysColumnName ='RentTypeID' and @CostCenterID=93)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup2.Name as  ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup2 WITH(NOLOCK) ON (A.RentTypeID=CTLookup2.NodeID) '                
  END            
  else if (@SysColumnName ='PropertyID' and @CostCenterID=93)                
  BEGIN                
	SET @strColumns=@strColumns+'PRT.Name as  ' +@SysColumnName                 
	SET @STRJOIN=@STRJOIN+'  LEFT JOIN REN_Property PRT WITH(NOLOCK) ON (A.PropertyID=PRT.NodeID)  '            
  end  
           
  else if (@SysColumnName ='PositionID' and @CostCenterID=94)                
  BEGIN                
  SET @strColumns=@strColumns+'CTLookup.Name as  ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.PositionID=CTLookup.NodeID) '                
  END              
       
  else if ( @CostCenterID in (95,104,103,129) and (@SysColumnName ='UnitID' or @SysColumnName='PropertyID'  or @SysColumnName='TenantID'
  or @SysColumnName='RentAccID' ))                
  BEGIN          
	if @SysColumnName ='UnitID'
	begin 
		SET @strColumns=@strColumns+'UNT.Name as   ' +@SysColumnName                
		SET @STRJOIN=@STRJOIN+'  LEFT JOIN REN_Units UNT WITH(NOLOCK) ON (A.UnitID=UNT.UnitID) '                
	end
	else if @SysColumnName ='PropertyID'
	begin 
	    SET @strColumns=@strColumns+'PRT.Name as  ' +@SysColumnName                 
		SET @STRJOIN=@STRJOIN+'  LEFT JOIN REN_Property PRT WITH(NOLOCK) ON (A.PropertyID=PRT.NodeID)  '                       
	end
	else if @SysColumnName ='TenantID'
	begin 
		SET @strColumns=@strColumns+'TNT.FirstName as   ' +@SysColumnName              
		SET @STRJOIN=@STRJOIN+'  LEFT JOIN REN_Tenant TNT WITH(NOLOCK) ON (A.TenantID=TNT.TenantID) '                     
	end
	else if @SysColumnName ='RentAccID'
	begin 
		SET @strColumns=@strColumns+'RENACC.Name as  ' +@SysColumnName               
		SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts RENACC WITH(NOLOCK) ON (A.RentAccID=RENACC.AccountID) '                        
	end
	else if (@SysColumnName ='IncomeAccID')                
	BEGIN                
		SET @strColumns=@strColumns+'INACC.Name as   ' +@SysColumnName                
		SET @STRJOIN=@STRJOIN+'  LEFT JOIN ACC_Accounts	INACC WITH(NOLOCK) ON (A.IncomeAccID=INACC.AccountID) '                
	END 
  END                  
  
  else if ((@SysColumnName ='ProductID' or @SysColumnName ='CRMPRODUCT') and (@CostCenterID=86 or @CostCenterID=89 or @CostCenterID=73))                
  BEGIN               
		IF @SysColumnName ='ProductID'
			SET @strColumns=@strColumns+' dbo.fnGet_ProductsBasedonFeature('+CONVERT(nvarchar(300),@CostCenterID)+','+@Pcol+',0) Product ' 
	    ELSE 
	        SET @strColumns=@strColumns+' dbo.fnGet_ProductsBasedonFeature('+CONVERT(nvarchar(300),@CostCenterID)+','+@Pcol+',1) CRMProduct '		   
  END       
 
 else if (@SysColumnName ='LocationID' and @CostCenterID=95)                
  BEGIN                
  SET @strColumns=@strColumns+'Loc.Name as   ' +@SysColumnName                
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Location Loc WITH(NOLOCK) ON (A.LocationID=Loc.NodeID) '                
  END                        
else if (@SysColumnName ='RenewRefID' and @CostCenterID=95)                
  BEGIN                
  --SET @strColumns=@strColumns+'RC.SNO  as   ' +@SysColumnName                
  SET @strColumns=@strColumns+' case when RC.RefNo is not null and RC.RefNo>0 then convert(nvarchar(max),RC.RefNo)+''/''+convert(nvarchar(max),RC.SNO) else convert(nvarchar(max),RC.SNO) end as ' +@SysColumnName 
  SET @STRJOIN=@STRJOIN+'   LEFT JOIN REN_Contract RC with(nolock) ON RC.ContractID=A.RenewRefID   '                
  END 
  else if (@SysColumnName ='Reserve' and @CostCenterID=95)                
  BEGIN                
  SET @strColumns=@strColumns+'CASE WHEN RQ.COSTCENTERID=103 THEN  CONVERT(VARCHAR,A.QuotationID)+'' - Quotation'' WHEN RQ.COSTCENTERID=129 THEN CONVERT(VARCHAR,A.QuotationID)+'' - Reservation''  end as   ' +@SysColumnName
  SET @STRJOIN=@STRJOIN+'   LEFT JOIN REN_Quotation RQ WITH(NOLOCK) ON RQ.QUOTATIONID=A.QUOTATIONID '   
  END 
  else if (@SysColumnName ='Quotation' and @CostCenterID=129)                
  BEGIN                
  SET @strColumns=@strColumns+'A.LinkedQuotationID  as   ' +@SysColumnName                
  END 
   else if (@SysColumnName ='Reserve' and @CostCenterID=103)                
  BEGIN                
  SET @strColumns=@strColumns+' CASE WHEN ISNULL(RQ.QuotationID,0)>0 THEN convert(varchar,RQ.QuotationID) + convert(varchar,'' - Reservation'')   ELSE convert(varchar,RC.SNo) + convert(varchar,'' - Contract'')  END as  ' +@SysColumnName  
  SET @STRJOIN=@STRJOIN+' LEFT JOIN REN_Quotation RQ with(nolock) ON RQ.LinkedQuotationID=A.QuotationID  '  
  SET @STRJOIN=@STRJOIN+' LEFT JOIN REN_contract RC with(nolock) ON RC.QuotationID=A.QuotationID  '               
  END 
   ELSE IF(@SysColumnName='StatusID' and @CostCenterID=7)                
    BEGIN             
     SET @strColumns=@strColumns+'case WHEN (a.ISUSERDELETED=1) THEN (''Deleted'') else Ss.Status  end Status'                
     SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Status SS WITH(NOLOCK) ON A.StatusID=SS.StatusID   '     
    END  
	--ELSE IF(@SysColumnName='StatusID' and @CostCenterID=2)                
 --   BEGIN             
                 
 --    SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Status SS WITH(NOLOCK) ON A.StatusID=SS.StatusID   '     
 --   END  
    ELSE IF(@SysColumnName='StatusID' and @CostCenterID=95)                
    BEGIN 
		 SET @strColumns=@strColumns+'S.ResourceData + case when RefS.ResourceData is not null then ''  [''+RefS.ResourceData+'']'' else '''' end as Status'                
		 SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Status SS WITH(NOLOCK) ON A.StatusID=SS.StatusID    
		 LEFT JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=SS.ResourceID AND S.LanguageID='+convert(NVARCHAR(10),@LangID)+
		 'LEFT JOIN REN_Contract refcnt WITH(NOLOCK) ON refcnt.RenewRefID=A.ContractID and  refcnt.StatusID<>451  and refcnt.COSTCENTERID = 95 
		LEFT JOIN COM_Status RefSS WITH(NOLOCK) ON refcnt.StatusID=RefSS.StatusID    
		LEFT JOIN COM_LanguageResources RefS WITH(NOLOCK) ON RefS.ResourceID=RefSS.ResourceID AND RefS.LanguageID='+convert(NVARCHAR(10),@LangID)
		 
    end                 
    ELSE IF(@SysColumnName='StatusID' and @ColumnCostCenterID<>113)                
    BEGIN 
		 SET @strColumns=@strColumns+'S.ResourceData as Status'                
		 SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Status SS WITH(NOLOCK) ON A.StatusID=SS.StatusID    
		 LEFT JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=SS.ResourceID AND S.LanguageID='+convert(NVARCHAR(10),@LangID)                     
    end        
     ELSE IF(@SysColumnName='Status' and @CostCenterID=93  )                
    BEGIN       
		 SET @strColumns=@strColumns+'S.ResourceData as Status'                
		 SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Status SS WITH(NOLOCK) ON A.Status=SS.StatusID   
		 LEFT JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=SS.ResourceID AND S.LanguageID='+convert(NVARCHAR(10),@LangID)                
    END                 
 ELSE IF(@SysColumnName='RoleID')                
    BEGIN
 
     SET @strColumns=@strColumns+'ROLE.Name'            
     SET @STRJOIN=@STRJOIN+'                 
LEFT JOIN ADM_UserRoleMap ROLEM WITH(NOLOCK) ON A.UserID=ROLEM.UserId and ROLEM.IsDefault=1               
LEFT JOIN ADM_PRoles ROLE WITH(NOLOCK) ON ROLEM.RoleID=ROLE.RoleID'              
    END              
              
    ELSE IF(@SysColumnName='AccountTypeID')                
    BEGIN                
  --  if @CostCenterID=2              
  --set @tempgroup=@tempgroup+'AT.ResourceData , '              
     SET @strColumns=@strColumns+'AT.ResourceData as AccountType'                
     SET @STRJOIN=@STRJOIN+' JOIN ACC_AccountTypes AA WITH(NOLOCK) ON A.AccountTypeID=AA.AccountTypeID                 
     JOIN COM_LanguageResources AT WITH(NOLOCK) ON AT.ResourceID=AA.ResourceID AND AT.LanguageID='+convert(NVARCHAR(10),@LangID)                
    END                
    ELSE IF(@SysColumnName='CustomerTypeID')                
    BEGIN                
      SET @strColumns=@strColumns+'CTLookup2.Name as  ' +@SysColumnName              
  SET @STRJOIN=@STRJOIN+'  LEFT JOIN COM_Lookup CTLookup2 WITH(NOLOCK) ON (A.CustomerTypeID=CTLookup2.NodeID) '                

  --  if @CostCenterID=2              
  --set @tempgroup=@tempgroup+'AT.ResourceData , '              
     --SET @strColumns=@strColumns+'AT.ResourceData as CustomerType'                
     --SET @STRJOIN=@STRJOIN+' JOIN ACC_AccountTypes AA WITH(NOLOCK) ON A.CustomerTypeID=AA.AccountTypeID                
     --JOIN COM_LanguageResources AT WITH(NOLOCK) ON AT.ResourceID=AA.ResourceID AND AT.LanguageID='+convert(NVARCHAR(10),@LangID)                
    END                
    ELSE IF(@SysColumnName='ProductTypeID')                
    BEGIN                
  --  if @CostCenterID=2              
  --set @tempgroup=@tempgroup+'PT.ResourceData , '              
     SET @strColumns=@strColumns+'PT.ResourceData as ProductType'                
     SET @STRJOIN=@STRJOIN+' JOIN INV_ProductTypes PP WITH(NOLOCK) ON A.ProductTypeID=PP.ProductTypeID                
     JOIN COM_LanguageResources PT WITH(NOLOCK) ON PT.ResourceID=PP.ResourceID AND PT.LanguageID='+ convert(NVARCHAR(10),@LangID)                
    END                
    ELSE IF(@SysColumnName='ValuationID')                
    BEGIN                
     SET @strColumns=@strColumns+'VT.ResourceData as ValuationMethod'                
     SET @STRJOIN=@STRJOIN+' JOIN INV_ValuationMethods VV WITH(NOLOCK) ON A.ValuationID=VV.ValuationID                
     JOIN COM_LanguageResources VT WITH(NOLOCK) ON VT.ResourceID=VV.ResourceID AND VT.LanguageID='+ convert(NVARCHAR(10),@LangID)                
    END                 
                   
    ELSE IF(@SysColumnName='UserColumnName')                
    BEGIN                
     SET @strColumns=@strColumns+'B.ResourceData'                
    END                
    ELSE IF(@SysColumnName <> '' and @SysColumnName not like 'dcccnid%' AND @SysColumnName not like 'dcAlpha%')                
    BEGIN                
     if(@ColumnDataType is not null and @ColumnDataType='DATE')                
      SET @strColumns=@strColumns+' CASE WHEN  A.'+@SysColumnName+' > '+case when @SysColumnName like '%Alpha%' then '''0''' else '0' end+' THEN  convert(nvarchar(12), Convert(datetime,A.'+@SysColumnName+'),106) ELSE '''' END as '+@SysColumnName                
     else                
     begin              
  --   if @CostCenterID=2              
  --set @tempgroup=@tempgroup+'A.'+@SysColumnName +' , '              
  if(@CostCenterID=2 and @SysColumnName='Level')
	SET @strColumns=@strColumns+'A.Depth as '+@SysColumnName      
  else
	SET @strColumns=@strColumns+'A.'+@SysColumnName                
  --select @SysColumnName, @strColumns              
      end              
     END   
     ELSE IF(@SysColumnName like 'dcccnid%')   
             SET @strColumns=@strColumns+'DCM.'+@SysColumnName                
     ELSE IF(@SysColumnName like 'dcAlpha%')   
             SET @strColumns=@strColumns+'DTM.'+@SysColumnName   
                     
   END     
   
            
   if(@CostCenterid=80)              
   begin              
		set @Where='A.ResourceTypeid=2'              
   end              
                  
 --  if(@CostCenterid=2)              
 --   begin              
 --   set @tempgroup=@tempgroup+ ' A.lft , A.Depth , A.IsGroup, A.ParentID,A.AccountID ,A.AccountTypeID, '                                    
              
 -- set @tempgroup=substring(@tempgroup,1,LEN(@tempgroup)-1)              
 -- SET @tempgroup=' group by ' + @tempgroup                
 --end              
                  
     IF(@CostCenterID=2 AND EXISTS (SELECT ROLEID FROM ADM_FEATUREACTIONROLEMAP with(nolock) WHERE FEATUREACTIONID =587 
     AND RoleID=@RoleID) AND @UserID<>1)
	begin
		if @Where<>''
		BEGIN
			IF EXISTS (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues with(nolock) WHERE UserID=@UserID AND FEATUREID=2) 
				set @Where=@Where+ 'AND A.ACCOUNTTYPEID IN (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues  with(nolock)
				WHERE FEATUREID=2 AND USERID='+CONVERT(NVARCHAR(10),@UserID)+')' 
			ELSE IF EXISTS (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues with(nolock) WHERE ROLEID=@RoleID)
				set @Where=@Where+ 'AND A.ACCOUNTTYPEID IN (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues with(nolock)
				WHERE  FEATUREID=2 AND ROLEID='+convert(nvarchar,@RoleID)+')'
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues with(nolock) WHERE UserID=@UserID AND FEATUREID=2) 
				set @Where=' A.ACCOUNTTYPEID IN (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues with(nolock)
				WHERE  FEATUREID=2 AND USERID='+CONVERT(NVARCHAR(10),@UserID)+')' 
			ELSE IF EXISTS (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues with(nolock) WHERE ROLEID=@RoleID)
				set @Where=' A.ACCOUNTTYPEID IN (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues  with(nolock)
				WHERE FEATUREID=2 AND ROLEID='+convert(nvarchar,@RoleID)+')'
		END
	end
	ELSE  IF(@CostCenterID=3 AND EXISTS (SELECT ROLEID FROM ADM_FEATUREACTIONROLEMAP with(nolock) WHERE FEATUREACTIONID =588 
     AND RoleID=@RoleID)AND @UserID<>1)
	begin
		if @Where<>''
		BEGIN
			IF EXISTS (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues with(nolock) WHERE UserID=@UserID AND FEATUREID=3) 
				set @Where=@Where+ 'AND A.PRODUCTTYPEID IN (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues  with(nolock)
				WHERE FEATUREID=3 AND  USERID='+CONVERT(NVARCHAR(10),@UserID)+')' 
			ELSE IF EXISTS (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues with(nolock) WHERE ROLEID=@RoleID)
				set @Where=@Where+ 'AND A.PRODUCTTYPEID IN (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues  with(nolock)
				WHERE  FEATUREID=3 AND ROLEID='+convert(nvarchar,@RoleID)+')'
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues with(nolock) WHERE UserID=@UserID AND FEATUREID=3) 
				set @Where=' A.PRODUCTTYPEID IN (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues  with(nolock)
				WHERE  FEATUREID=3 AND USERID='+CONVERT(NVARCHAR(10),@UserID)+')' 
			ELSE IF EXISTS (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues  with(nolock) WHERE ROLEID=@RoleID)
				set @Where=' A.PRODUCTTYPEID IN (SELECT FEATURETYPEID FROM ADM_FeatureTypeValues with(nolock)
				WHERE  FEATUREID=3 AND ROLEID='+convert(nvarchar,@RoleID)+')'
		END
	end
	IF EXISTS (SELECT UserID FROM ADM_UserRoleRestrictions with(nolock) WHERE UserID=@UserID)                
		SET @RestrictionWhere='UserID='+CONVERT(NVARCHAR(10),@UserID)         
	IF EXISTS (SELECT UserID FROM ADM_UserRoleRestrictions with(nolock) WHERE UserGroupID IN                 
				(SELECT UserGroupID FROM ADM_UserRoleGroups with(nolock) WHERE UserID=@UserID))                
		SET @RestrictionWhere='UserGroupID IN (SELECT UserGroupID FROM ADM_UserRoleGroups with(nolock) WHERE UserID='+CONVERT(NVARCHAR(10),@UserID)+')'                
   IF EXISTS (SELECT UserID FROM ADM_UserRoleRestrictions with(nolock) WHERE RoleID=@RoleID)
   SET @RestrictionWhere='RoleID='+convert(nvarchar,@RoleID)                
   IF(@RestrictionWhere IS NOT NULL)                
   BEGIN                
    IF(@CostCenterID=3)                
     SET @RestrictionWhere='A.ProductID NOT IN(SELECT ProductID from INV_ProductCostCenterMap M WITH(NOLOCK) '                
          +'join ADM_UserRoleRestrictions UR WITH(NOLOCK) ON M.CostCenterID=UR.CostCenterID and M.NodeID=UR.NodeID AND UR.'+@RestrictionWhere+')'                
          +' AND A.ProductID NOT IN(SELECT NodeID FROM ADM_UserRoleRestrictions WITH(NOLOCK) WHERE CostCenterID='+CONVERT(NVARCHAR(10),@CostCenterID)+' AND '+@RestrictionWhere+')'                
    ELSE IF(@CostCenterID=2)                
     SET @RestrictionWhere = 'A.AccountID NOT IN(SELECT AccountID from ACC_AccountCostCenterMap M WITH(NOLOCK) '                
          +'join ADM_UserRoleRestrictions UR WITH(NOLOCK) ON M.CostCenterID=UR.CostCenterID and M.NodeID=UR.NodeID AND UR.'+@RestrictionWhere+')'                
          +' AND A.AccountID NOT IN(SELECT NodeID FROM ADM_UserRoleRestrictions WITH(NOLOCK) WHERE CostCenterID='+CONVERT(NVARCHAR(10),@CostCenterID)+' AND '+@RestrictionWhere+')'                
    ELSE IF(@CostCenterID=16)                
     SET @RestrictionWhere = 'A.BatchID NOT IN(SELECT BatchID from INV_BatchCostCenterMap M WITH(NOLOCK) '                
          +'join ADM_UserRoleRestrictions UR WITH(NOLOCK) ON M.CostCenterID=UR.CostCenterID and M.NodeID=UR.NodeID AND UR.'+@RestrictionWhere+')'                
          +' AND A.BatchID NOT IN(SELECT NodeID FROM ADM_UserRoleRestrictions WITH(NOLOCK) WHERE CostCenterID='+CONVERT(NVARCHAR(10),@CostCenterID)+' AND '+@RestrictionWhere+')'                
   ELSE                
     SET @RestrictionWhere = 'A.NodeID NOT IN(SELECT ParentNodeID from COM_CostCenterCostCenterMap M WITH(NOLOCK) '                
          +'join ADM_UserRoleRestrictions UR WITH(NOLOCK) ON M.CostCenterID=UR.CostCenterID and M.NodeID=UR.NodeID AND ParentCostCenterID='+CONVERT(NVARCHAR(10),@CostCenterID)+' AND UR.'+@RestrictionWhere+')'                
          +' AND A.NodeID NOT IN(SELECT NodeID FROM ADM_UserRoleRestrictions WITH(NOLOCK) WHERE CostCenterID='+CONVERT(NVARCHAR(10),@CostCenterID)+' AND '+@RestrictionWhere+')'                
                 
    IF @Where IS NOT NULL AND LTRIM(RTRIM(@WHERE))<>'' AND @CostCenterID!=41 AND @CostCenterID!=8                   
     SET @Where=@Where+' AND '+@RestrictionWhere                 
    ELSE IF @CostCenterID!=41                   
     SET @Where=@RestrictionWhere                 
   END                
   
    --Hide InActive Dimensions
    Declare @Dimensions nvarchar(max),@RestrictionDimWhere nvarchar(max)
    Declare  @TblHideDimList TABLE (iUserID int)  
    set @Dimensions=''
    set @RestrictionDimWhere=''
	select @Dimensions=isnull(value,'') from ADM_GLOBALPREFERENCES WITH(NOLOCK) where Name='HideInactiveDimensions'  
	if(isnull(@Dimensions,'')<>'')
	begin
		INSERT INTO @TblHideDimList    
			exec spsplitstring @Dimensions,','

		IF EXISTS(SELECT * FROM @TblHideDimList WHERE iUserID=@CostCenterID) and @userid!=1 
		BEGIN
			select @RestrictionDimWhere=StatusID from COM_Status WITH(NOLOCK) where CostCenterID=@CostCenterID and Status='In Active'	
			IF @WhereCondition IS NOT NULL AND @WhereCondition<>''
				SET @WhereCondition=@WhereCondition+' and '    
			if(@CostCenterID=93)
				set @WhereCondition=@WhereCondition+' a.status<>'+@RestrictionDimWhere
			else					
				set @WhereCondition=@WhereCondition+' a.statusid<>'+@RestrictionDimWhere
		END
	end
    --      
                
    IF @WhereCondition IS NOT NULL AND @WhereCondition<>''                
   begin   
                
    if @Where IS NOT NULL AND LTRIM(RTRIM(@WHERE))<>''                 
     SET @Where=@Where+' and ' + @WhereCondition                
    else                
     SET @Where= @WhereCondition                
   end                
           
if (@CostCenterID=92 and @IsUserWiseExists=1 and @userid!=1)      
begin
	if(@RoleID!=1 and ISNULL(@TFuserAssignedDims,'')<>'')
	begin
		SET  @Where=ltrim(rtrim(@Where))+' A.lft=1 OR  A.NODEID IN ( '
	end
	else
	begin
		if @Where IS NOT NULL AND LTRIM(RTRIM(@WHERE))<>'' 
            SET @Where=@Where+' and '  
		SET  @Where=ltrim(rtrim(@Where))+' A.lft=1 OR  A.NODEID IN (SELECT PROPERTYID FROM ADM_PROPERTYUSERROLEMAP PropertyUserRoleMap with(nolock) WHERE PropertyUserRoleMap.USERID in ('+convert(nvarchar,@UserID)+') OR 
		PropertyUserRoleMap.ROLEID='+convert(nvarchar,@RoleID)+') '   
	end
end  
else if (@CostCenterID=95 and @userid!=1)
begin
	set @PREFSALES=''
	select @PREFSALES=Value from  [COM_CostCenterPreferences] with(nolock) where  [CostCenterID]=95 and [Name]='DisplayBasedAssignment'
	if(@PREFSALES is not null and @PREFSALES='true')
	BEGIN
		 if @Where IS NOT NULL AND LTRIM(RTRIM(@WHERE))<>'' 
            SET @Where=@Where+' and '        
		SET  @Where=ltrim(rtrim(@Where))+'  ( A.lft=1 OR  A.PROPERTYID IN (SELECT PROPERTYID FROM ADM_PROPERTYUSERROLEMAP PropertyUserRoleMap with(nolock) WHERE PropertyUserRoleMap.USERID in ('+convert(nvarchar,@UserID)+') OR 
		PropertyUserRoleMap.ROLEID='+convert(nvarchar,@RoleID)+') )'   
	END
	else if(@IsUserWiseExists=1) 
	BEGIN
		if @Where IS NOT NULL AND LTRIM(RTRIM(@WHERE))<>'' 
            SET @Where=@Where+' and '        
     
		SET  @Where=ltrim(rtrim(@Where)) + ' ( A.lft=1 OR  (a.Createdby in (SELECT USERNAME FROM ADM_USERS WITH(NOLOCK) WHERE USERID in
	(select nodeid from dbo.COM_CostCenterCostCenterMap with(nolock) where 
	  Parentcostcenterid=7 and costcenterid=7 and ParentNodeid='+CONVERT(NVARCHAR(40),@UserID)+') or 
	 userid = '+CONVERT(NVARCHAR(40),@UserID)+')))'    
	                 
	END  
 
end  
  
	if(@DivisionWhere is not null and @DivisionWhere<>'')              
	begin              
		if(@CostCenterID=50001 or @CostCenterID=2 or @CostCenterID=3 or @CostCenterID=6 or @CostCenterID=94)              
		begin              
			if @Where IS NOT NULL AND LTRIM(RTRIM(@WHERE))<>''                 
				SET @Where=@Where+' and '               
			else                
				SET @Where= ''               
		end               
		
		if(@CostCenterID=50001)              
			set @Where=@Where+' ('+@Pcol+' in ('+@DivisionWhere+'))   '              
		else if(@CostCenterID=2 or @CostCenterID=3 or @CostCenterID=94)              
			set @Where=@Where+' (A.IsGroup=1 or '+@Pcol+' in (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock)
			where ParentCostCenterID = '+convert(nvarchar,@CostCenterID)+' and CostCenterID=50001 and (NodeID in ('+@DivisionWhere+' ))))   '
		else if(@CostCenterID=6)              
			set @Where=@Where+' ('+@Pcol+' in (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock)
			where ParentCostCenterID = '+convert(nvarchar,@CostCenterID)+' and CostCenterID=50001 and (NodeID in ('+@DivisionWhere+' ))))   ' 
		
		IF(@CostCenterID=16)
		begin 
			IF(@Where IS NOT NULL AND @Where <>'')    
				set @Where=@Where+ '  AND  a.batchid in (select batchid from INV_DocDetails  bd with(nolock)
				join com_docccdata d with(nolock) on d.invdocdetailsid=bd.invdocdetailsid    
				WHERE   d.dcccnid1 IN ('+@DivisionWhere+') )'      
			ELSE
			begin     
				set @Where= ' a.batchid in (select batchid from INV_DocDetails  bd with(nolock) 
				join com_docccdata d with(nolock) on d.invdocdetailsid=bd.invdocdetailsid    
				WHERE   d.dcccnid1 IN ('+@DivisionWhere+') )'      
			end 
		end  
		else IF(@CostCenterID=72)
		begin 
			set @STRJOIN=@STRJOIN+ '  left join com_ccccdata d with(nolock) on d.nodeid='+@Pcol+' and d.costcenterid=72 '

			if(@Where<>'')
				set @Where =@Where+' and d.ccnid1 in ('+@DivisionWhere+')'
			else 
				set @Where =	'  d.ccnid1 in ('+@DivisionWhere+')'
		end
		ELSE if @CostCenterID=101
		BEGIN    
		IF @DivisionWhere IS NOT NULL AND @DivisionWhere<>''              
		BEGIN       
			if(@Where IS NOT NULL AND @Where <>'')    
				set @Where=@Where+ '  AND'   
			else
				set @Where=''   
			set @Where=@Where+ ' A.BudgetDefID IN (select BudgetDefID from COM_BudgetAlloc with(nolock) where CCNID1 IN ('+@DivisionWhere+'))'
		END
	END 
	    
	end              
	if(@LocationWhere is not null and @LocationWhere<>'')              
	begin
		if(@CostCenterID=50002 or @CostCenterID=2 or @CostCenterID=3 or @CostCenterID=6 or @CostCenterID=94 or @CostCenterID>50000 )              
		begin              
			if @Where IS NOT NULL AND LTRIM(RTRIM(@WHERE))<>''                 
				SET @Where=@Where+' and '               
			else                
				SET @Where= ''               
		end   
           
		IF(@CostCenterID=16)
		begin 
			IF(@Where IS NOT NULL AND @Where <>'')    
				set @Where=@Where+ '  AND  a.batchid in (select batchid from INV_DocDetails  bd  with(nolock)
				join com_docccdata d with(nolock) on d.invdocdetailsid=bd.invdocdetailsid    
				WHERE   d.dcccnid2 IN ('+@LocationWhere+') )'      
			ELSE
			begin     
				set @Where= ' a.batchid in (select batchid from INV_DocDetails  bd  with(nolock)
				join com_docccdata d with(nolock) on d.invdocdetailsid=bd.invdocdetailsid    
				WHERE   d.dcccnid2 IN ('+@LocationWhere+') )'      
			end
		end  
		
		if(@CostCenterID=50002)              
			set @Where=@Where+' ('+@Pcol+' in ('+@LocationWhere+'))   '              
		else if(@CostCenterID=2 or @CostCenterID=3 or @CostCenterID=6 or @CostCenterID=94 or @CostCenterID>50000)
		begin
			if((@CostCenterID>50000 and not exists(select value from ADM_GlobalPreferences with(nolock) where Name='LocationWiseDimensionGroups' and value like '%'+CONVERT(NVARCHAR,@CostCenterID)+'%'))
			or (@CostCenterID=2 and not exists(select value from ADM_GlobalPreferences with(nolock) where Name='LWAccountGroups' and value='True'))
			or (@CostCenterID=3 and not exists(select value from ADM_GlobalPreferences with(nolock) where Name='LWProductGroups' and value='True')))
			begin
				if(@CostCenterID>50000 and @RoleID!=1 and ISNULL(@TFuserAssignedDims,'')<>'')
				begin
					set @TFJoinCond=@TFJoinCond+'  JOIN  COM_CCCCData CCMP with(nolock) on CCMP.NodeID=CMI.NodeID and  CCMP.CostCenterID ='+convert(varchar,@CostCenterID) +' 
					and (CCMP.CCNID2 in ('+@LocationWhere+' ))'	
				end
				else
				begin	
					set @Where=@Where+' (A.IsGroup=1 or '+@Pcol+' in (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock)
					where ParentCostCenterID = '+convert(nvarchar,@CostCenterID)+' and CostCenterID=50002 and (NodeID in ('+@LocationWhere+' ))))'   
				end
			end   
			else
				if(@CostCenterID=94 and @RoleID!=1 and ISNULL(@TFuserAssignedDims,'')<>'')
				begin					
					set @Where=@Where+'  JOIN  COM_CCCCData CCMP with(nolock) on CCMP.NodeID=B.TenantID and  CCMP.CostCenterID =94  
					  and (CCMP.CCNID2 in ('+@LocationWhere+' ))'				
				end
				else
				begin
					set @Where=@Where+' ('+@Pcol+' in (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock)
					where ParentCostCenterID = '+convert(nvarchar,@CostCenterID)+' and CostCenterID=50002 and (NodeID in ('+@LocationWhere+' ))))'
				end
		end
		ELSE if(@CostCenterID = 92 OR @CostCenterID = 93 OR @CostCenterID = 95 OR @CostCenterID = 103 OR @CostCenterID = 104 OR @CostCenterID = 129)    
		BEGIN    
			IF @LocationWhere IS NOT NULL AND @LocationWhere<>''              
			BEGIN       
				IF(@Where IS NOT NULL AND @Where <>'')
				BEGIN 
					 IF (@CostCenterID = 92)  
					 BEGIN
							if(@RoleID!=1 and ISNULL(@TFuserAssignedDims,'')<>'')
							begin
								set @Where=@Where+' select B.NodeID from  REN_Property B WITH(NOLOCK)    JOIN  COM_CostCenterCostCenterMap CCMU with(nolock) on CCMU.ParentCostCenterID = 7 and CCMU.ParentNodeID='+convert(nvarchar,@userid)+'  JOIN  COM_CCCCData CCMP with(nolock) on CCMP.NodeID=B.NodeID and  CCMP.CostCenterID = 92  
								 and (CCMP.CCNID2 in ('+@LocationWhere+' ))'
							end
							else
							begin
								set @Where=@Where+ '  AND (a.LocationID IN ('+@LocationWhere+') 
								OR A.NodeID IN (SELECT DISTINCT PropertyID FROM ADM_PropertyUserRoleMap WITH(NOLOCK) WHERE LocationID IN ('+@LocationWhere+'))) '  
							end
					 END
					 ELSE 
						set @Where=@Where+ '  AND a.LocationID IN ('+@LocationWhere+') '	    
				END
				ELSE  
				BEGIN  
					  IF (@CostCenterID = 92) 
					  BEGIN
							if(@RoleID!=1 and ISNULL(@TFuserAssignedDims,'')<>'')
							begin
								 set @Where=@Where+' select B.NodeID from  REN_Property B WITH(NOLOCK)    JOIN  COM_CostCenterCostCenterMap CCMU with(nolock) on CCMU.ParentCostCenterID = 7 and CCMU.ParentNodeID='+convert(nvarchar,@userid)+'  JOIN  COM_CCCCData CCMP with(nolock) on CCMP.NodeID=B.NodeID and  CCMP.CostCenterID = 92  
								 and (CCMP.CCNID2 in ('+@LocationWhere+' ))'
							end
							else
							begin
								set @Where=@Where+ ' (a.LocationID IN ('+@LocationWhere+') 
								OR A.NodeID IN (SELECT DISTINCT PropertyID FROM ADM_PropertyUserRoleMap WITH(NOLOCK) WHERE LocationID IN ('+@LocationWhere+'))) '      
							end
					 END
					 ELSE 
						set @Where=@Where+ ' a.LocationID IN ('+@LocationWhere+') '
				END
			END
		END
		ELSE if(@CostCenterID = 76 or @CostCenterID=72)
		BEGIN    
			IF @LocationWhere IS NOT NULL AND @LocationWhere<>''              
			BEGIN       
				if(@Where IS NOT NULL AND @Where <>'')    
					set @Where=@Where+ '  AND'      
				set @Where=@Where+ ' (a.IsGroup=1 or a.LocationID IN ('+@LocationWhere+')) '
			END
		END     
		ELSE if @CostCenterID=101
		BEGIN    
			IF @LocationWhere IS NOT NULL AND @LocationWhere<>''              
			BEGIN       
				if(@Where IS NOT NULL AND @Where <>'')    
					set @Where=@Where+ '  AND'   
				else
					set @Where=''   
				set @Where=@Where+ ' A.BudgetDefID IN (select BudgetDefID from COM_BudgetAlloc with(nolock) where CCNID2 IN ('+@LocationWhere+'))'
			END
		END   	  
	end    
	
	if(isnull(@Where,'')<>'' and @RoleID!=1 and ISNULL(@TFuserAssignedDims,'')<>'' and (@CostCenterID=92 or @CostCenterID=93 or @CostCenterID=94) )              
	begin
		DECLARE @WHR NVARCHAR(MAX)
		SET @WHR=''
		if(@CostCenterID=94)
		begin
			SET @WHR=' ('+@Pcol+' in ( select B.TenantID from  REN_Tenant B WITH(NOLOCK)  '
			set @Where=@WHR + @TFJoinCond +  @Where  +'))'
		end
		else if(@CostCenterID=92)
		begin
			set @Where=@Where +@TFJoinCond  +')'
		end
	end
		
	if(@RoleID!=1 and (@TFDIm>50000 or @TFDIm=94) and @TfUAD=1)
	BEGIN
		
		if @Where IS NOT NULL AND LTRIM(RTRIM(@WHERE))<>''                 
			SET @Where=@Where+' and '               
		else                
			SET @Where= '' 
					
		select @userAssignedDims=dbo.fnCom_GetAssignedNodesForUser(@TFDIm,@UserID,@RoleID)
		
		set @Where=@Where+' ('+@Pcol+' in (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock)
		where ParentCostCenterID = '+convert(nvarchar,@CostCenterID)+' and CostCenterID='+convert(nvarchar(max),@TFDIm)+' and (NodeID in ('+@userAssignedDims+' ))))'      
		
	END
	
		
	if(@UserID!=1 and @isproj=1)
	BEGIN
		 set @STRJOIN=@STRJOIN+'
		 join (select DCM.DcccNID'+convert(nvarchar,(@CostCenterID-50000))+' PID,INVE.RefID,INVE.TYPE RefType from COM_DoCCCData DCM WITH(NOLOCK) 
		 JOIN Inv_docdetails INV WITH(NOLOCK) ON DCM.InvdocdetailsID=INV.InvdocdetailsID
		 JOIN Inv_docextradetails INVE WITH(NOLOCK) ON INVE.InvdocdetailsID=INV.InvdocdetailsID
		 where inv.Documenttype=45 and INVE.TYPE in(6,7,8) and
		 ((RefID='+convert(nvarchar,@UserID)+' and INVE.TYPE=8)  
				OR (RefID='+convert(nvarchar,@RoleID)+' and INVE.TYPE=7)     
				or (INVE.TYPE=6 and RefID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID='+convert(nvarchar,@UserID)+' or G.RoleID='+convert(nvarchar,@RoleID)+')))
		 ) as t on PID=A.NodeID '
		
	END	 
	
	IF (@IsUserWiseExists=1 AND @UserID!=1)
	BEGIN
		if(@CostCenterID=2 or @CostCenterID=3 or @CostCenterID>50000) 
		BEGIN
			SET @MAPSQL='DECLARE @MAPTAB TABLE (ID INT,ParentID INT,LFT INT,RGT INT)
INSERT INTO @MAPTAB
SELECT C'+@Pcol+',CA.ParentID,CA.LFT,CA.RGT FROM '+@TableName+' A WITH(NOLOCK)
JOIN '+@TableName+' CA WITH(NOLOCK) ON CA.LFT BETWEEN A.LFT AND A.RGT
JOIN ( 
SELECT CCMU.ParentNodeID ID FROM COM_CostCenterCostCenterMap CCMU with(nolock) WHERE CCMU.ParentCostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' and CCMU.CostCenterID=7 and CCMU.NodeID='+CONVERT(NVARCHAR,@UserID)+'
UNION
SELECT CCMU.NodeID FROM COM_CostCenterCostCenterMap CCMU with(nolock) WHERE CCMU.ParentCostCenterID=7 and CCMU.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' and CCMU.ParentNodeID='+CONVERT(NVARCHAR,@UserID)+') AS T ON T.ID='+@Pcol+'
WHERE 1=1 '+@MAPSQL+'
INSERT INTO @MAPTAB
SELECT '+@Pcol+',A.ParentID,A.LFT,A.RGT FROM '+@TableName+' A WITH(NOLOCK)
JOIN @MAPTAB T ON '+@Pcol+'=T.ParentID
WHERE A.ISGROUP=1 AND A.LFT<T.LFT AND A.RGT>T.RGT
'		
		END
	END
	ELSE
		SET @MAPSQL=''
		
    --ADIL
	IF @Where IS NOT NULL AND LTRIM(RTRIM(@WHERE))<>''              
	BEGIN        

		if(@CostCenterID in(95,103,129,104))
		begin          
			SET @Where=' where A.COSTCENTERID = '+  convert(nvarchar,@CostCenterID ) +' AND (('+@Where+') or A.ParentID=0)  and a.lft>'+convert(nvarchar,@lft) 
			IF(@CostCenterID in(103,129))
				SET @Where=@Where+' AND A.StatusID<>430'
		end     
		else IF @CostCenterID=65 --Added by pranathi to apply filter based for contacts  
			SET @Where=' WHERE ('+@Where+')  '   
		else IF @CostCenterID=7        
		begin
			SET @Where=' WHERE ('+@Where+')  '                
			if(@IsUserWiseExists=1 and @userid!=1)   
			BEGIN 
				SET @Where=@Where+ ' and (A.UserID in (select nodeid from COM_CostCenterCostCenterMap with(nolock) where parentcostcenterid=7 and costcenterid=7 and parentnodeid='+  convert(nvarchar,@UserID ) +')
			OR A.UserID in (select parentnodeid from COM_CostCenterCostCenterMap with(nolock) where parentcostcenterid=7 and costcenterid=7 and nodeid='+  convert(nvarchar,@UserID ) +'))'
			END
		end
		ELSE IF @CostCenterID=6               
			SET @Where=' WHERE ('+@Where+') AND A.IsRoleDeleted <> 1 '           
		ELSE IF (@GridViewID=276)              
			SET  @Where=' WHERE ('+@Where+') AND a.ActualDeliveryDateTime is  NULL '     
		ELSE IF (@GridViewID=277)              
			SET  @Where=' WHERE ('+@Where+') AND a.DeliveryDateTime < Getdate() '        
		ELSE IF(@CostCenterID=2 or @CostCenterID=3 or @CostCenterID=72  or @CostCenterID>50000 )     
		BEGIN          
	 
			SET @Where=' WHERE (('+@Where+') or A.ParentID=0) '
	   
			if(@direction=2)
				set @Where+=' and a.lft<'+convert(nvarchar,@lft)
			else
				set @Where+=' and a.lft>'+convert(nvarchar,@lft)
			     
			IF (@IsUserWiseExists=1 AND @UserID!=1)
			BEGIN
				if(@CostCenterID>50000 and @RoleID!=1 and ISNULL(@TFuserAssignedDims,'')<>'')
				begin
					set @STRJOIN=@STRJOIN+'	JOIN  COM_CostCenterCostCenterMap CCMUU with(nolock) on CCMUU.ParentCostCenterID = 7 and CCMUU.ParentNodeID='+convert(nvarchar,@userid)+''
					set @STRJOIN=@STRJOIN+'	left JOIN (select CMI.NodeID,CMI.lft,CMI.rgt from '+@TableName+' CMI with(nolock) '
					set @STRJOIN=@STRJOIN+' JOIN COM_CostCenterCostCenterMap CCMU with(nolock) on CCMU.ParentCostCenterID IN (7) and CCMU.ParentNodeID='+convert(nvarchar,@userid)+''
					set @STRJOIN=@STRJOIN+@TFJoinCond					
					set @STRJOIN=@STRJOIN+' ) as CMI ON a.lft between CMI.lft and CMI.rgt'
					set @Where=@Where+' and (a.lft=1 or CMI.lft is not null or A.NodeID =CCMUU.ParentNodeID)'
				end
				else if(@CostCenterID=2 or @CostCenterID=3 or @CostCenterID>50000)   --IF IT IS USERWISE TRUE THEN ONLY ADD THE CONDITION  
				begin
					declare @PrefValue nvarchar(20)
					set @PrefValue =''
					select @PrefValue=value from adm_globalpreferences with(nolock) where name='ExcludeUnMapped'
					if (@PrefValue<>'true' or (@PrefValue='true'
						and exists(select CostCenterID from COM_CostCenterCostCenterMap WITH(NOLOCK) where CostCenterID=7 and NodeID=@userid and ParentCostCenterID=@CostCenterID)))
					begin	 
						SET  @Where=@Where + ' and ( a.lft=1 or '+@Pcol+' IN (SELECT DISTINCT ID FROM @MAPTAB) or (a.Createdby in (SELECT USERNAME FROM ADM_USERS WITH(NOLOCK)WHERE USERID in (select nodeid from dbo.COM_CostCenterCostCenterMap with(nolock) 
where Parentcostcenterid=7 and costcenterid=7 and ParentNodeid='+CONVERT(NVARCHAR,@UserID)+') or userid='+CONVERT(NVARCHAR,@UserID)+')))'    
					end
				end 
			 END
		END    
		ELSE IF @CostCenterID not in (8,31,41,43,113,143) and @GridViewID not in (143,144,163,173,198,279)
			SET @Where=' WHERE (('+RTRIM(@Where)+') or A.ParentID=0)'  
		else if @CostCenterID=143 AND @GridViewID<>163 and @GridViewID<>173   
			SET @Where=' WHERE ('+@Where+' AND sv.parentID=0)'      
		ELSE     
			SET @Where=' WHERE '+@Where        
	END              
	ELSE
	BEGIN   
		   
		if(@CostCenterID=7 and @IsUserWiseExists=1 and @userid!=1)   
		begin 
			SET @Where= ' where (A.UserID ='+  convert(nvarchar,@UserID ) +' or a.userid in (select nodeid from 
			COM_CostCenterCostCenterMap with(nolock) where parentcostcenterid=7 and costcenterid=7 and parentnodeid='+  convert(nvarchar,@UserID ) +'))'
		end
		else if(@CostCenterID=2 or @CostCenterID=3 or @CostCenterID=72 OR @CostCenterID=93 OR @CostCenterID=94 or @CostCenterID>50000 )              
		begin  
			if(@direction=2)
				set @Where=' where a.lft<'+convert(nvarchar,@lft)
			else
				set @Where=' where a.lft>'+convert(nvarchar,@lft)
			
			IF (@IsUserWiseExists=1  AND @UserID!=1)
			BEGIN
				
				if(@CostCenterID>50000 and @RoleID!=1 and ISNULL(@TFuserAssignedDims,'')<>'')
				begin
					set @STRJOIN=@STRJOIN+'	JOIN  COM_CostCenterCostCenterMap CCMUU with(nolock) on CCMUU.ParentCostCenterID=7 and CCMUU.ParentNodeID='+convert(nvarchar,@userid)+''
					set @STRJOIN=@STRJOIN+'	left JOIN (select CMI.NodeID,CMI.lft,CMI.rgt from '+@TableName+' CMI with(nolock) '
					set @STRJOIN=@STRJOIN+' JOIN COM_CostCenterCostCenterMap CCMU with(nolock) on CCMU.ParentCostCenterID=7 and CCMU.ParentNodeID='+convert(nvarchar,@userid)+''
					set @STRJOIN=@STRJOIN+@TFJoinCond					
					set @STRJOIN=@STRJOIN+' ) as CMI ON a.lft between CMI.lft and CMI.rgt'
					set @Where=@Where+' and (a.lft=1 or CMI.lft is not null or A.CreatedBy=(SELECT USERNAME FROM ADM_USERS WITH(NOLOCK) WHERE USERID='+CONVERT(NVARCHAR(40),@UserID)+') or A.NodeID =CCMUU.ParentNodeID)'
				end
				else if(@CostCenterID=2 or @CostCenterID=3 or @CostCenterID>50000) 
				BEGIN 
					SET  @Where=@Where + ' and ( a.lft=1 or '+@Pcol+' IN (SELECT DISTINCT ID FROM @MAPTAB) or (a.Createdby in (SELECT USERNAME FROM ADM_USERS WITH(NOLOCK)WHERE USERID in (select nodeid from dbo.COM_CostCenterCostCenterMap with(nolock) 
where Parentcostcenterid=7 and costcenterid=7 and ParentNodeid='+CONVERT(NVARCHAR,@UserID)+') or userid='+CONVERT(NVARCHAR,@UserID)+')))'    	
				END
			 END  
		end       
		else if(@CostCenterID in(95,103,129,104))              
		begin             
			SET @Where=' where A.COSTCENTERID = '+  convert(nvarchar,@CostCenterID ) +' and a.lft>'+convert(nvarchar,@lft)
		end
		else if(@CostCenterID in(86,88,89))              
		begin             
			if(@direction=2)
				set @Where=' where a.lft<'+convert(nvarchar,@lft)
			else
				set @Where=' where a.lft>'+convert(nvarchar,@lft)
		end
		else        
			SET @Where=''                
	END      
	
	if(@CostCenterID=93)              
	begin                 
		SET @SQL=' select top '+convert(nvarchar,@PageSize)+' A.lft'+@strColumns+',A.Status as StatusID,A.Depth,A.IsGroup,A.ParentID,'+@Primarycol+@STRJOIN+@Where+' AND A.UnitID>0 order by  a.lft '          
	end          
	else  if(@CostCenterID=94)              
	begin                 
		SET @SQL=' select top '+convert(nvarchar,@PageSize)+' A.lft'+@strColumns+',IsNull(A.StatusID,0) StatusID, A.Depth,A.IsGroup,A.ParentID,'+@Primarycol+@STRJOIN+@Where+' order by  a.lft '               
	end     
	ELSE IF(@CostCenterID=269)
		SET @SQL=' select top '+convert(nvarchar,@PageSize)+' 0 '+@strColumns+',A.MapID '+@STRJOIN+@Where+'  '          
	else  if(@CostCenterID in(95,103,129,104))            
	begin  
		if(@GridViewID=310)
		BEGIN
			SET @SQL=' select distinct top '+convert(nvarchar,@PageSize)+' A.lft'+@strColumns+','+(case when @CostCenterID in(103,129) then 'a.sno' else 'case when A.RefNo is not null and A.RefNo>0 then A.RefNo else a.sno  end' end)+' as StatusID, A.Depth,A.IsGroup,A.ParentID,'+@Primarycol+@STRJOIN
			+' left join ren_contract CU on CU.RefContractID=A.ContractID
			    join(select UnitID,max(EndDate) EndDate from
				(select C.UnitID,max(C.EndDate) EndDate from ren_contract C with(nolock)
				left join ren_contract CU with(nolock) on CU.RefContractID=C.ContractID
				where CU.ContractID is null
				group by C.UnitID
				union all
				select CU.UnitID,max(C.EndDate) EndDate from ren_contract C with(nolock)
				inner join ren_contract CU with(nolock) on CU.RefContractID=C.ContractID
				group by CU.UnitID) as t
				group by UnitID
				) T6 ON (CU.UnitID is not null and T6.UnitID=CU.UnitID and T6.EndDate=A.EndDate)
				or (T6.UnitID=A.UnitID and T6.EndDate=A.EndDate)'
			+@Where+' and (a.StatusID=426 or a.StatusID=427) order by  StatusID desc'               
		END
		ELSE if(@GridViewID=321)
		BEGIN
			SET @SQL=' select distinct top '+convert(nvarchar,@PageSize)+' A.lft'+@strColumns+','+(case when @CostCenterID in(103,129) then 'a.sno' else 'case when A.RefNo is not null and A.RefNo>0 then A.RefNo else a.sno  end ' end)+' as  StatusID, A.Depth,A.IsGroup,A.ParentID,'+@Primarycol+@STRJOIN
			+' LEFT join Acc_docDetails AccDOc with(nolock) on a.ContractID=AccDOc.refnodeid and AccDOc.RefCCID=95 and AccDOc.StatusID=371 '
			+@Where+' order by  StatusID desc'         
		END
		ELSE if(@CostCenterID=95)
			SET @SQL=' select distinct top '+convert(nvarchar,@PageSize)+' A.lft'+@strColumns+',case when A.RefNo is not null and A.RefNo>0 then A.RefNo else a.sno  end as  StatusID, A.Depth,A.IsGroup,A.ParentID,'+@Primarycol+@STRJOIN+@Where+' order by  StatusID desc'     		
		ELSE
			SET @SQL=' select distinct top '+convert(nvarchar,@PageSize)+' A.lft'+@strColumns+','+(case when @CostCenterID in(103,129) then 'a.sno' else 'case when A.RefNo is not null and A.RefNo>0 then A.RefNo else a.sno  end' end)+' AS StatusID, A.Depth,A.IsGroup,A.ParentID,'+@Primarycol+@STRJOIN+@Where+' order by  StatusID desc'     
		         
	end      
	else if(@CostCenterID<>65)           
	begin 

		if(@CostCenterID=16)
		BEGIN 
			if(@Where is not null and @Where!='')
				set @Where=@Where+' and  A.lft>'+convert(nvarchar,@lft)+' '
			else
				set @Where=' where A.lft>'+convert(nvarchar,@lft)+' '
		END
		IF(@CostCenterID=113)
			SET @SQL=' select row_number() over (order by A.StatusID) rowno'+@strColumns+',A.StatusID,0 Depth,0 IsGroup,0 ParentID,0 TypeID, '+@Primarycol+@STRJOIN+@Where+'  '             
		else IF(@CostCenterID=502)
			SET @SQL=' select row_number() over (order by A.AccountTypeID) rowno'+@strColumns+',A.AccountTypeID,0 Depth,0 IsGroup,0 ParentID,0 TypeID,A.AccountTypeID NodeID '+@STRJOIN+@Where+'  '
		else IF(@CostCenterID=503)
			SET @SQL=' select row_number() over (order by A.ProductTypeID) rowno'+@strColumns+',A.ProductTypeID,0 Depth,0 IsGroup,0 ParentID,0 TypeID,A.ProductTypeID NodeID '+@STRJOIN+@Where+'  '              
		ELSE
		begin
			
			if(@direction>0)
				set @strColumns=@strColumns+',A.rgt'
			
			SET @SQL='select distinct top '+convert(nvarchar,@PageSize)+'A.lft'+@strColumns+',A.StatusID,A.IsGroup,A.ParentID,'+@Primarycol
			
			IF(@Depth IS NOT NULL AND @Depth<>'')
				SET @SQL=@SQL+@Depth
			ELSE
				SET @SQL=@SQL+',A.Depth '
			
			if (@CostCenterID >50000 AND @UserID!=1 AND (@isproj=1 or (@IsGroupUserWiseExists=0 AND @IsUserWiseExists=1)))
				SET @SQL=REPLACE(@SQL,'A.','CG.')
			
			SET @SQL=@MAPSQL+' '+@SQL
			if(@CostCenterID=50051)
			begin
				SET @SQL=@SQL+',CONVERT(DATETIME,A.DORelieve) as DORelieve '
			end
			
			SET @SQL=@SQL+@STRJOIN+@Where
			
			if(@CostCenterID=50052)
			begin
				Declare @LftID int,@RgtID int,@TaxComponentPref varchar(5),@SQL2 NVARCHAR(MAX)
				Select @TaxComponentPref=ISNULL(VALUE,'') from ADM_GlobalPreferences with(nolock) where Name='EnableIncomeTax'
				if(ISNULL(@TaxComponentPref,'')='False')
				begin
				SET @SQL2='Select @LftID=lft,@RgtID=rgt from COM_CC50052 with(nolock) where (Code=''INCOME TAX'' or Name=''INCOME TAX'')'
				EXEC sp_executesql @SQL2,N'@LftID INT OUTPUT,@RgtID INT OUTPUT',@LftID OUTPUT,@RgtID OUTPUT

					if(ISNULL(@LftID,0)>0)
						SET @SQL=@SQL+' and A.lft not between '''+ convert(nvarchar,@LftID) +''' and '''+ convert(nvarchar,@RgtID) +''''
				end
			end
			
			if (@CostCenterID >50000 AND @UserID!=1 AND (@isproj=1 or (@IsGroupUserWiseExists=0 AND @IsUserWiseExists=1)))
				SET @SQL=@SQL+' order by  CG.lft '
			else
				SET @SQL=@SQL+' order by  A.lft '
			
			if(@direction=2)
				SET @SQL=@SQL+'desc'
		end
	end       
  
                    
 if(@CostCenterID=90)              
 begin                   
      SET @SQL=' with rows as ( select row_number() over (order by A.lft) rowno'+@strColumns+',0 StatusID,A.Depth,A.IsGroup,A.ParentID,'+@Primarycol+@STRJOIN+@Where+               
     ' ) select * from rows WHERE nodeid>0 and (rowno>'+convert(varchar,@Position)+' and rowno<='+convert(varchar,@Position+@PageSize)+') Order By rowno Asc '                
 end          
 if(@CostCenterID=74)              
 begin              
     SET @SQL=' with rows as ( select row_number() over (order by A.AssetClassid) rowno'+@strColumns+', A.StatusID,0 Depth, 0 IsGroup,0 ParentID,  0 lft, 0 rgt  '+@Primarycol+@STRJOIN+              
     ' ) select * from rows WHERE nodeid>0 and (rowno>'+convert(varchar,@Position)+' and rowno<='+convert(varchar,@Position+@PageSize)+') Order By rowno Asc '                
 end              
 if(@CostCenterID=75)             
 begin              
     SET @SQL=' with rows as ( select row_number() over (order by A.DeprBookid) rowno'+@strColumns+', A.StatusID ,0 Depth, 0 IsGroup,0 ParentID, 0 lft, 0 rgt '+@Primarycol+@STRJOIN+              
     ' ) select * from rows WHERE nodeid>0 and (rowno>'+convert(varchar,@Position)+' and rowno<='+convert(varchar,@Position+@PageSize)+') Order By rowno Asc '                
 end              
 if(@CostCenterID=77)              
 begin              
     SET @SQL=' with rows as ( select row_number() over (order by A.PostingGroupID) rowno'+@strColumns+', A.StatusID ,0 Depth, 0 IsGroup,0 ParentID, 0 lft, 0 rgt '+@Primarycol+@STRJOIN+              
     ' ) select * from rows WHERE nodeid>0 and (rowno>'+convert(varchar,@Position)+' and rowno<='+convert(varchar,@Position+@PageSize)+') Order By rowno Asc '        
 end    
 	         
	 IF(@CostCenterID=7)                
	 BEGIN
		if @UserID!=1
		begin
			declare @RoleWhere nvarchar(max)
			set @RoleWhere=''
			if(@LocationWhere is not null and @LocationWhere!='')
				set @RoleWhere=' ROLE.RoleID!=1 and ROLE.RoleID IN (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock) where ParentCostCenterID=6 and CostCenterID=50002 and NodeID in ('+@LocationWhere+' ))'
			if(@DivisionWhere is not null and @DivisionWhere!='')
				set @RoleWhere=@RoleWhere+' and ROLE.RoleID!=1 and ROLE.RoleID IN (select ParentNodeID from COM_CostCenterCostCenterMap with(nolock) where ParentCostCenterID=6 and CostCenterID=50001 and NodeID in ('+@DivisionWhere+'))'
			if @RoleWhere!=''
			begin
				if @Where!=''
					set @Where=@Where+' and '+@RoleWhere
				else
					set @Where='WHERE '+@RoleWhere
			end
		end
		SET @SQL=' with rows as ( select row_number() over (order by ROLE.RoleType,A.UserName) lft'+@strColumns+',A.StatusID, 0 Depth, 0 IsGroup,0 ParentID,'+@Primarycol+@STRJOIN+@Where
		
		if @Where!=''
			set @SQL=@SQL+' and A.UserID=1'
		else
			set @SQL=@SQL+' WHERE A.UserID=1'
		
		SET @SQL=@SQL+' UNION select 1+row_number() over (order by ROLE.RoleType,A.UserName) lft'+@strColumns+',A.StatusID, 0 Depth, 0 IsGroup,0 ParentID,'+@Primarycol+@STRJOIN+@Where
		
		if @Where!=''
			set @SQL=@SQL+' and A.UserID<>1'
		else
			set @SQL=@SQL+' WHERE A.UserID<>1'
		
		SET @SQL=@SQL+' ) select * from rows WHERE nodeid>0 Order By lft Asc '               
	END              
	ELSE IF(@CostCenterID=6)
	BEGIN
		SET @SQL=' with rows as ( select row_number() over (order by A.Name) rowno'+@strColumns+',A.StatusID, 0 Depth, 0 IsGroup,0 ParentID,'+@Primarycol+@STRJOIN+@Where                
		
		if @Where!=''
			set @SQL=@SQL+' and A.RoleID=1'
		else
			set @SQL=@SQL+' WHERE A.RoleID=1'
	     
		SET @SQL=@SQL+' UNION select 1+row_number() over (order by A.Name) rowno'+@strColumns+',A.StatusID, 0 Depth, 0 IsGroup,0 ParentID,'+@Primarycol+@STRJOIN+@Where               
	    
		if @Where!=''
			set @SQL=@SQL+' and A.RoleID<>1'
		else
			set @SQL=@SQL+' WHERE A.RoleID<>1'
	     
		SET @SQL=@SQL+' ) select * from rows WHERE nodeid>0 and (rowno>'+convert(varchar,@Position)+' and rowno<='+convert(varchar,@Position+@PageSize)+') Order By rowno Asc '             
	END              
	ELSE IF(@CostCenterID=11)                
	BEGIN               
		SET @SQL=' with rows as ( select row_number() over (order by A.BaseID) rowno'+@strColumns+',0 StatusID, 0 Depth, 0 IsGroup,0 ParentID,'+@Primarycol+@STRJOIN+@Where+                
		' ) select * from rows WHERE nodeid>0 and (rowno>'+convert(varchar,@Position)+' and rowno<='+convert(varchar,@Position+@PageSize)+') Order By rowno Asc '               
	END                   
	ELSE IF(@CostCenterID=8)                                
		SET @SQL='  select row_number() over (order by A.FeatureID) rowno,A.SYSName,A.Name,0 as StatusID,0 as Depth,''FALSE'' as IsGroup,                
      0 as ParentID,A.FeatureID as NodeID,0 as TypeID                 
      FROM ADM_Features A WITH(NOLOCK) where A.FeatureID>=50000 AND A.FeatureID NOT BETWEEN 50051 AND 50057'                 
	ELSE IF(@CostCenterID=43)            
		SET @SQL='  select row_number() over (order by A.DocumentType) rowno'+@strColumns+',0 as StatusID,0 as Depth,''FALSE'' as IsGroup,0 as ParentID,A.DocumentTypeID as NodeID,0 as TypeID FROM '+@TableName+' A WITH(NOLOCK) '                                              
	ELSE IF(@CostCenterID=12)   
		SET @SQL='  select 0 lft'+@strColumns+',0 as StatusID,0 as Depth,''FALSE'' as IsGroup,0 as ParentID,A.CurrencyID as NodeID,0 as TypeID FROM '+@TableName+' A WITH(NOLOCK) '                                                
	ELSE IF(@GridViewID=198)                
	BEGIN
		if @Where is null or @Where=''
			set @Where=' where '
		else
			set @Where=@Where+' and '
		if(@RoleID=1 or @UserID=1)
			set @Where=@Where+'1=1'
		else
			set @Where=@Where+'i.CostCenterID IN(
		select FA.FeatureID
		from adm_featureactionrolemap FAR with(nolock)
		inner join adm_featureaction FA with(nolock) on FAR.FeatureActionID=FA.FeatureActionID
		where FAR.RoleID='+CONVERT(NVARCHAR,@RoleID)+' and (FA.FeatureActionTypeID=1 or FA.FeatureActionTypeID=2) and FA.FeatureID between 40000 and 50000
		)'
		SET @SQL=' select distinct i.CostCenterID rowno, i.DocumentName,i.DocumentAbbr,              
		 i.CostCenterID NodeID,0 as StatusID,0 as Depth,''false'' as IsGroup,0 as ParentID,DocumentType as TypeID                 
		 from ADM_DocumentTypes i with(nolock)'+@Where+' ORDER BY i.DocumentName'                 
	END           
	ELSE IF(@GridViewID=272)              
	BEGIN                
		select 'Estimate' as 'Ticket Type','1' as TypeID              
		union              
		select 'Work Order'as 'Ticket Type','2' as TypeID              
		union              
		select 'Invoice' as 'Ticket Type','3' as TypeID                    
	END          
	ELSE IF(@CostCenterID=71)              
	BEGIN              
		SET @SQL='Select row_number() over (order by A.ResourceID) rowno, A.ResourceCode,A.ResourceName,S.Status,A.StatusID,A.Depth,A.IsGroup,A.ParentID,A.ResourceTypeID AS TypeID,A.ResourceID as NodeID              
FROM  PRD_Resources A WITH(NOLOCK)               
left join COM_Status S with(nolock) on S.StatusID = A.StatusID WHERE ResourceTypeID=1'              
	END              
	ELSE IF (@CostCenterID=88)       
	BEGIN
		if(@Where is not null and @Where!='') 
			SET @SQL='  select top '+convert(nvarchar,@PageSize)+' A.lft '+@strColumns+',A.StatusID,A.Depth,A.IsGroup,A.ParentID,'+@Primarycol+@STRJOIN+@Where+              
			' and A.lft>'+CONVERT(nvarchar,@lft)   
		else
			SET @SQL=' select top '+convert(nvarchar,@PageSize)+' A.lft '+@strColumns+',A.StatusID,A.Depth,A.IsGroup,A.ParentID,'+@Primarycol+@STRJOIN+              
			' where A.lft>'+CONVERT(nvarchar,@lft)   
		
		SET   @SQL =@SQL + ' Order By A.lft '    
	END
	ELSE IF(@CostCenterID=86 OR @CostCenterID=89 OR @CostCenterID=73)              
	BEGIN              
		declare @DonotDisplayOwner bit=0
	
		declare @PK nvarchar(50)
		if(@CostCenterID=73)
			set @PK='A.CaseID'
		else if(@CostCenterID=86)
			set @PK='A.LeadID'
		else if(@CostCenterID=89)
			set @PK='A.OpportunityID'
		--ADDED CONDITION ON OCT 05 2012 BY HAFEEZ TO GET LOCATION WISE LEADS              
		if @LocationWhere IS NOT NULL AND @LocationWhere<>''              
		begin              
			SET @STRJOIN=@STRJOIN +  ' LEFT JOIN COM_CCCCData CC WITH(NOLOCK) ON CC.NODEID='+@PK+' AND CC.COSTCENTERID='+CONVERT(nvarchar,@CostCenterID)+' AND CC.CCNID2 IN ('+@LocationWhere+') '              
		end  
	    
		select @DonotDisplayOwner=convert(bit,Value) from com_costcenterpreferences with(nolock) where costcenterid=@CostCenterID and name='ShowOnlyAssigned'
	    
		SET @SQL=' DECLARE @TABLE TABLE(USERNAME NVARCHAR(300),USERID INT) 
			INSERT INTO @TABLE'
		if @DonotDisplayOwner=1
			SET @SQL=@SQL+' select UserName,UserID from adm_users with(nolock) where Userid='+convert(varchar,@UserID)
		else	
			SET @SQL=@SQL+' EXEC spCOM_GetUserHierarchy '+convert(varchar,@UserID)+','+convert(varchar,@CostCenterID)+','+convert(varchar,@LangID)
	    
		SET @SQL=@SQL+'    select distinct top '+convert(nvarchar,@PageSize)+' A.lft '+@strColumns+' ,A.StatusID,A.Depth,A.IsGroup,A.ParentID,'+@Primarycol+@STRJOIN+ @AttachUserWiseQuery       
		
		if(@Where is not null and @Where!='') 
			SET @SQL=@SQL+ ' ' + @Where+ ' and '
		else
			SET @SQL=@SQL +' where '
		
		if(@direction=2)
			set @SQL=@SQL+' A.lft<'+convert(nvarchar,@lft)
		else
			set @SQL=@SQL+' A.lft>'+convert(nvarchar,@lft) 
		
		set @DonotDisplayOwner=0
		select @DonotDisplayOwner=convert(bit,Value) from com_costcenterpreferences with(nolock) where costcenterid=@CostCenterID and name='DonotDisplayOwner'
		if @IsUserWiseExists=1 --IF IT IS USERWISE TRUE THEN ONLY ADD THE CONDITION    
		begin    
			if @DonotDisplayOwner=1
				set @SQL=@SQL  +' AND (A.lft=1 OR (('''+convert(varchar,@UserID)+'''=1 or (a.Createdby in (SELECT USERNAME FROM @TABLE)) OR TBL.LeadID Is not null))
				AND ((dbo.fnGet_GetAssignedListForFeatures('+convert(varchar,@CostCenterID)+','+@PK+')='''' AND A.CREATEDBY IN (SELECT USERNAME FROM @TABLE)) OR TBL.LeadID Is not null))  '
			ELSE
				set @SQL=@SQL  +' AND (A.lft=1 OR ('''+convert(varchar,@UserID)+'''=1 or (a.Createdby in (SELECT USERNAME FROM @TABLE)) OR TBL.LeadID Is not null))'
			if @LocationWhere IS NOT NULL AND @LocationWhere<>''              
				set @SQL =@SQL + ' OR   '+@PK+' in ( SELECT NODEID FROM COM_CCCCDATA with(nolock) WHERE COSTCENTERID='+convert(varchar,@CostCenterID)+' AND CCNID2 IN ('+@LocationWhere+')) '            
		end
		if(@direction=2)
			SET @SQL=@SQL+' order by  A.lft desc'
		else
			SET @SQL=@SQL+' order by  A.lft '
		--PRINT @SQL
	END            
	ELSE IF(@CostCenterID=65)--For Contacts            
	BEGIN            
		if(@Where<>'')
			set @Where= @Where+' and A.FirstName<>'''''
		else
			set @Where=' where A.FirstName<>'''''
    
		SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Lookup SLookup WITH(NOLOCK) ON (A.SalutationID=SLookup.NodeID)'    
		SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Lookup CLookup WITH(NOLOCK) ON (A.ContactTypeID=CLookup.NodeID)'    
		SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Lookup RLookup WITH(NOLOCK) ON (A.RoleLookupID=RLookup.NodeID) '    
		SET @STRJOIN=@STRJOIN+' LEFT JOIN CRM_Customer CRM_Customer WITH(NOLOCK) ON (A.FeatureID=83 and A.FeaturePK=CRM_Customer.CustomerID) '    
		SET @STRJOIN=@STRJOIN+' LEFT JOIN Acc_Accounts Acc_Accounts WITH(NOLOCK) ON (A.FeatureID=2 and A.FeaturePK=Acc_Accounts.AccountID) '    
		SET @STRJOIN=@STRJOIN+' LEFT JOIN COM_Lookup CTLookup WITH(NOLOCK) ON (A.Country=CTLookup.NodeID)'    
		SET @STRJOIN=@STRJOIN+' LEFT JOIN ADM_FEATURES FEATURES WITH(NOLOCK) ON (A.FeatureID=FEATURES.FeatureID)'    
		SET @SQL=' DECLARE @TABLE TABLE(USERNAME NVARCHAR(300),USERID INT) 
		INSERT INTO @TABLE
        EXEC spCOM_GetUserHierarchy '+convert(varchar,@UserID)+','+convert(varchar,@CostCenterID)+','+convert(varchar,@LangID)+'  select * from( select row_number() over (order by isnull(A.lft,0)) as rowno'+@strColumns+',1 StatusID,0 Depth,0 IsGroup,0 ParentID,            
		'+@Primarycol+@STRJOIN+@AttachUserWiseQuery+@Where      
      
	   IF @IsUserWiseExists=1 --IF IT IS USERWISE TRUE THEN ONLY ADD THE CONDITION    
	   BEGIN    
			SET @SQL=@SQL + ' and ('''+convert(varchar,@UserID)+'''=1 or (a.Createdby in (SELECT USERNAME FROM @TABLE))   OR  TBL.LeadID Is not null)                   
		 '           
	            
			IF @LocationWhere IS NOT NULL AND @LocationWhere<>''   
				SET @SQL =@SQL + ' OR   A.ContactID in ( SELECT NODEID FROM COM_CCCCDATA with(nolock) WHERE COSTCENTERID=65 AND CCNID2 IN ('+@LocationWhere+')) )'                          
			ELSE              
				SET   @SQL =@SQL + ' )    '    
	       
		END    
		ELSE     
			SET   @SQL =@SQL + ' ) '      
	         
		SET @SQL=@SQL+'  as t where    rowno>='+CONVERT(nvarchar,@Position)+' and rowno<='+CONVERT(nvarchar,(@Position+@PageSize))   + 'ORDER BY FirstName  '      
 
	END        
	ELSE IF(@CostCenterID=83) --FOR CRM CUSTOMER               
	BEGIN            
		IF @LocationWhere IS NOT NULL AND @LocationWhere<>''              
		BEGIN           
			if(@Where is not null and @Where!='')     
				SET @Where =@Where + ' and ( A.IsGroup=1 or   A.CustomerID in ( SELECT NODEID FROM COM_CCCCDATA with(nolock) WHERE COSTCENTERID=83 AND CCNID2 IN ('+@LocationWhere+'))  )'              
			else
				SET @Where ='where A.lft>'+CONVERT(nvarchar,@lft) +' and ( A.IsGroup=1 or A.CustomerID in ( SELECT NODEID FROM COM_CCCCDATA with(nolock) WHERE COSTCENTERID=83 AND CCNID2 IN ('+@LocationWhere+'))  )'              
		END  
       
		if(@Where is not null and @Where!='') 
			SET @SQL=' DECLARE @TABLE TABLE(USERNAME NVARCHAR(300),USERID INT) 
			INSERT INTO @TABLE
			EXEC spCOM_GetUserHierarchy '+convert(varchar,@UserID)+','+convert(varchar,@CostCenterID)+','+convert(varchar,@LangID)+'  select top '+convert(nvarchar,@PageSize)+' A.lft '+@strColumns+',A.StatusID,A.Depth,A.IsGroup,A.ParentID,'+@Primarycol+@STRJOIN+@AttachUserWiseQuery+@Where+              
			' and A.lft>'+CONVERT(nvarchar,@lft)    
		else         
		SET @SQL=' DECLARE @TABLE TABLE(USERNAME NVARCHAR(300),USERID INT) 
		INSERT INTO @TABLE
        EXEC spCOM_GetUserHierarchy '+convert(varchar,@UserID)+','+convert(varchar,@CostCenterID)+','+convert(varchar,@LangID)+'    select top '+convert(nvarchar,@PageSize)+' A.lft  '+@strColumns+',A.StatusID,A.Depth,A.IsGroup,A.ParentID,'+@Primarycol+@STRJOIN+@AttachUserWiseQuery+@Where+'    
		where A.lft>'+CONVERT(nvarchar,@lft)     
        
		IF @IsUserWiseExists=1 --IF IT IS USERWISE TRUE THEN ONLY ADD THE CONDITION    
		BEGIN    
			SET @SQL=@SQL +'     
			and (A.lft=1 or a.isgroup=1  OR  ('''+convert(varchar,@UserID)+'''=1 or (a.Createdby in  (SELECT USERNAME FROM @TABLE))   OR  TBL.LeadID Is not null)   )              
	   '             
		END    
              
		SET   @SQL =@SQL + ' Order By  A.lft'                          
	END     
	ELSE IF(@CostCenterID=100)              
	BEGIN              
		SET @SQL= '              
SELECT   row_number() over (order by G.nodeid) rowno,     G.NodeID, G.GroupName, 
CASE WHEN (G.UserID=0) THEN R.Name + ''-'' + ''Role''
WHEN G.RoleID=0 THEN U.UserName + ''-'' + ''User'' end AS Name, s.Status, G.StatusID,G.Depth,G.IsGroup, G.ParentID, 0 AS TypeID, 0 temp              
FROM COM_Groups AS G with(nolock) 
LEFT OUTER JOIN COM_Status AS s with(nolock) ON G.StatusID = s.StatusID 
LEFT JOIN aDM_PRoles AS R with(nolock) ON R.RoleID = G.RoleID              
LEFT JOIN ADM_Users AS U with(nolock) ON U.UserID = G.UserID   
 '              
	END
	ELSE IF(@CostCenterID=91)--For Team by Hafeez              
	BEGIN        
		SET @SQL= ' SELECT row_number() over (order by T.NodeID) rowno,Case when isGroup=1 then T.TeamName Else U.UserName End as TeamName,Case when isOwner=0 and isGroup=0 then ''Member'' when  isOwner=1 then ''Owner'' end As Role,COM_STATUS.Status [Status] 
, T.StatusID,Case when T.NodeID=1 then 0 when T.IsGroup=1 then 1 else 2 end as  Depth,T.IsGroup, T.ParentID, 0 AS TypeID,T.NodeID, 0 temp  FROM CRM_Teams T  with(nolock)               
 LEFT JOIN  COM_STATUS with(nolock) ON COM_STATUS.StatusID=T.StatusID              
  LEFT OUTER JOIN   ADM_Users AS U with(nolock) ON U.UserID = T.UserID                                  
'              
	END                 
	ELSE IF(@CostCenterID=84)--For SERVICECONTRACT by Hafeez              
	BEGIN         
		SET @SQL= '  select row_number() over (order by A.SvcContractID) rowno,A.DocID,S.ResourceData as Status,CT.CTemplName,CU.CustomerName,convert(nvarchar(12),Convert(datetime,A.Date),106) as Date,A.StatusID,A.Depth,A.IsGroup,A.ParentID,A.SvcContractID as       
 NodeID,0 as TypeID FROM CRM_ServiceContract A WITH(NOLOCK)  
JOIN COM_Status SS WITH(NOLOCK) ON A.StatusID=SS.StatusID                
LEFT JOIN COM_LanguageResources S WITH(NOLOCK) ON S.ResourceID=SS.ResourceID AND S.LanguageID=1              
LEFT JOIN CRM_ContractTemplate CT WITH(NOLOCK) ON CT.ContractTemplID=A.ContractTemplID               
LEFT JOIN CRM_Customer CU WITH(NOLOCK) ON CU.CustomerID=A.CustomerID                                   
'                     
	END                 
	ELSE IF(@CostCenterID=49)              
	BEGIN              
   
		set @SQL='DECLARE @UserID INT,@RoleID INT
SET @UserID='+CONVERT(NVARCHAR,@UserID)+'              
SELECT @RoleID='+CONVERT(NVARCHAR,@RoleID)+'

declare @Tbl as TABLE(ID INT)
insert into @Tbl
SELECT R.ID FROM ADM_Assign M with(nolock) inner join ADM_BulkEditTemplate R with(nolock) on R.ID=M.NodeID
WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
GROUP BY R.ID

select 0,''Bulk Edit'' TemplateName'    

		set @SQL=@SQL+',0 NodeID,1 IsGroup,-1 lft,0 rgt,0 Depth,0 ParentID,0 StatusID,0 TypeID,NULL GroupOrder    
UNION ALL    
select N.CostCenterID,N.Name TemplateName,N.ID NodeID,0 IsGroup,0 lft,0 rgt,2 Depth,0 ParentID,1 StatusID,0 TypeID,F.Name GroupOrder    
from ADM_BulkEditTemplate N with(nolock)
inner join ADM_Features F with(nolock) ON N.CostCenterID=F.FeatureID
where @UserID=1 or @RoleID=1 or N.ID IN (select ID FROM @Tbl)
UNION ALL    
select N.CostCenterID,F.Name,min(N.ID) NodeID,1 IsGroup,0 lft,0 rgt,1 Depth,0 ParentID,1 StatusID,0 TypeID,F.Name GroupOrder    
from ADM_BulkEditTemplate N with(nolock)
inner join ADM_Features F with(nolock) ON N.CostCenterID=F.FeatureID
where @UserID=1 or @RoleID=1 or N.ID IN (select ID FROM @Tbl)
group by CostCenterID,F.Name   
order by GroupOrder,IsGroup desc,TemplateName'             
    END       
	ELSE IF(@CostCenterID in(41,47,48))              
	BEGIN  
		if @CostCenterID=47     
			set @SQL='select 0,''Email'' TemplateName'    
		else if @CostCenterID=48    
			set @SQL='select 0,''SMS'' TemplateName'  
		else if @CostCenterID=41    
			set @SQL='select 0,''PushNotification'' TemplateName'  
				  
		set @SQL=@SQL+',NULL [To],NULL Subject,'''' Status, 0 NodeID,1 IsGroup,-1 lft,0 rgt,0 Depth,0 ParentID,0 StatusID,0 TypeID,NULL GroupOrder    
UNION ALL    
select N.CostCenterID,N.TemplateName,N.[To],N.Subject,s.status StatusID,N.TemplateID NodeID,0 IsGroup,0 lft,0 rgt,2 Depth,0 ParentID,N.StatusID,0 TypeID,F.Name GroupOrder    
from COM_NotifTemplate N with(nolock)
inner join com_status s  with(nolock) on n.statusid=s.statusid
inner join ADM_Features F with(nolock) ON N.CostCenterID=F.FeatureID AND '+@WhereCondition+'    
UNION ALL    
select N.CostCenterID,F.Name,  null,null,s.status  Status,min(TemplateID) NodeID,1 IsGroup,0 lft,0 rgt,1 Depth,0 ParentID,1 StatusID,0 TypeID,F.Name GroupOrder    
from COM_NotifTemplate N with(nolock)
inner join com_status s  with(nolock) on n.statusid=s.statusid
inner join ADM_Features F with(nolock) ON N.CostCenterID=F.FeatureID AND '+@WhereCondition+'    
group by N.CostCenterID,F.Name      ,N.statusid,s.status
order by GroupOrder,IsGroup desc,TemplateName'    
    
	END       
    ELSE IF(@CostCenterID=117)              
	BEGIN              
		SET @SQL= 'DECLARE @UserID INT,@RoleID INT ,@LangID INT             
SET @UserID='+CONVERT(NVARCHAR,@UserID)+'              
SELECT  @RoleID='+CONVERT(NVARCHAR,@RoleID)+'
SELECT  @LangID='+CONVERT(NVARCHAR,@LangID)+'
    
SELECT  Distinct ROW_NUMBER() over (order by max(lft)), 
case isnull(s.ResourceData,'''') when '''' then d.DashBoardName else s.ResourceData end DashBoardName
,D.DashBoardType, 1 StatusID, D.Depth, D.IsGroup,D.ParentID,  max(D.lft) lft,  max(D.rgt) rgt,0 TypeID ,D.DashBoardID as NodeID    
FROM  ADM_DashBoard D with(nolock)
LEFT JOIN COM_LanguageResources S  WITH(NOLOCK) ON S.ResourceName=D.DashBoardName AND S.LanguageID=@LangID 
where D.ParentID=0 or  (@RoleID=1 or D.createdby=@UserID  
or (D.DashBoardID IN ((SELECT DashBoardID FROM ADM_DashBoardUserRoleMap with(nolock) WHERE UserID=@UserID OR RoleID=@RoleID   
    or GroupID IN (SELECT G.GID FROM COM_Groups G with(nolock) WHERE G.UserID=@UserID or G.RoleID=@RoleID))
union
SELECT SR.DashBoardID FROM ADM_DashBoardUserRoleMap M with(nolock) 
inner join ADM_DashBoard D with(nolock) on D.DashBoardID=M.DashBoardID and D.IsGroup=1
inner join ADM_DashBoard SR with(nolock) on SR.lft between D.lft and D.rgt and SR.DashBoardID>0
WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
)))
group by D.DashBoardName, D.DashBoardType, D.depth,D.isgroup,D.parentid ,D.DashBoardID,s.ResourceData
ORDER BY LFT
    '
    PRINT (@SQL)
    END               
	ELSE IF(@CostCenterID=46)              
	BEGIN              
		SET @SQL= 'SELECT     1 AS rowno, N.WorkFlowNotifDefName, CASE WHEN ReportID > 0 THEN ''Reports'' ELSE ''Category'' END AS NotifType,               
CASE WHEN ReportID > 0 THEN              
(SELECT TOP 1 ReportName              
FROM ADM_RevenUReports  with(nolock)             
WHERE ReportID = N .ReportID) ELSE              
(SELECT TOP 1 Name              
FROM ADM_Features with(nolock)
WHERE FeatureID = N .CostCenterID) END AS Dimension, N.Expression,              
(SELECT TOP (1) NotificationName              
FROM COM_Notifications with(nolock)
WHERE (NotificationID = N.DefID)) AS NotifTemplate, '''' AS ScheduleTemplate,              
(SELECT TOP (1) ResourceData              
FROM COM_LanguageResources with(nolock)
WHERE ResourceID = S.ResourceID) AS ST, N.StatusID, 0 AS Depth, 0 AS IsGroup, 0 AS ParentID, 0 AS TypeID,N.WorkFlowNotifDefID AS NodeID              
FROM COM_WorkFlowNotifDef AS N with(nolock) 
LEFT OUTER JOIN COM_Status AS S with(nolock) ON S.StatusID = N.StatusID              
WHERE N.DefTypeID=2'              
    END               
              
	ELSE IF(@CostCenterID between 40000 and 50000)              
	begin      
    -- PRINT 'IKRAM'
		if(@GridViewID=278 or @GridViewID=280 OR @PendingList=1)              
		begin   
			 SELECT @ColumnCostCenterID=[CostCenterIDBase] 
			FROM [COM_DocumentLinkDef] with(nolock)
			where [DocumentLinkDefID]=@LinkDefID
			
			SET @SQL='DECLARE @CostCenterID int,@ColumnName nvarchar(50),@lINKColumnName nvarchar(50)              
			DECLARE @Query nvarchar(max),@LinkCostCenterID int,@ColID INT,@lINKColID INT,@PrefValue nvarchar(50) ,@Vouchers nvarchar(max)             

			SELECT @CostCenterID=[CostCenterIDBase]              
			,@ColID=[CostCenterColIDBase]              
			,@LinkCostCenterID=[CostCenterIDLinked]              
			,@lINKColID=[CostCenterColIDLinked]    
			,@Vouchers = [LinkedVouchers]              
			FROM [COM_DocumentLinkDef] with(nolock)
			where [DocumentLinkDefID]='+@LinkDefID+'              

			SELECT @ColumnName=SysColumnName from ADM_CostCenterDef with(nolock)
			where CostCenterColID=@lINKColID

			SELECT @lINKColumnName=SysColumnName from ADM_CostCenterDef with(nolock)
			where CostCenterColID= @ColID

			DECLARE @tblList AS TABLE(abcd INT)                

			set @Query=''SELECT a.InvDocDetailsID from ''              
			IF(@ColumnName LIKE ''dcNum%'' )              
				SET @Query=@Query+''COM_DocNumData a  with(nolock)'' +              
				''join INV_DocDetails d with(nolock) on a.InvDocDetailsID =d.InvDocDetailsID
				join inv_product p  with(nolock) on d.ProductID=p.ProductID     ''              
			ELSE              
				SET @Query=@Query+''INV_DocDetails a with(nolock) 
				join inv_product p  with(nolock) on a.ProductID=p.ProductID ''              

			SET @Query=@Query+''left join INV_DocDetails B with(nolock) on a.InvDocDetailsID =b.LinkedInvDocDetailsID ''              

      		select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)
			where CostCenterID=@LinkCostCenterID and PrefName=''AllowMultipleLinking''              

			if(@PrefValue is not null and @PrefValue=''True''    )           
			BEGIN        
				DECLARE @FinalStr nvarchar(max)    
				if(@Vouchers is not null and @Vouchers <>'''')    
				BEGIN    
					SET @FinalStr =@Vouchers    
					SET @FinalStr = @FinalStr +'',''+convert(nvarchar(5),@CostCenterID)       
				END     
				ELSE    
					SET @FinalStr = convert(nvarchar(5),@CostCenterID)           
					SET @Query=@Query+'' and b.CostCenterid  in (''+@FinalStr  +'')''    
				END     

				IF(@ColumnName LIKE ''dcNum%'' )              
					SET @Query=@Query+'' JOIN COM_DocCCData DCM WITH(NOLOCK) ON DCM.InvDocDetailsID=d.InvDocDetailsID ''    
				ELSE              
					SET @Query=@Query+'' JOIN COM_DocCCData DCM WITH(NOLOCK) ON DCM.InvDocDetailsID=a.InvDocDetailsID '''    
	    
			IF(@WhereCondition <> '' and @WhereCondition like '%join%')  
			BEGIN
				set @CC= charindex('join',@WhereCondition)
				SET @SQL= @SQL+'SET @Query=@Query+'''+substring(@WhereCondition,@CC,LEN(@WhereCondition))+'''' 		
				set @WhereCondition= substring(@WhereCondition,0,@CC)
			END        
	                 
			SET @SQL= @SQL+' IF(@ColumnName LIKE ''dcNum%'' )              
				SET @Query=@Query+'' where d.CostCenterid=''+convert(nvarchar(5),@LinkCostCenterID)              
			ELSE              
				SET @Query=@Query+'' where a.CostCenterid=''+convert(nvarchar(5),@LinkCostCenterID)              
			
			select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)
			where CostCenterID=@LinkCostCenterID and PrefName=''Allowlinkingonce''                

			if(@PrefValue is not null and @PrefValue=''True'')            
			begin              
				SET @Query=@Query+'' and b.InvDocDetailsID is null ''              
			end        
			
			select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)      
			where CostCenterID=@CostCenterID and PrefName=''linkSingleline''        

			if(@PrefValue is not null and @PrefValue=''True'')--FOr link Single line      
			begin
				IF(@ColumnName LIKE ''dcNum%'' )    
					SET @Query=@Query+'' and d.DocSeqNo=1''     
				Else
					SET @Query=@Query+'' and a.DocSeqNo=1''      
				end    

				select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)      
				where CostCenterID=@CostCenterID and PrefName=''OnlyLinked''       

				if(@PrefValue is not null and @PrefValue=''True'')--FOr link Single line      
				begin
					IF(@ColumnName LIKE ''dcNum%'' )    
						SET @Query=@Query+'' and d.LinkedInvDocDetailsID is not null and d.LinkedInvDocDetailsID>0 ''      
					Else
						SET @Query=@Query+'' and a.LinkedInvDocDetailsID is not null and a.LinkedInvDocDetailsID>0 ''      
					end   

				IF(@ColumnName LIKE ''dcNum%'' )    
					SET @Query=@Query+'' and d.linkstatusid<>445 ''     
				Else
					SET @Query=@Query+'' and a.linkstatusid<>445 '''           
	       
			IF(@WhereCondition <> '')  
				SET @SQL= @SQL+'SET @Query=@Query+'''+@WhereCondition +'''' 

			IF(@LocationWhere <> '' and @LocationWhere <> '0')          
				SET @SQL= @SQL+' select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)
				where CostCenterID=@CostCenterID and PrefName=''OverrideLocationwise''            

				if(@PrefValue is null or @PrefValue<>''True'')    
					SET @Query=@Query+N'' and DCM.dcCCNID2 in('+@LocationWhere+')'''        

			IF(@DivisionWhere <> '' and @DivisionWhere <> '0')
			BEGIN          
				SET @SQL= @SQL+' select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)
				where CostCenterID=@CostCenterID and PrefName=''OverrideDivisionwise''            
				          
				if(@PrefValue is null or @PrefValue<>''True'')          
				SET @Query=@Query+N'' and DCM.dcCCNID1 in ('+@DivisionWhere +')'''    
			END          
	   
			IF(@DocDate is not null)          
			BEGIN          
				SET @SQL= @SQL+' select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)
				where CostCenterID=@CostCenterID and PrefName=''MonthWise''            

				if(@PrefValue is NOT null AND  @PrefValue=''True'')         
				BEGIN          
					SET @Query=@Query+'' and month(convert(datetime, a.DocDate)) = '''''+convert(nvarchar(20),month(@DocDate))+'''''''           
				END          

				select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)
				where CostCenterID=@CostCenterID and PrefName=''Ondocumentdate''            

				if(@PrefValue is NOT null AND  @PrefValue=''True'')         
				BEGIN          
					SET @Query=@Query+'' and convert(datetime, a.DocDate) = '''''+convert(nvarchar(20),@DocDate)+'''''''           
				END      
				
				set @PrefValue= null
					
				select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)
				where CostCenterID=@LinkCostCenterID and PrefName=''Expiredafter''            

				if(@PrefValue is NOT null and convert(int,@PrefValue)>0)          
				BEGIN          
				IF(@ColumnName LIKE ''dcNum%'' )           
					SET @Query=@Query+'' and convert(datetime, d.DocDate) >=convert(datetime,'''''+convert(nvarchar(20),@DocDate)+''''')''+convert(nvarchar, -convert(int,@PrefValue))          
				else    
					SET @Query=@Query+'' and convert(datetime, a.DocDate) >=convert(datetime,'''''+convert(nvarchar(20),@DocDate)+''''')''+convert(nvarchar,-convert(int,+@PrefValue))          
				END    '       
			end     
			 
			IF(@DocDate is not null and   @DocDate <> '')          
			BEGIN           
				SET @SQL= @SQL+' select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)
				where CostCenterID=@CostCenterID and PrefName=''Duedatewise''            
				    
				if(@PrefValue is NOT null AND  @PrefValue=''True'' )         
				BEGIN          
					SET @Query=@Query+'' and convert(datetime, a.DueDate) >= '''''+convert(nvarchar(20),@DocDate)+'''''''           
				END  '        
			end                
	                
			SET @SQL= @SQL+'SET @Query=@Query+'' group by a.InvDocDetailsID,a.''+@ColumnName              

			select @PrefValue=PrefValue from COM_DocumentPreferences with(nolock)
			where CostCenterID=@CostCenterID and PrefName=''LinkZeroQty''                

			if(@PrefValue is null or @PrefValue<>''True'')             
			begin              
				SET @Query=@Query+'' having a.''+@ColumnName+''-isnull(sum(b.LinkedFieldValue),0) >0 ''              
			end              

			INSERT INTO @tblList              
			Exec(@Query)       '  
			
			----GETTING DOCUMENT DETAILS              
			--select distinct  A.DocID rowno '+@strColumns+',0 StatusID,0 Depth,''false'' IsGroup,0 ParentID,convert(INT,DOcNUmber) docno,a.DocAbbr,a.DocPrefix,CASE WHEN A.MODIFIEDDATE IS NULL THEN A.CREATEDDATE else A.MODIFIEDDATE END MODDATE,'+@Primarycol+@STRJOIN+                       
			--' where a.statusid=369 and a.InvDocDetailsID in (select abcd from @tblList)'
			
			--GETTING DOCUMENT DETAILS              
			SET @SQL= @SQL+' select distinct  A.DocID rowno '+@strColumns+',0 StatusID,0 Depth,''false'' IsGroup,0 ParentID,convert(INT,DOcNUmber) docno,a.DocAbbr,a.DocPrefix,CASE WHEN A.MODIFIEDDATE IS NULL THEN A.CREATEDDATE else A.MODIFIEDDATE END MODDATE,'+@Primarycol+@STRJOIN                       
			if((@ColumnCostCenterID>40000 and @ColumnCostCenterID<50000)
					and exists(select PrefValue from COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@ColumnCostCenterID and PrefName='ShowLinkedDocsBasedon' and isnull(PrefValue,'')<>'')
					and exists(select PrefValue from COM_DocumentPreferences WITH(NOLOCK) where CostCenterID=@ColumnCostCenterID and PrefName='LinkUnposted' and isnull(PrefValue,'')='true'))
				SET @SQL= @SQL+' where a.statusid in (369,372) '
			else 
				SET @SQL= @SQL+' where a.statusid=369 '
				
			SET @SQL= @SQL+' and a.InvDocDetailsID in (select abcd from @tblList)'
			
			if exists(select PrefValue from COM_DocumentPreferences WITH(NOLOCK)
			where CostCenterID=@ColumnCostCenterID and PrefName='SortDesc' and PrefValue='true')
				set @SQL= @SQL+' order by MODDATE DESC,docno DESC, a.[DocID] DESC '
			ELSE
				set @SQL= @SQL+' order by  a.DocAbbr DESC ,a.DocPrefix DESC,docno desc'  
		end              
		else				    
		begin  

			DECLARE @BIDPrefValue NVARCHAR(100)
			select @BIDPrefValue = PrefValue from COM_DocumentPreferences with(nolock)
			where PrefName='BidQuotationDocument'

			if(@CostCenterID = @BIDPrefValue)
			Begin
					SET @SQL = 'DECLARE @I INT,@CNT INT
					DECLARE @Tbl AS TABLE(ID INT NOT NULL IDENTITY(1,1), DetailsID INT,CostCenterID INT,LinkedInvDocDetailsID INT,QDocID INT)
					INSERT INTO @Tbl(DetailsID,CostCenterID,LinkedInvDocDetailsID,QDocID)
					SELECT D.[InvDocDetailsID],D.CostCenterID,NULL,D.DocID 
					FROM [INV_DocDetails] D with(nolock) 
					WHERE D.DocID ='+ @LinkDefID +' -- 33978 -- 34087
					SET @I=0 '

					SET @SQL = @SQL + ' WHILE(1=1)
					BEGIN
						SET @CNT=(SELECT Count(*) FROM @Tbl)
						INSERT INTO @Tbl(DetailsID,CostCenterID,LinkedInvDocDetailsID,QDocID)
						SELECT INV.InvDocDetailsID,INV.CostCenterID,CASE WHEN T.LinkedInvDocDetailsID IS NULL THEN INV.LinkedInvDocDetailsID ELSE T.LinkedInvDocDetailsID END,INV.DocID
						FROM INV_DocDetails INV with(nolock) INNER JOIN @Tbl T ON INV.LinkedInvDocDetailsID=T.DetailsID AND ID>@I
	
						IF @CNT=(SELECT Count(*) FROM @Tbl)
							BREAK
						SET @I=@CNT
					END '	

					SET @SQL = @SQL + '   select distinct  A.DocID rowno '+@strColumns+',A.DocPrefix,A.DocNumber,A.StatusID,0 Depth,''false'' IsGroup,A.DocDate,0 ParentID,'+@Primarycol+@STRJOIN              
								+' where A.DocID in ( SELECT d.DocID
					FROM [INV_DocDetails] D with(nolock)
					JOIN @Tbl TBL ON TBL.DetailsID=D.InvDocDetailsID AND TBL.CostCenterID= '+ convert(varchar,@BIDPrefValue) + ' 
					INNER JOIN ACC_Accounts CR with(nolock) ON CR.AccountID = D.CreditAccount
					)  '

			End
			else
			Begin

				SET @SQL=' select distinct  A.DocID rowno '+@strColumns+',A.DocPrefix,A.DocNumber,A.StatusID,0 Depth,''false'' IsGroup,A.DocDate,0 ParentID,'+@Primarycol+@STRJOIN              
				+' where A.CostCenterID='+CONVERT(nvarchar, @LinkDefID) 
			End       

			if(@DivisionWhere is not null and @DivisionWhere<>'')              
			begin              
				SET @SQL= @SQL+' and DCM.dcCCNID1 in ('+@DivisionWhere+')'              
			end              
			if(@LocationWhere is not null and @LocationWhere<>'')              
			begin                  
				SET @SQL= @SQL+' and DCM.dcCCNID2 in ('+@LocationWhere+')'              
			end              
			SET @SQL= @SQL+'  order by A.DocDate desc'           
		end              
	end              
	       
	IF(@CostCenterID=81)                
	BEGIN                
	   SET @SQL='  select row_number() over (order by A.ContractTemplID) rowno,A.CTemplCode,A.CTemplName,A.BillFrequencyName,A.SvcFrequencyName,S.Status,A.StatusID,A.Depth,A.IsGroup,A.ParentID,A.ContractTemplID as NodeID,0 as TypeID                 
FROM CRM_ContractTemplate A WITH(NOLOCK)               
left join COM_Status S with(nolock) on S.StatusID = A.StatusID'                               
	END                           
	ELSE IF(@CostCenterID=40)
	BEGIN
		select @where=''
		IF @LocationWhere is not null and @LocationWhere!=''
			set @where=' and (A.IsGroup=1 or A.ProfileID IN (select ProfileID from COM_CCPrices with(nolock) where CCNID2 IN ('+@LocationWhere+')))'
		IF @DivisionWhere is not null and @DivisionWhere!=''
			set @where=' and (A.IsGroup=1 or A.ProfileID IN (select ProfileID from COM_CCPrices with(nolock) where CCNID1 IN ('+@DivisionWhere+')))'
		set @I=1
		set @strColumns=''
		while(@I<=@Cnt)
		begin
			select @CostCenterColID=CostCenterColID from @tblList where ID=@I
			if @CostCenterColID=24408
				set @strColumns=@strColumns+',A.ProfileName'
			else if @CostCenterColID=130
				set @strColumns=@strColumns+',S.Status'
			else if @CostCenterColID=24411
				set @strColumns=@strColumns+',convert(nvarchar(12), Convert(datetime,(select min(wef) from COM_CCPrices with(nolock) where wef is not null and ProfileID=A.ProfileID),106)) WEF'
			else if @CostCenterColID=133
				set @strColumns=@strColumns+',convert(nvarchar(12), Convert(datetime,(select max(TillDate) from COM_CCPrices with(nolock) where ProfileID=A.ProfileID),106)) TillDate'
			else if @CostCenterColID=510
				set @strColumns=@strColumns+',case (select max(PriceType) from COM_CCPrices with(nolock) where ProfileID=A.ProfileID) when 1 then ''Sale'' when 2 then ''Purchase'' when 3 then ''Reorder Level'' else ''All'' end PriceType'
			else if @CostCenterColID=228
				set @strColumns=@strColumns+',CASE WHEN  A.CreatedDate > 0 THEN  convert(nvarchar(12), Convert(datetime,A.CreatedDate),106) ELSE '''' END as CreatedDate'
			else
				set @strColumns=@strColumns+',null'
			set @I=@I+1
		end
		SET @SQL=' select A.lft'+@strColumns+',1 StatusID,A.Depth,A.IsGroup,A.ParentID,A.ProfileID NodeID,0 as TypeID,Convert(datetime,A.CreatedDate) CreatedDate_Key
		FROM COM_CCPricesDefn A WITH(NOLOCK) 
		inner join COM_Status S WITH(NOLOCK) ON S.StatusID=A.StatusID
		where 1=1'+@where+'
		order by a.lft' 
	END
	ELSE IF(@CostCenterID=45)
		SET @SQL=' select A.lft,A.ProfileName,S.Status,1 StatusID,A.Depth,A.IsGroup,A.ParentID,A.ProfileID NodeID,0 as TypeID 
FROM COM_CCTaxesDefn A WITH(NOLOCK) 
inner join COM_Status S WITH(NOLOCK) ON S.StatusID=A.StatusID
where A.Description is null or A.Description!=''SYSTEM''
order by a.lft'      
	ELSE IF(@CostCenterID=162)
		SET @SQL='DECLARE @UserID INT,@RoleID INT
SET @UserID='+CONVERT(NVARCHAR,@UserID)+'              
SELECT @RoleID='+CONVERT(NVARCHAR,@RoleID)+'

declare @Tbl as TABLE(ID INT) 
if(@UserID=1)
	insert into @Tbl
	select ProfileID from ADM_ImportDef where parentid<>0
else		 
	insert into @Tbl
	SELECT R.ProfileID FROM ADM_Assign M with(nolock) inner join ADM_ImportDef R with(nolock) on R.ProfileID=M.NodeID
	WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
	GROUP BY R.ProfileID 

select A.lft,A.ProfileName,A.FileName, S.Status,1 StatusID,A.Depth,A.IsGroup,A.ParentID,A.ProfileID NodeID,0 as TypeID 
FROM ADM_ImportDef A WITH(NOLOCK) 
inner join COM_Status S WITH(NOLOCK) ON S.StatusID=A.StatusID 
WHERE parentid=0 or  (PROFILEID IN (select ID FROM @Tbl) or A.createdby in (SELECT USERNAME FROM ADM_USERS WITH(NOLOCK) where userid =@UserID))
order by a.lft'      
   ELSE IF(@CostCenterID=44)                
   BEGIN                
		if @WhereCondition is not null and @WhereCondition!=''
			set @Where=' WHERE '+@WhereCondition
		else
			set @Where=''
		SET @SQL=' select 0 lft,A.Name,1 StatusID,1 Depth,0 IsGroup,0 ParentID,A.NodeID,A.LookupType as TypeID FROM COM_Lookup A WITH(NOLOCK)'+@Where+'  order by a.Name'      
		print(@SQL)
   END
   ELSE IF(@CostCenterID=200)
   BEGIN
		set @Where=''
		SET @SQL='DECLARE @UserID INT,@RoleID INT
declare @TblRID as table(RID INT)
SET @UserID='+CONVERT(NVARCHAR,@UserID)+'              
SELECT @RoleID='+CONVERT(NVARCHAR,@RoleID)+'

insert into @TblRID
SELECT R.ReportID  FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=0 and (M.ActionType=1 or M.ActionType=0)
WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
union
SELECT SR.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1 and (M.ActionType=1 or M.ActionType=0)
inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
  
SELECT row_number() over (order by R.lft) rowno, case '+CONVERT(NVARCHAR,@LangID)+' when ''1'' then CONVERT(NVARCHAR(MAX),ReportName) else
CONVERT(NVARCHAR(MAX),CAST(CONVERT(NVARCHAR(MAX),ISNULL(R.ReportDefnXML,CONVERT(NVARCHAR(MAX),R.ReportName))) AS XML).query(''data(PactRevenURpts/PactRevenURptDef/ArabicName)'')) end ReportName
,R.ReportTypeName+(case when R.IsGroup=0 and R.StaticReportType=-1 then '' - Query'' when R.IsGroup=0 and R.StaticReportType>0 then '' - Static'' else '''' end) ReportTypeName
,Description
, CreatedBy,convert(nvarchar(12), Convert(datetime,CreatedDate),106) CreatedDate   
, ModifiedBy,convert(nvarchar(12), Convert(datetime,ModifiedDate),106) ModifiedDate   
, StatusID, Depth, ParentID, lft, rgt, IsGroup,StaticReportType,ReportID  NodeID,0 as TypeID    
FROM ADM_RevenUReports AS R with(nolock)  
WHERE ReportID>0 AND (ReportID=1 OR @RoleID=1 OR ReportID IN 
	(
		select RID from @TblRID
		union
		select G.ReportID
		from @TblRID T
		inner join ADM_RevenUReports C with(nolock) ON T.RID=C.ReportID
		inner join ADM_RevenUReports G with(nolock) ON C.lft between G.lft and G.rgt
		group by G.ReportID
	)
)'
   END
   ELSE IF(@CostCenterID=199)
   BEGIN
		set @Where=''
		SET @SQL='
SELECT row_number() over (order by R.lft) rowno,R.Name
,(case when R.IsGroup=0 and R.WType=-1 then ''Query'' when R.IsGroup=0 and R.WType>0 then GR.Name else '''' end) Type
,0 StatusID, R.Depth, R.ParentID, R.lft, R.rgt, R.IsGroup,R.WType,R.ID  NodeID,0 as TypeID    
FROM ADM_Widgets AS R with(nolock)
LEFT JOIN ADM_Widgets AS GR with(nolock) on R.WType=GR.ID
WHERE R.ID>0 '
   END 
   ELSE IF(@CostCenterID=257)
   BEGIN
		set @Where=''
		SET @SQL='
SELECT row_number() over (order by A.lft) rowno, Name, (select top 1 BillNo from INV_DocDetails where DocID=A.FCID) Forecast
,FCPeriod,convert(nvarchar(12), Convert(datetime,FromDate),106) FromDate,convert(nvarchar(12), Convert(datetime,ToDate),106) ToDate, StatusID, Depth, ParentID, lft, rgt, IsGroup,MRPID  NodeID,0 as TypeID    
FROM INV_MRP AS A with(nolock)
WHERE MRPID>0'
	END 
	ELSE IF(@GridViewID=282)                
	BEGIN
		declare @FPColumn nvarchar(50),@BOMCCID INT
		
		select @BOMCCID=Value from ADM_GlobalPreferences with(nolock) where Name='BOMDocument'
		
		select @FPColumn=SysColumnName from ADM_CostCenterDef with(nolock) 
		where CostCenterID=@BOMCCID
		and SysTableName='COM_DocTextData' and ColumnCostCenterID=3

		
		if @FPColumn is not null
		begin
			SET @SQL='SELECT DISTINCT 1 rowno, VoucherNo,P.ProductName FP,DocPrefix,CONVERT(int,DocNumber) Number,1 StatusID,1 Depth,1 ParentID,0 lft,0 rgt,0 IsGroup,DocID  NodeID,0 as TypeID
FROM INV_DocDetails D with(nolock) 
INNER JOIN COM_DocTextData TXT with(nolock) ON TXT.InvDocDetailsID=D.InvDocDetailsID
LEFT JOIN INV_Product P with(nolock) ON P.ProductID=TXT.'+@FPColumn+'
WHERE CostCenterID='+CONVERT(NVARCHAR,@BOMCCID)+'
ORDER BY DocPrefix,Number'     
		end
		else
		begin
			SET @SQL='SELECT DISTINCT 1 rowno, VoucherNo, NULL FP,DocPrefix,CONVERT(int,DocNumber) Number,1 StatusID,1 Depth,1 ParentID,0 lft,0 rgt,0 IsGroup,DocID  NodeID,0 as TypeID
FROM INV_DocDetails D with(nolock) WHERE CostCenterID='+CONVERT(NVARCHAR,@BOMCCID)+'
ORDER BY DocPrefix,Number'     
		end
	END       
	ELSE IF(@GridViewID=283)--Product Vendors
	BEGIN		
		SET @SQL='select A.AccountID,A.AccountCode,A.AccountName,1 StatusID,1 Depth,1 ParentID,0 lft,0 rgt,0 IsGroup,A.AccountID  NodeID,0 as TypeID
from ACC_Accounts A with(nolock) 
INNER JOIN (select distinct AccountID from INV_ProductVendors with(nolock)) AS V
ON A.AccountID=V.AccountID
ORDER BY AccountName'		
	END
	ELSE IF(@GridViewID=284)--Kit Products
	BEGIN
		declare @Tbl as Table(ID INT)
		declare @k int
		set @k=1
		insert into @Tbl
		select A.ParentID FROM INV_Product A WITH(NOLOCK) where a.lft>0 and (a.ProductTypeID=3 or a.ProductTypeID=9) group by A.ParentID
		while(@k<7)
		begin
			insert into @Tbl
			select A.ParentID FROM INV_Product A WITH(NOLOCK) 
			inner join @Tbl T on A.ProductID=T.ID
			where A.ParentID!=0 and a.lft>0 and a.ParentID NOT IN (select ID from @Tbl) group by A.ParentID
			set @k=@k+1
		end
		select A.lft,A.ProductCode,A.ProductName,A.StatusID,A.Depth,A.IsGroup,A.ParentID,A.ProductID as NodeID ,A.ProductTypeID as TypeID,a.lft 
		FROM INV_Product A WITH(NOLOCK) 
		where a.lft>0 and (a.ProductTypeID=3 or a.ProductTypeID=9) or a.ProductID IN (select ID from @Tbl)
		order by  a.lft
	END

	print @SQL
	Exec sp_executesql @SQL  --Main Query               
 
   --To Get the Count of Records in table           
	if (@CostCenterID >50000 AND @UserID!=1 AND Charindex('CG.',@STRJOIN,0)>0) AND (@isproj=1 or (@IsGroupUserWiseExists=0 AND @IsUserWiseExists=1))
		SET @SQL=@MAPSQL+' SELECT count(DISTINCT CG.NodeID) '+@STRJOIN +@Where   
	ELSE IF(@CostCenterID=269)   
		SET @SQL='SELECT count(A.mapID) '+@STRJOIN +@Where   
	ELSE
		SET @SQL=@MAPSQL+' SELECT count(A.ParentID) '+@STRJOIN +@Where  
    
	--print @Where --ADIL check where should have lft condition

	IF(@CostCenterID=81)          
		SET @SQL='SELECT count(A.ContractTemplID) FROM '+@TableName+' A WITH(NOLOCK)'+@Where                
	IF(@CostCenterID=71)       
		SET @SQL='SELECT count(A.ResourceID) FROM '+@TableName+' A WITH(NOLOCK)'+@Where                
	ELSE IF(@CostCenterID between 40000 and 50000)        
		SET @SQL='SELECT 1 '               
            
	IF(@CostCenterID=8)                
		SET @SQL='SELECT count(A.FeatureID) FROM ADM_Features A WITH(NOLOCK) where A.FeatureID>=50000 AND A.FeatureID NOT BETWEEN 50051 AND 50057'                
                     
	IF(@CostCenterID=43)                               
		SET @SQL='SELECT count(A.DocumentTypeID) FROM '+@TableName+' A WITH(NOLOCK)'                   
	ELSE IF(@CostCenterID in (41,47,48))    
		SET @SQL='SELECT count(A.TemplateID) FROM '+@TableName+' A WITH(NOLOCK)'    
	ELSE IF(@CostCenterID=117)                 
		SET @SQL='SELECT count(A.NodeID) FROM ADM_DashBoard A WITH(NOLOCK)'    
	ELSE IF(@CostCenterID=502)           
		SET @SQL='SELECT count(A.AccountTypeID) FROM '+@TableName+' A WITH(NOLOCK)'                
	ELSE IF(@CostCenterID=503)           
		SET @SQL='SELECT count(A.ProductTypeID) FROM '+@TableName+' A WITH(NOLOCK)'                          
	ELSE IF(@GridViewID=198)            
		SET @SQL='SELECT count(A.CostCenterID) FROM ADM_DocumentTypes  A WITH(NOLOCK) '                             
	ELSE IF(@CostCenterID=143 AND @GridViewID<>163)                               
		SET @SQL='SELECT count(A.ServiceTicketID) FROM '+@TableName+' A WITH(NOLOCK)'                              
	ELSE IF (@CostCenterID=7)                   
		SET @SQL=' select  COUNT(A.USERID) '+@STRJOIN+@Where+' '            
	ELSE IF (@CostCenterID=6)           
		SET @SQL=' SELECT count(A.RoleID) FROM '+@TableName+' A WITH(NOLOCK)'          
	ELSE IF (@CostCenterID=11)                  
		SET @SQL=' SELECT count(A.UOMID) FROM '+@TableName+' A WITH(NOLOCK)'            
	ELSE IF (@CostCenterID=49)            
		SET @SQL=' SELECT count(A.ID) FROM ADM_BulkEditTemplate A WITH(NOLOCK)'              
	ELSE IF(@CostCenterID=46)                          
		SET @SQL=' SELECT COUNT(*) FROM COM_WorkFlowNotifDef WITH (NOLOCK) WHERE DefTypeID = 2'                               
	ELSE IF(@CostCenterID=74)                           
		SET @SQL=' SELECT COUNT(*) FROM ACC_AssetClass WITH (NOLOCK)  '                            
    ELSE IF(@CostCenterID=75)                            
		SET @SQL=' SELECT COUNT(*) FROM ACC_DeprBook WITH (NOLOCK)  '                             
    ELSE IF(@CostCenterID=77)                          
		SET @SQL=' SELECT COUNT(*) FROM ACC_PostingGroup WITH (NOLOCK)  '                            
	ELSE IF(@CostCenterID=90)              
		SET @SQL=' SELECT count(A.SFReportID) FROM '+@TableName+' A WITH(NOLOCK)'                
	ELSE IF(@CostCenterID=113)              
		SET @SQL=' SELECT count(A.StatusID) FROM '+@TableName+' A WITH(NOLOCK)'+@Where              
	ELSE IF(@CostCenterID=44)              
		SET @SQL=' SELECT count(A.NodeID) FROM '+@TableName+' A WITH(NOLOCK)'+@Where               
	ELSE IF(@CostCenterID=40)
		SET @SQL=' select count(A.ProfileID) FROM COM_CCPricesDefn A WITH(NOLOCK)'
	ELSE IF(@CostCenterID=45)
		SET @SQL=' select count(A.ProfileID) FROM COM_CCTaxesDefn A WITH(NOLOCK)'
	ELSE IF(@CostCenterID=12)
		SET @SQL=' select count(A.CurrencyID) FROM COM_Currency A WITH(NOLOCK)'
	ELSE IF(@CostCenterID=200 or @CostCenterID=257)
		SET @SQL=' select 1'
   Print @SQL            
   Exec sp_executesql @SQL --Count Query
   
   SELECT [StatusID],[Status] FROM COM_Status WITH(NOLOCK) WHERE [Status]='In Active' AND CostCenterID=@CostCenterID          
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
