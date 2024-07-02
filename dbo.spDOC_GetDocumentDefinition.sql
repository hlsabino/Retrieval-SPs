USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDocumentDefinition]
	@CostCenterID [int],
	@Locations [nvarchar](500) = NULL,
	@Divisions [nvarchar](500) = NULL,
	@Lic [nvarchar](500) = NULL,
	@Viewfor [int],
	@UserName [nvarchar](500),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON;    
    --Declaration Section    
  DECLARE @HasAccess BIT,@Sql nvarchar(max),@DocViewID INT,@Series INT,@ConCCID INT,@DType INT,@Day FLOAT,@IsLineWise BIT,@getregis bit
  DECLARE @DefXml nvarchar(max),@profileID  nvarchar(max),@FRGN BIT,@RegNodeID INT,@ShiftID INT,@tableName nvarchar(200),@OnReject bit,@UserWise bit
  declare @i int, @cnt int,@Value nvarchar(50),@shiftTabName nvarchar(100),@isDayClose bit,@isUserClose int,@isShiftClose bit,@Reg int,@FieldWidth INT,@DimensionList nvarchar(max)
  declare @cctable table(ID INT IDENTITY(1,1),CCID nvarchar(50)) 
  --SP Required Parameters Check    
  IF @CostCenterID=0    
  BEGIN    
   RAISERROR('-100',16,1)    
  END    

	select @DType=DocumentType FROM  ADM_DocumentTypes  WITH(NOLOCK)  where CostCenterID=@CostCenterID       

  if exists(select b.DocumentViewID 
	  from ADM_DocViewUserRoleMap a WITH(NOLOCK) 
	  join [ADM_DocumentViewDef] b WITH(NOLOCK) on a.DocumentViewID=b.DocumentViewID
	  where b.CostCenterID=@CostCenterID and a.UserID=@UserID and b.ViewFor IN (0,@Viewfor))	 
  begin  
	set @DocViewID=(select  top 1 b.DocumentViewID from ADM_DocViewUserRoleMap a WITH(NOLOCK) 
				  join [ADM_DocumentViewDef] b WITH(NOLOCK) on a.DocumentViewID=b.DocumentViewID
				  where b.CostCenterID=@CostCenterID and a.UserID=@UserID and b.ViewFor IN (0,@Viewfor))
  end    
  else  if exists(select b.DocumentViewID 
	  from ADM_DocViewUserRoleMap a WITH(NOLOCK) 
	  join [ADM_DocumentViewDef] b WITH(NOLOCK) on a.DocumentViewID=b.DocumentViewID
	  where b.CostCenterID=@CostCenterID and a.RoleID=@RoleID and b.ViewFor IN (0,@Viewfor))	 
  begin  
	set @DocViewID=(select  top 1 b.DocumentViewID from ADM_DocViewUserRoleMap a WITH(NOLOCK) 
				  join [ADM_DocumentViewDef] b WITH(NOLOCK) on a.DocumentViewID=b.DocumentViewID
				  where b.CostCenterID=@CostCenterID and a.RoleID=@RoleID and b.ViewFor IN (0,@Viewfor))
  end      
  else  if exists(select b.DocumentViewID 
	  from ADM_DocViewUserRoleMap a WITH(NOLOCK) 
	  join [ADM_DocumentViewDef] b WITH(NOLOCK) on a.DocumentViewID=b.DocumentViewID
	  where b.CostCenterID=@CostCenterID and a.GroupID in (select GroupID from   COM_Groups WITH(NOLOCK) where UserID=@UserID or RoleID=@RoleID) and b.ViewFor IN (0,@Viewfor))	 
  begin  
	set @DocViewID=(select  top 1 b.DocumentViewID from ADM_DocViewUserRoleMap a WITH(NOLOCK) 
				  join [ADM_DocumentViewDef] b WITH(NOLOCK) on a.DocumentViewID=b.DocumentViewID
				  where b.CostCenterID=@CostCenterID and a.GroupID in (select GroupID from   COM_Groups WITH(NOLOCK) where UserID=@UserID or RoleID=@RoleID) and b.ViewFor IN (0,@Viewfor))
  end    
  else
  begin
		if (@DType >= 51 AND @DType <= 199 AND @DType != 64) --IS PAYROLL DOCUMENT
		BEGIN
			declare @cnt1 INT
			SET @cnt1=0
			IF EXISTS (SELECT * FROM SYS.TABLES WITH(NOLOCK) WHERE NAME='COM_CC50051')
			BEGIN
				set @Sql=' select @cnt1=COUNT(*) FROM COM_CC50051 WITH(NOLOCK) WHERE RptManager=(Select NodeID FROM COM_CC50051 WITH(NOLOCK) WHERE IsGroup=0 AND LoginUserID='''+@UserName+''') '
				EXEC sp_executesql @Sql,N'@cnt1 int output',@cnt1 output
			END	
			IF (@cnt1>0)
			BEGIN
				if exists(select DocumentViewID from ADM_DocViewUserRoleMap WITH(NOLOCK) where CostCenterID=@CostCenterID and RoleID=-1)  
				  and exists (select DocumentViewID  FROM [ADM_DocumentViewDef] WITH(NOLOCK) where DocumentViewID in(select DocumentViewID from ADM_DocViewUserRoleMap WITH(NOLOCK) where CostCenterID=@CostCenterID and RoleID=-1)  )
				  begin  
					set @DocViewID=(select  top 1 DocumentViewID from ADM_DocViewUserRoleMap WITH(NOLOCK) where CostCenterID=@CostCenterID and  RoleID=-1)  
				  end 
			END
		END
  end  
    --User access check    
    --select @RoleID ,@CostCenterID
  SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,@CostCenterID,2)   
  
  if( @CostCenterID=40079) --Attendance Dimension Wise --Worksheet
	SET @HasAccess=1
  
  IF @HasAccess=0    
  BEGIN    
   RAISERROR('-105',16,1)    
  END 
  
  
   SELECT @IsLineWise=IsLineWise,@OnReject=OnReject,@UserWise=UserWise,@FieldWidth=FieldWidth FROM [COM_WorkFlowDef]  a   WITH(NOLOCK)      
   where [CostCenterID]=@CostCenterID and IsEnabled=1
  
   SELECT @Series=Series,@ConCCID=ConvertAs,@DType=DocumentType FROM  ADM_DocumentTypes  WITH(NOLOCK)  where CostCenterID=@CostCenterID    
   
 
	SET @FRGN = 0  
	SELECT   @FRGN = Value  FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE (Name LIKE 'use foreign currency')  
    
  if(@FRGN = 1 )  
  BEGIN  
  --Getting Costcenter Fields      
	  SELECT  C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,C.RowNo,C.ColumnNo,C.ColumnSpan,    
		C.UserDefaultValue,C.UserProbableValues,C.IsMandatory,C.IsEditable,C.IsVisible,C.ColumnCCListViewTypeID,    
		C.IsCostCenterUserDefined,isnull(C.UIwidth,100) UIWidth,C.IsColumnUserDefined,C.ColumnCostCenterID
		,case when c.ColumnCostCenterID>50000 and (C.FetchMaxRows is null or C.FetchMaxRows<1) then (select top 1 GridViewID from [ADM_GridView] WITH(NOLOCK) where FeatureID=C.ColumnCostCenterID and CostCenterID=98 and IsUserDefined=0)
		else C.FetchMaxRows end FetchMaxRows,C.SectionID,C.SectionName,C.SectionSeqNumber,    
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,DD.DistributionColID,C.IsReEvaluate,RoundOffLineWise,  
		DD.IsRoundOffEnabled,DD.IsDrAccountDisplayed,DD.IsCrAccountDisplayed,DD.IsDistributionEnabled,DD.Distributeon ,LR.SysColumnName as ReservedWordType,   
		DD.IsCalculate,C.IsUnique,C.LinkData,C.LocalReference,CASE WHEN (CDF.COLUMNCOSTCENTERID=7 AND c.dependanton=-7) THEN c.dependanton ELSE CDF.COLUMNCOSTCENTERID END LocalCCID,D.SysColumnName DistCol
		,DD.CrRefID,DD.CrRefColID,CR.SysColumnName as CRSysColumnName,CR.sectionid CRSection,DD.DrRefID,DD.DrRefColID,DR.SysColumnName as DRSysColumnName,DR.sectionid DrSection,C.Decimal
		,C.TextFormat,C.Filter,DD.ShowbodyTotal,C.IsRepeat,c.isnotab,c.lastvaluevouchers,c.dependancy,CASE WHEN c.dependanton=-7 THEN NULL ELSE c.dependanton END dependanton,c.IsTransfer 
		,(select isnull(IsColumnInUse,0) FROM ADM_CostCenterDef with(nolock) where costcenterid=C.ColumnCostCenterID and  syscolumnname='ccnid'+convert(nvarchar,(c.dependanton-50000))) as filterinuse
		,(select isnull(IsColumnInUse,0) FROM ADM_CostCenterDef with(nolock) where costcenterid=3 and  syscolumnname='ccnid'+convert(nvarchar,(C.ColumnCostCenterID-50000))) as Productfilterinuse
		,(select isnull(IsColumnInUse,0) FROM ADM_CostCenterDef with(nolock) where costcenterid=2 and  syscolumnname='ccnid'+convert(nvarchar,(C.ColumnCostCenterID-50000))) as Accountfilterinuse
		, DBACC.ACCOUNTNAME DebitAccountName ,  CRACC.ACCOUNTNAME CreditAccountName,C.CrFilter,C.DbFilter,C.Calculate,DD.ShowinCalc
		,DF.Mode,DF.SpName,DF.Shortcut,DF.IpParams,DF.OpParams,DF.Expression,EvaluateAfter,Posting,c.parentccdefaultcolid,
	   case when C.UserColumnType='Attachment' then C.LastValueVouchers else DD.BasedOnXml end BasedOnXml
	   ,case when LRef.UserProbableValues='h' then 1 else 0 end IsHistory,IGC.[Name] IgnoreChars,c.WaterMark,dd.FixedAcc,c.Cformula,IsPartialLinking,DD.Distxml,C.MinChar,C.MaxChar
	  FROM ADM_CostCenterDef C WITH(NOLOCK)    
	  LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID    
	  LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID AND DD.CostCenterID=c.CostCenterID
	  LEFT JOIN ADM_CostCenterDef LR WITH(NOLOCK) ON LR.CostCenterID=79 AND LR.CostCenterColID=C.LinkData       
	  LEFT JOIN ADM_COSTCENTERDEF CDF WITH(NOLOCK) ON C.LOCALREFERENCE = CDF.COSTCENTERCOLID  AND C.LOCALREFERENCE IS NOT NULL
	  LEFT JOIN ADM_COSTCENTERDEF LRef WITH(NOLOCK) ON LRef.CostCenterID = CDF.COLUMNCOSTCENTERID  AND LRef.syscolumnname=replace(c.syscolumnname,'dc','')
	  LEFT JOIN ADM_CostCenterDef DR WITH(NOLOCK) ON (DR.CostCenterColID = DD.DrRefID or DR.CostCenterColID = -DD.DrRefID) and  DD.DrRefID IS NOT NULL
	  LEFT JOIN ADM_CostCenterDef CR WITH(NOLOCK) ON (CR.CostCenterColID = DD.CrRefID or CR.CostCenterColID = -DD.CrRefID)  and  DD.CrRefID IS NOT NULL
	  LEFT JOIN ADM_CostCenterDef D WITH(NOLOCK) ON D.CostCenterColID = DD.DistributionColID  and  DD.DistributionColID IS NOT NULL
	  LEFT JOIN ACC_ACCOUNTS DBACC WITH(NOLOCK)  ON  DD.DebitAccount =  DBACC.ACCOUNTID
	  LEFT JOIN ACC_ACCOUNTS CRACC WITH(NOLOCK) ON  DD.CreditAccount =  CRACC.ACCOUNTID
	  LEFT JOIN ADM_DocFunctions DF WITH(NOLOCK) ON  DF.CostCenterColID=  C.CostCenterColID AND DF.CostCenterID=c.CostCenterID
	  LEFT JOIN [COM_Lookup] IGC WITH(NOLOCK) ON  IGC.[NodeID]=  C.IgnoreChar
	  WHERE C.CostCenterID = @CostCenterID     
	  AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)  AND   
	   (C.SysColumnName NOT LIKE '%dcCalcNum%')AND (C.SysColumnName NOT LIKE 'dcPOSRemarksNum%') AND (C.SysColumnName <> 'UOMConversion')   AND (C.SysColumnName <> 'UOMConvertedQty')          
	  ORDER BY C.RowNo,C.ColumnNo, C.IsColumnInUse    
  END  
  ELSE    
  BEGIN  
	  SELECT  C.CostCenterColID,R.ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,C.RowNo,C.ColumnNo,C.ColumnSpan,    
		C.UserDefaultValue,C.UserProbableValues,C.IsMandatory,C.IsEditable,C.IsVisible,C.ColumnCCListViewTypeID,    
		C.IsCostCenterUserDefined,isnull(C.UIwidth,100) UIWidth,C.IsColumnUserDefined,C.ColumnCostCenterID,
		case when c.ColumnCostCenterID>50000 and (C.FetchMaxRows is null or C.FetchMaxRows<1) then (select top 1 GridViewID from [ADM_GridView] WITH(NOLOCK) where FeatureID=C.ColumnCostCenterID and CostCenterID=98 and IsUserDefined=0)
		else C.FetchMaxRows end FetchMaxRows,C.SectionID,C.SectionName,C.SectionSeqNumber,    
		DD.DebitAccount,DD.CreditAccount,DD.Formula,DD.PostingType,DD.RoundOff,  DD.DistributionColID,C.IsReEvaluate, RoundOffLineWise, 
		DD.IsRoundOffEnabled,DD.IsDrAccountDisplayed,DD.IsCrAccountDisplayed,DD.IsDistributionEnabled,DD.Distributeon,LR.SysColumnName as ReservedWordType,    
		DD.IsCalculate,C.IsUnique,C.LinkData,C.LocalReference,CASE WHEN (CDF.COLUMNCOSTCENTERID=7 AND c.dependanton=-7) THEN c.dependanton ELSE CDF.COLUMNCOSTCENTERID END LocalCCID,D.SysColumnName DistCol
		,DD.CrRefID,DD.CrRefColID,CR.SysColumnName as CRSysColumnName,CR.sectionid CRSection,DD.DrRefID,DD.DrRefColID,DR.SysColumnName as DRSysColumnName,DR.sectionid DrSection,C.Decimal
		 ,C.TextFormat,C.Filter,DD.ShowbodyTotal,C.IsRepeat,c.isnotab,c.lastvaluevouchers,c.dependancy,CASE WHEN c.dependanton=-7 THEN NULL ELSE c.dependanton END dependanton,c.IsTransfer 
		,(select isnull(IsColumnInUse,0) FROM ADM_CostCenterDef with(nolock) where costcenterid=C.ColumnCostCenterID and  syscolumnname='ccnid'+convert(nvarchar,(c.dependanton-50000))) as filterinuse
		,(select isnull(IsColumnInUse,0) FROM ADM_CostCenterDef with(nolock) where costcenterid=3 and  syscolumnname='ccnid'+convert(nvarchar,(C.ColumnCostCenterID-50000))) as Productfilterinuse
		,(select isnull(IsColumnInUse,0) FROM ADM_CostCenterDef with(nolock) where costcenterid=2 and  syscolumnname='ccnid'+convert(nvarchar,(C.ColumnCostCenterID-50000))) as Accountfilterinuse
		, DBACC.ACCOUNTNAME DebitAccountName ,  CRACC.ACCOUNTNAME CreditAccountName,C.CrFilter,C.DbFilter,C.Calculate,DD.ShowinCalc
		,DF.Mode,DF.SpName,DF.Shortcut,DF.IpParams,DF.OpParams,DF.Expression,EvaluateAfter,Posting,c.parentccdefaultcolid,
	   case when C.UserColumnType='Attachment' then C.LastValueVouchers else DD.BasedOnXml end BasedOnXml
	   ,case when LRef.UserProbableValues='h' then 1 else 0 end IsHistory,c.WaterMark,dd.FixedAcc,c.Cformula,IsPartialLinking,DD.Distxml,C.MinChar,C.MaxChar
	  FROM ADM_CostCenterDef C WITH(NOLOCK)    
	  LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID    
	  LEFT JOIN ADM_DocumentDef DD WITH(NOLOCK) ON DD.CostCenterColID=C.CostCenterColID AND DD.CostCenterID=c.CostCenterID
	  LEFT JOIN ADM_CostCenterDef LR WITH(NOLOCK) ON LR.CostCenterID=79 AND LR.CostCenterColID=C.LinkData       
	  LEFT JOIN ADM_COSTCENTERDEF CDF WITH(NOLOCK) ON C.LOCALREFERENCE = CDF.COSTCENTERCOLID  AND C.LOCALREFERENCE IS NOT NULL  
  	  LEFT JOIN ADM_COSTCENTERDEF LRef WITH(NOLOCK) ON LRef.CostCenterID = CDF.COLUMNCOSTCENTERID  AND LRef.syscolumnname=replace(c.syscolumnname,'dc','')
	  LEFT JOIN ADM_CostCenterDef DR WITH(NOLOCK) ON (DR.CostCenterColID = DD.DrRefID or DR.CostCenterColID = -DD.DrRefID) and  DD.DrRefID IS NOT NULL
	  LEFT JOIN ADM_CostCenterDef CR WITH(NOLOCK) ON (CR.CostCenterColID = DD.CrRefID or CR.CostCenterColID = -DD.CrRefID)  and  DD.CrRefID IS NOT NULL
	  LEFT JOIN ADM_CostCenterDef D WITH(NOLOCK) ON D.CostCenterColID = DD.DistributionColID  and  DD.DistributionColID IS NOT NULL
	  LEFT JOIN ACC_ACCOUNTS DBACC WITH(NOLOCK) ON  DD.DebitAccount =  DBACC.ACCOUNTID
	  LEFT JOIN ACC_ACCOUNTS CRACC WITH(NOLOCK) ON  DD.CreditAccount =  CRACC.ACCOUNTID
	  LEFT JOIN ADM_DocFunctions DF WITH(NOLOCK) ON  DF.CostCenterColID=  C.CostCenterColID AND DF.CostCenterID=c.CostCenterID
	  WHERE C.CostCenterID = @CostCenterID     
	  AND ((C.IsColumnUserDefined=1 AND C.IsColumnInUse=1) OR C.IsColumnUserDefined=0)  AND   
	  (C.SysColumnName NOT LIKE '%dcCalcNum%')  AND (C.SysColumnName NOT LIKE '%dcExchRT%') AND (C.SysColumnName NOT LIKE '%dcCurrID%') AND (C.SysColumnName NOT LIKE 'dcPOSRemarksNum%')  AND (C.SysColumnName <> 'UOMConversion')   AND (C.SysColumnName <> 'UOMConvertedQty')          
	  ORDER BY C.RowNo,C.ColumnNo    
  END  
	
	set @getregis=0
	if(@DType=38 or @DType=39 or @DType=50)
		set @getregis=1
	
	if(@DType=18 and exists(Select PrefValue from COM_DocumentPreferences WITH(NOLOCK) 
	where CostCenterID=@CostCenterID and PrefName='UseasPosReciept' and prefvalue='true'))
		set @getregis=1
		
		print @getregis
		print @DType
	if(@getregis=1)
	BEGIN
		set @Reg=0
		Select @Reg=Value from ADM_GlobalPreferences WITH(NOLOCK)    
		where Name='Registers'
		and Value is not null and ISNUMERIC(Value)=1
		if(@Reg>50000)
		BEGIN
			select @tableName=TableName from ADM_Features WITH(NOLOCK)
			where FeatureID=@Reg
			set @RegNodeID=0
			set @Sql='SELECT @RegNodeID=NOdeID from '+@tableName+' WITH(NOLOCK) where AliasName='''+@Lic+''''			
			exec sp_executesql @Sql,N'@RegNodeID INT OUTPUT' ,@RegNodeID OUTPUT
			
			if(@RegNodeID=0)
			BEGIN
				declare @ind int
				set @ind=Charindex('~',@Lic,0)
				set @Lic=Substring(@Lic,0,@ind) 
 
				set @Sql='SELECT @RegNodeID=NOdeID from '+@tableName+' WITH(NOLOCK) where AliasName='''+@Lic+''''			
				exec sp_executesql @Sql,N'@RegNodeID INT OUTPUT' ,@RegNodeID OUTPUT
			END
			
			set @Sql=''
			select @Sql=Value from ADM_GlobalPreferences with(nolock) where Name ='Dimension List'
   	
			declare  @TblList TABLE (Dimensions int)    
			INSERT INTO @TblList    
			exec spsplitstring @Sql,','  
		
			if(@UserID<>1 and EXISTS(SELECT Dimensions FROM @TblList WHERE Dimensions=@Reg))
			BEGIN
				if not exists(select * from COM_CostCenterCostCenterMap WITH(NOLOCK)
					where ParentCostCenterID=7 and ParentNodeID=@UserID and CostCenterID=@Reg and NodeID=@RegNodeID)
					set @RegNodeID=0
			END
			
			
			if(@RegNodeID>0)
			BEGIN
				declare @StartTime time,@EndTime time--,@PosSessionID INT
				
				--select @PosSessionID=POSLoginHistoryID,@Day=[Day] from POS_loginHistory WITH(NOLOCK) 
				--where RegisterNodeID=@RegNodeID
				--order by POSLoginHistoryID
				
				--if(@Day is not null and @Day < Floor(convert(float,getdate())))
				--begin
				--	if not exists (select DocNo from com_docid with(nolock) where PosSessionID= @PosSessionID)
				--	begin
				--		update POS_loginHistory set [IsDayClose]=1,isShiftClose=1,IsUserClose=1 where POSLoginHistoryID=@PosSessionID
				--	end
				--end
				
				select @Day=[Day],@isDayClose=[IsDayClose],@isShiftClose=isShiftClose,@ShiftID=ShiftNodeID,@isUserClose=IsUserClose
				from POS_loginHistory WITH(NOLOCK) 
				where RegisterNodeID=@RegNodeID
				order by POSLoginHistoryID
				
			    if(@Day is null)
					set @Day=Floor(convert(float,getdate()))
				else if (@isDayClose=1)
				begin
					
					if exists (Select PrefValue from COM_DocumentPreferences WITH(NOLOCK)    
					where CostCenterID=@CostCenterID and PrefName='LogInasSystemDate' and PrefValue='true')
						set @Day=Floor(convert(float,getdate()))
					else
						set @Day=@Day+1
				end
					
				set @i=0
				Select @i=Value from ADM_GlobalPreferences WITH(NOLOCK)    
				where Name='PosShifts' and Value is not null and ISNUMERIC(Value)=1
				
				if((@isShiftClose is null or @isShiftClose=1) and @i>50000)
				begin
					set @ShiftID=0
					select @shiftTabName=TableName from ADM_Features WITH(NOLOCK)
					where FeatureID=@i
				
					set @Sql='declare @stat int
                       select @stat=statusid from com_status WITH(NOLOCK)
                       where costcenterid='+convert(nvarchar(max),@i)+' and status=''In Active''
                       
                       SELECT @ShiftID=SH.NodeID,@StartTime=SH.ccalpha49,@EndTime=SH.ccAlpha50 from '+@shiftTabName+' SH WITH(NOLOCK)'
					
					if (@UserID<>1 AND EXISTS (SELECT Dimensions FROM @TblList WHERE Dimensions=@i))
					BEGIN
						set @Sql=@Sql+' JOIN COM_CostCenterCostCenterMap CCM WITH(NOLOCK) ON CCM.ParentCostCenterID=7 AND CCM.ParentNodeID='+CONVERT(NVARCHAR,@UserID)
						set @Sql=@Sql+' AND CCM.NodeID=SH.NodeID AND CCM.CostCenterID='+CONVERT(NVARCHAR,@i)
					END
					
					
					set @Sql=@Sql+' where ISDATE(SH.ccalpha49)=1 and ISDATE(SH.ccAlpha50)=1 and SH.statusid<>@stat
					and convert(time,getdate()) between CONVERT(time,SH.ccalpha49) and  CONVERT(time,SH.ccAlpha50)'
					
					Select @DimensionList=Value from ADM_GlobalPreferences WITH(NOLOCK) where Name='UserWiseRegisters' and Value is not null
					if (@DimensionList is not null AND @DimensionList<>'' AND CONVERT(INT,@DimensionList) >0 )
					begin
						DECLARE @TEMPSql NVARCHAR(MAX),@ShiftIDS NVARCHAR(MAX)
						SET @TEMPSql='SELECT @ShiftIDS=STUFF((SELECT DISTINCT '',''+CONVERT(NVARCHAR,CCD.dcCCNID'+CONVERT(NVARCHAR,(@i-50000))+') 
								FROM INV_DocDetails IDD WITH(NOLOCK) 
								JOIN COM_DocCCData CCD WITH(NOLOCK) ON CCD.InvDocDetailsID=IDD.InvDocDetailsID
								WHERE IDD.DocDate=FLOOR(CONVERT(FLOAT,GETDATE())) AND IDD.CostCenterID='+@DimensionList+' 
								AND CCD.UserID ='+CONVERT(NVARCHAR,@UserID)+'
								ORDER BY 1 FOR XML PATH ('''')),1,1,'''')'
						
						exec sp_executesql @TEMPSql,N'@ShiftIDS NVARCHAR(MAX) OUTPUT',@ShiftIDS OUTPUT		
						
						IF(@ShiftIDS is null OR  @ShiftIDS='')
							SET @ShiftIDS='0'
						set @Sql=@Sql+' AND SH.NodeID IN('+@ShiftIDS+')'
					END
							print @Sql
					exec sp_executesql @Sql,N'@ShiftID INT OUTPUT,@StartTime  nvarchar(50) OUTPUT,@EndTime  nvarchar(50) OUTPUT' ,@ShiftID OUTPUT,@StartTime OUTPUT,@EndTime OUTPUT
				end
				
				if(@ShiftID is null or @i=0)
					set @ShiftID=0
					
				if(@i>50000)
				begin
				    select @shiftTabName=TableName from ADM_Features WITH(NOLOCK)
					where FeatureID=@i
					
					set @Sql='SELECT @StartTime=convert(time,isnull(ccalpha49,GETDATE())),@EndTime=convert(time,isnull(ccAlpha50,GETDATE())) from '+@shiftTabName+' WITH(NOLOCK) 
						where NodeID='+convert(nvarchar,@ShiftID)	
						print @Sql		
					exec sp_executesql @Sql,N'@StartTime time OUTPUT,@EndTime time OUTPUT',@StartTime OUTPUT,@EndTime OUTPUT
				end
				
				if @StartTime is null
					set @StartTime=convert(time,getdate())
				if @EndTime is null	
					set @EndTime=convert(time,getdate())
				
				if(@isDayClose=0 and @isShiftClose=0)
					set @Sql='SELECT a.NOdeID,COde,Name,0 IsShiftStart,r.PaymentModes,'+convert(nvarchar,@ShiftID)+' ShiftID,convert(datetime,'+CONVERT(nvarchar,@day)+') Day,RightPanelWidth,RowSize,TouchScreen,'''+convert(nvarchar,@StartTime)+''' StartTime,'''+convert(nvarchar,@EndTime)+''' EndTime,b.*,r.ActionHeight,r.ActionWidth from '+@tableName+' a WITH(NOLOCK) 
					join com_ccccdata b WITH(NOLOCK) on a.NOdeID=b.NOdeID
					left join ADM_RegisterPreferences r WITH(NOLOCK) on  a.NOdeID=r.RegisterID
					where b.costcenterid='+CONVERT(nvarchar,@Reg)+' and a.NOdeID='+convert(nvarchar(max),@RegNodeID)
				ELSE
					set @Sql='SELECT a.NOdeID,COde,Name,1 IsShiftStart,r.PaymentModes,'+convert(nvarchar,@ShiftID)+' ShiftID,convert(datetime,'+CONVERT(nvarchar,@day)+') Day,RightPanelWidth,RowSize,TouchScreen,'''+convert(nvarchar,@StartTime)+''' StartTime,'''+convert(nvarchar,@EndTime)+''' EndTime,b.*,r.ActionHeight,r.ActionWidth from '+@tableName+' a WITH(NOLOCK) 
					join com_ccccdata b WITH(NOLOCK) on a.NOdeID=b.NOdeID 
					left join ADM_RegisterPreferences r WITH(NOLOCK) on  a.NOdeID=r.RegisterID
					where b.costcenterid='+CONVERT(nvarchar,@Reg)+' and a.NOdeID='+convert(nvarchar(max),@RegNodeID)
					print @Sql
				exec(@Sql)
			END
			ELSE
				SELECT 1 WHERE 1<>1						
		END
		ELSE
			SELECT 1 WHERE 1<>1		
	END	
	ELSE if(@DType in(15,18,22,23))
	BEGIN
		set @i=0
		Select @i=PrefValue from COM_DocumentPreferences WITH(NOLOCK)    
		where CostCenterID=@CostCenterID and PrefName='CrossDimDocument'
		and PrefValue is not null and ISNUMERIC(PrefValue)=1
		
		if(@i>40000)
		BEGIN
			SELECT distinct [WorkFlowDefID],[CostCenterID],[Action],[Expression],a.WorkFlowID,a.LevelID ,IsLineWise,IsExpressionLineWise,CONVERT(DATETIME,a.WEFDate) WEFDate,CONVERT(DATETIME,a.TILLDate) TILLDate
			FROM [COM_WorkFlowDef]  a   WITH(NOLOCK)
			join COM_WorkFlow b WITH(NOLOCK) on a.WorkFlowID=b.WorkFlowID  and a.LevelID=b.LevelID
			LEFT JOIN COM_Groups G with(nolock) on b.GroupID=G.GID
			where [CostCenterID]=@i and IsEnabled=1  
			and (b.UserID =@UserID or b.RoleID=@RoleID or G.UserID=@UserID or G.RoleID=@RoleID OR b.RoleID=-1)
		END
		ELSE
			SELECT 1 WHERE 1<>1		
	END
	ELSE
		SELECT 1 WHERE 1<>1		
	
	
      
   SELECT [CostCenterID],[DefType],isgroupExists FROM COM_CCPriceTaxCCDefn a WITH(NOLOCK)
   where ProfileID=0 and [DefType] in(1,3)
   union 
   SELECT distinct [CostCenterID],2,isgroupExists  FROM COM_CCPriceTaxCCDefn a WITH(NOLOCK) 
   join COM_CCTaxes b WITH(NOLOCK) on a.ProfileID=b.ProfileID
   where b.docid=@CostCenterID and [DefType]=2

   set @shiftTabName=''
   	select @shiftTabName=GUID+'.'+FileExtension from com_files  WITH(NOLOCK)
	where FeatureID=400 and FeaturePK=@COSTCENTERID
 
  --GETTING DOCUMENT INFO    
   SELECT @shiftTabName attachfile,@OnReject OnReject,@IsLineWise IsLineWise,isnull(@UserWise,0) UserWise,a.DocumentTypeID,a.DocumentType,a.DocumentAbbr
   ,case when DR.ResourceData is not null then DR.ResourceData else a.DocumentName end DocumentName,a.IsInventory,a.StatusID,R.ResourceData 'status'  , a.Bounce Bounce,a.[GUID],ISNULL(@FieldWidth,0) FieldWidth  FROM     
   ADM_DocumentTypes a   WITH(NOLOCK)
    JOIN ADM_RIBBONVIEW V WITH(NOLOCK)  ON A.COSTCENTERID=V.FEATUREID
   LEFT JOIN COM_LanguageResources DR WITH(NOLOCK) ON V.ScreenResourceID=DR.ResourceID AND DR.LanguageID=@LangID
   left join COM_Status S WITH(NOLOCK)  on a.StatusID=s.StatusID  
   LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON S.ResourceID=R.ResourceID AND R.LanguageID=@LangID   
    WHERE a.CostCenterID=@CostCenterID   
      
   --GETTING DOCUMENT PREFIX      
   set @Sql='SELECT CodePrefix,CodeNumberLength,CurrentCodeNumber+CodeNumberInc,isnull(CurrentCodeNumber,0)+1    
   FROM COM_CostCenterCodeDef WITH(NOLOCK) WHERE CostCenterID='    
  
	if((@DType=14 or @DType=19) and @Series=1 and @ConCCID is not null and  @ConCCID>0)--alternate series     
	begin 
		 set @Sql=@Sql+convert(nvarchar,@ConCCID)
	end  
	else     
	begin 
		set @Sql=@Sql+convert(nvarchar,@CostCenterID) 
	end  
   
	if(@Locations is not null and @Locations<>'')    
		set @Sql=@Sql+' and Location in ('+@Locations+')'    
	if(@Divisions is not null and @Divisions<>'')    
		set @Sql=@Sql+' and Division in ('+@Divisions+')'    
      
  exec(@Sql)
    
	select b.BudgetDefID,QtyBudget,QtyType,bd.CostCenterID,convert(datetime,a.FromDate)FromDate,convert(datetime,ToDate)ToDate from ADM_DocumentBudgets a WITH(NOLOCK)
	join COM_BudgetDef b  WITH(NOLOCK) on a.BudgetID=b.BudgetDefID
	join COM_BudgetDefDims bd WITH(NOLOCK) on a.BudgetID=bd.BudgetDefID
	WHERE a.costcenterid=@CostCenterID

  select DocumentLinkDefID,case when DocumentName is null then f.name when DR.ResourceData is not null then DR.ResourceData else DocumentName end DocumentName,CostCenterIDBase,[CostCenterColIDBase]    
      ,[CostCenterIDLinked],[CostCenterColIDLinked],[IsDefault],ViewID ,AutoSelect ,c.syscolumnname
      ,DocumentType  
 from COM_DocumentLinkDef a   WITH(NOLOCK)   
 left  join adm_documenttypes  b  WITH(NOLOCK) on a.[CostCenterIDLinked]=b.CostCenterID 
   left  JOIN ADM_RIBBONVIEW V WITH(NOLOCK)  ON b.COSTCENTERID=V.FEATUREID
   LEFT JOIN COM_LanguageResources DR WITH(NOLOCK) ON V.ScreenResourceID=DR.ResourceID AND DR.LanguageID=@LangID

    left  join adm_features  f  WITH(NOLOCK) on a.[CostCenterIDLinked]=f.Featureid
 left  join ADM_Costcenterdef  c  WITH(NOLOCK) on a.[CostCenterColIDLinked]=c.CostCenterColID
  where CostCenterIDBase=@CostCenterID    
  
  DECLARE @DocumentType INT
  SELECT  @DocumentType=DocumentType FROM ADM_DocumentTypes WITH(NOLOCK)
  WHERE CostCenterID = @CostCenterID   
	
	--Getting DOCUMENT Preferences    
	IF(@DocumentType=39 OR @DocumentType=50)
		Select PrefName,PrefValue,PrefValueType from COM_DocumentPreferences WITH(NOLOCK)    
		where CostCenterID=@CostCenterID OR PreferenceTypeName='POS'
		order by   PreferenceTypeName
	ELSE
		Select PrefName,PrefValue,PrefValueType from COM_DocumentPreferences WITH(NOLOCK)    
		where CostCenterID=@CostCenterID 
    
  --Getting DocPrefix   
  SELECT     a.DocPrefixID, a.DocumentTypeID, ISNULL(C.CostCenterID,a.CCID) AS CCID, a.CCID AS ColID, C.SysColumnName, b.Name, a.Length, a.Delimiter, a.PrefixOrder,SeriesNo,Isdefault
FROM         COM_DocPrefix AS a WITH(NOLOCK) LEFT OUTER JOIN
                      ADM_CostCenterDef AS C WITH(NOLOCK) ON a.CCID = C.CostCenterColID LEFT OUTER JOIN
                      ADM_Features AS b WITH (NOLOCK) ON C.CostCenterID = b.FeatureID AND C.CostCenterID > 50000
WHERE     (a.DocumentTypeID =
                          (SELECT     DocumentTypeID
                            FROM          ADM_DocumentTypes WITH(NOLOCK)
                            WHERE      (CostCenterID = @CostCenterID)))
ORDER BY a.SeriesNo,a.PrefixOrder
      /*if((@DType=14 or @DType=19) and @Series=1 and @ConCCID is not null and  @ConCCID>0)--alternate series     
    SELECT [DocPrefixID],[DocumentTypeID],[CCID],Name,[Length],[Delimiter],[PrefixOrder]    
     FROM [COM_DocPrefix] a    
     left join   ADM_FEATURES b WITH(NOLOCK)   on a.CCID=b.FEATUREID and a.CCID>50000    
      where DocumentTypeID=(SELECT DocumentTypeID FROM     
     ADM_DocumentTypes WHERE CostCenterID=@ConCCID)    
     order by PrefixOrder       
    else     
    SELECT [DocPrefixID],[DocumentTypeID],[CCID],Name,[Length],[Delimiter],[PrefixOrder]    
     FROM [COM_DocPrefix] a    
     left join   ADM_FEATURES b WITH(NOLOCK)   on a.CCID=b.FEATUREID and a.CCID>50000    
      where DocumentTypeID=(SELECT DocumentTypeID FROM     
     ADM_DocumentTypes WHERE CostCenterID=@CostCenterID)    
     order by PrefixOrder      */
    
  --Getting Workflows  
   SELECT distinct [WorkFlowDefID],[CostCenterID],[Action],[Expression],a.WorkFlowID,a.LevelID,IsLineWise,IsExpressionLineWise,CONVERT(DATETIME,a.WEFDate) WEFDate,CONVERT(DATETIME,a.TILLDate) TILLDate
   FROM [COM_WorkFlowDef]  a   WITH(NOLOCK)
   join COM_WorkFlow b WITH(NOLOCK) on a.WorkFlowID=b.WorkFlowID  and a.LevelID=b.LevelID
   LEFT JOIN COM_Groups G with(nolock) on b.GroupID=G.GID
   where [CostCenterID]=@CostCenterID and IsEnabled=1  
   and (b.UserID =@UserID or b.RoleID=@RoleID or G.UserID=@UserID or G.RoleID=@RoleID OR b.RoleID=-1 )  
    
   if(@DocViewID is not null and @DocViewID>0)  
   begin  
    SELECT [DocumentViewDefID],c.SysColumnName  
     ,[DocumentViewID]  
     ,[DocumentTypeID]  
     ,d.[CostCenterID]  
     ,d.[CostCenterColID]  
     ,[ViewName]  
     ,d.[IsEditable]  
     ,[IsReadonly]  
     ,[NumFieldEditOptionID]  
     ,d.[IsVisible]  
     ,[TabOptionID]  
     ,[CompoundRuleID]  
     ,[FailureMessage]  
     ,[ActionOptionID]  
     ,[Mode]  
     ,[Expression],d.IsMandatory ,viewfor,d.description 
    FROM [ADM_DocumentViewDef] d WITH(NOLOCK)  
    left join ADM_CostCenterDef c WITH(NOLOCK) on c.CostCenterColID=d.CostCenterColID where DocumentViewID=@DocViewID  
   end  
   else  
   begin  
   SELECT [DocumentViewDefID],c.SysColumnName  
     ,[DocumentViewID]  
     ,[DocumentTypeID]  
     ,d.[CostCenterID]  
     ,d.[CostCenterColID]  
     ,[ViewName]  
     ,d.[IsEditable]  
     ,[IsReadonly]  
     ,[NumFieldEditOptionID]  
     ,d.[IsVisible]  
     ,[TabOptionID]  
     ,[CompoundRuleID]  
     ,[FailureMessage]  
     ,[ActionOptionID]  
     ,[Mode]  
     ,[Expression]  ,d.IsMandatory ,viewfor ,d.description 
    FROM [ADM_DocumentViewDef] d  WITH(NOLOCK) 
    join ADM_CostCenterDef c WITH(NOLOCK) on c.CostCenterColID=d.CostCenterColID where 1=2 --not to return any row just structure  
   end  
  
  
  
  if (@RegNodeID is null or @RegNodeID=0) and exists(Select PrefValue from COM_DocumentPreferences WITH(NOLOCK)
	where PrefName='EnableTouch' and CostCenterID=@CostCenterID and prefvalue='true')
  BEGIN	
		set @Reg=0
		Select @Reg=Value from ADM_GlobalPreferences WITH(NOLOCK) where Name='Registers'
		and Value is not null and ISNUMERIC(Value)=1
		if(@Reg>50000)
		BEGIN
			select @tableName=TableName from ADM_Features WITH(NOLOCK)
			where FeatureID=@Reg
			set @RegNodeID=0
			set @Sql='SELECT @RegNodeID=NOdeID from '+@tableName+' WITH(NOLOCK) where AliasName='''+@Lic+''''			
			exec sp_executesql @Sql,N'@RegNodeID INT OUTPUT' ,@RegNodeID OUTPUT
		END	
	END	
	
    if(@RegNodeID is not null and @RegNodeID>0)	
    begin
		select a.CCID,a.Filter,a.[Level],a.Map,a.ParentCCID,case when f.Name is null then 'Product' else f.Name end Name,r.ButtonHeight,r.ButtonWidth,
		isnull((select IsColumnInUse FROM ADM_CostCenterDef with(nolock)
		where costcenterid=(case when a.CCID<0 then 3 else a.CCID end) and  syscolumnname='ccnid' + convert(nvarchar,(a.ParentCCID - 50000))),0) ColumnInUse
		,r.ActionHeight,r.ActionWidth 
		into #RegTouch
		from ADM_POSLevelsProfiles a WITH(NOLOCK)
		left join ADM_Features f WITH(NOLOCK) on a.CCID=f.FeatureID
		join ADM_RegisterPreferences r with(nolock) on a.ProfileID=r.LevelProfile
		where  r.RegisterID=@RegNodeID
		order by Level	
		
		if not exists (select * from #RegTouch WITH(NOLOCK) where CCID=3 and [Level]=(select max([Level]) from #RegTouch))
			insert into #RegTouch
			select 3,null Filter,1000,0 Map,null ParentCCID,'Product' Name
			,isnull((select max(ButtonHeight) from ADM_RegisterPreferences with(nolock) where RegisterID=@RegNodeID ),50) ButtonHeight
			,isnull((select max(ButtonWidth) from ADM_RegisterPreferences with(nolock) where RegisterID=@RegNodeID ),50) ButtonWidth,
			isnull((select top 1 IsColumnInUse FROM ADM_CostCenterDef with(nolock)
			where costcenterid=3 and  ColumnCostCenterID=((select CCID from ADM_POSLevelsProfiles a WITH(NOLOCK) where PosLevelsProfileID=(select max(a.PosLevelsProfileID)
			from ADM_POSLevelsProfiles a WITH(NOLOCK)
			join ADM_Features f WITH(NOLOCK) on a.CCID=f.FeatureID
			join ADM_RegisterPreferences r with(nolock) on a.ProfileID=r.LevelProfile
			where  r.RegisterID=@RegNodeID))) order by IsColumnInUse desc),0) ColumnInUse,0 ActionHeight,0 ActionWidth
		
		select * from #RegTouch WITH(NOLOCK)
		order by Level
		
		DROP TABLE #RegTouch
	end
	else	
		select 1 
  
	select 1 
  
   SELECT CostCenterID, DocumentName    FROM              -- for list of documents
  ADM_DocumentTypes WITH(NOLOCK) WHERE  DocumentType=26   
  
  select CurrencyID,Name from COM_Currency With(nolock)
  where StatusID=1
  
  SELECT [DocumentDynamicMappingID],[DocumentTypeID],[CostCenterColIDField],[CostCenterColIDMapping]
      ,[ClubFields],c.SysColumnName ,m.SysColumnName MapSysColumnName,c.ColumnDataType,m.UserColumnType MapColumnDataType
      ,delimiter,Show,a.ListTypeID,a.IgnoreKit,a.DistributOn
  FROM [COM_DocumentDynamicMapping] a WITH(NOLOCK)
  JOIN ADM_COSTCENTERDEF c  WITH(NOLOCK)ON a.[CostCenterColIDField] = c.COSTCENTERCOLID 
  left JOIN ADM_COSTCENTERDEF m WITH(NOLOCK) ON a.[CostCenterColIDMapping] = m.COSTCENTERCOLID   
  where a.DocumentTypeID =(select DocumentTypeID from ADM_DocumentTypes with(nolock) where CostCenterID=@CostCenterID)
  
  select name,value from com_costcenterpreferences WITH(NOLOCK) where (costcenterid=3 
  and (name='TempPartProduct' or name='BinFilterinPopup' or name='DefaultDelimiter' or name='IgnoreFirstDelimiter' or name='ScanMultiple' or name='BinFilterDim' or name='BarcodeDimension' or name='Waistage' or name='NoOfBins' or name='ExcludeHoldBins' or name='BinsDimension' or name='ConsolidatedBins' or name='ProductWiseBins' or name='bincapacityonVolume' or name='AutoSelectBins' or name='DonotExceedCapacity'))
  or (costcenterid=16 and name in('AllowNegativebatches','BatchFilterDim','ExcludeHold','ExcludeReserve'))
  or (costcenterid=76 and (name='JobDimension' or name='JobFilterDim' or name='JobRemainingQty' or name='BomDimension' or name='StageDimension')
  or (costcenterid=101 and (name='DueDateCheck' or name='BudgetDateField' or name='BudgetAccountField' ))
  )
  
  declare @tab table(id INT identity(1,1),COlID INT)
   declare @DefCost table(ccid INT,NodeID INT,Name nvarchar(500))
  Declare @Table nvarchar(50),@ColumnName varchar(50),@ListViewID int,@ColumnCostCenterID int,@ListViewTypeID int

  insert into @tab
   SELECT  C.CostCenterColID
   FROM ADM_CostCenterDef C WITH(NOLOCK)    
   WHERE C.CostCenterID = @CostCenterID   
   AND  C.IsColumnInUse=1  and 
   (((C.SysColumnName like 'dcccnid%' or(c.UserColumnType='LISTBOX' and C.SysColumnName like 'dcalpha%') or C.SysColumnName ='DebitAccount' or  C.SysColumnName ='CreditAccount' or C.SysColumnName ='productid')
   and sectionid=3 and UserDefaultValue is not null and UserDefaultValue<>'') or ( C.SysColumnName like 'dcnum%' and sectionid=4 and   UserDefaultValue is not null and UserDefaultValue >0))
  select @cnt=COUNT(id) from @tab
  set @i=0
  while(@i<@cnt)
  begin
	set @i=@i+1
	select @Value=UserDefaultValue,@ListViewTypeID=ColumnCCListViewTypeID,@ColumnCostCenterID=ColumnCostCenterID
	from ADM_CostCenterDef WITH(NOLOCK) where CostCenterColID=(select COlID from @tab where id=@i)
	if(@Value is null or @Value='' or (@ColumnCostCenterID =3 and exists(select ccid from @DefCost where ccid=@ColumnCostCenterID)))
		continue
	 
	 if(@ColumnCostCenterID=11 or @ColumnCostCenterID=0)
		SET @SQL='select ''11'',CurrencyID NodeID ,Name from  COM_Currency  WITH(NOLOCK) where CurrencyID =  '+@Value
	  ELSE if(@ColumnCostCenterID=3)
				SET @SQL='select 3,ProductID AS NodeID ,ProductName+''''+ProductCode from Inv_product  WITH(NOLOCK) where ProductID='+@Value
	  ELSE if(@ColumnCostCenterID=2)
				SET @SQL='select 2,AccountID AS NodeID ,AccountName+''''+AccountCode from Acc_Accounts  WITH(NOLOCK) where AccountID='+@Value			
	ELSE if(@ColumnCostCenterID=44)
				SET @SQL='select 44,NodeID,Name from COM_Lookup WITH(NOLOCK) where NodeID='+@Value
	ELSE			
	BEGIN			
			SELECT @Table=TableName FROM ADM_Features  WITH(NOLOCK) WHERE FeatureID=@ColumnCostCenterID
					 
			IF(@ListViewTypeID = 0)
			BEGIN	
				SELECT @ListViewID=[ListViewID] from ADM_ListView WITH(NOLOCK) 
				where CostCenterID=@ColumnCostCenterID and UserID=@UserID and IsUserDefined=1 and ListViewTypeID is null
						

				IF(@ListViewID IS NULL)
					SELECT @ListViewID=[ListViewID] from ADM_ListView WITH(NOLOCK) 
					where CostCenterID=@ColumnCostCenterID and IsUserDefined=0 and ListViewTypeID is null
			END
			ELSE
			BEGIN	
		 
				SELECT @ListViewID=[ListViewID] from ADM_ListView WITH(NOLOCK) 
				where CostCenterID=@ColumnCostCenterID and ListViewTypeID =@ListViewTypeID
					
 			END


					--Getting FIRST COLUMN IN LIST
					SET @ColumnName=(SELECT Top 1 SysColumnName FROM ADM_CostCenterDef A WITH(NOLOCK)
									JOIN ADM_ListViewColumns B WITH(NOLOCK) ON A.CostCenterColID=B.CostCenterColID 
									WHERE B.ListViewID= @ListViewID
									ORDER BY B.ColumnOrder)
									
					 
					--Prepare query	
					SET @SQL='select '''+convert(nvarchar,@ColumnCostCenterID)+''', NodeID ,'+@ColumnName+' from '+@Table +'  WITH(NOLOCK) where NodeID =  '+@Value
		END
		
			
	print @SQL
	insert into @DefCost
	exec(@SQL)
  end
  
  select * from @DefCost
  
	if((@DType=38 or @DType=39 or @DType=50) and @RegNodeID>0)	
		select CashDrawerCommand,CashDrawerName,PortName,NodeID,NoOfLines,CharactersPerLine,IdleMessageXML,ProductScanXML,BillPayXML,OnExitXML,CashDrawPrintID
		from ADM_PoleDisplay a  WITH(NOLOCK) 
		left join ADM_PoleDisplayRegisters b  WITH(NOLOCK)  on a.poleid=b.poleid
		where DocumentID=@CostCenterID and NodeID=@RegNodeID
	ElSE
		select CashDrawerCommand,CashDrawerName,PortName,NodeID,NoOfLines,CharactersPerLine,IdleMessageXML,ProductScanXML,BillPayXML,OnExitXML,CashDrawPrintID
		from ADM_PoleDisplay a  WITH(NOLOCK) 
		left join ADM_PoleDisplayRegisters b  WITH(NOLOCK)  on a.poleid=b.poleid
		where DocumentID=@CostCenterID
		
  select DefinitionXML,BarcodeXml from ADM_DocBarcodeLayouts WITH(NOLOCK) 
  where CostCenterID=@CostCenterID and  len(Bodyxml)<10
  
  
   select  DocumentLinkDefID,Mode,CostCenterIDBase
   ,case when DR.ResourceData is not null then DR.ResourceData else b.Name end DocName   
   from COM_DocumentLinkDef a   WITH(NOLOCK) 
   join ADM_Features  b  WITH(NOLOCK) on a.CostCenterIDBase=b.FeatureID 
   JOIN ADM_RIBBONVIEW V WITH(NOLOCK) ON b.FEATUREID=V.FEATUREID
   LEFT JOIN COM_LanguageResources DR WITH(NOLOCK) ON V.ScreenResourceID=DR.ResourceID AND DR.LanguageID=@LangID
   join ADM_FeatureAction fa WITH(NOLOCK) on b.FeatureID=fa.FeatureID and fa.FeatureActionTypeID=1
   join ADM_FeatureActionRoleMap fM WITH(NOLOCK) on fa.FeatureActionID=fM.FeatureActionID
   where [CostCenterIDLinked]=@CostCenterID and fM.RoleID=@RoleID
   
	SELECT 1 Type, R.ReportID,Q.ReportName,Q.ReportField,Q.ReportFieldName,Q.DocumentField,Q.DocumentFieldName,A.SysColumnName,Q.Shortcut,Q.DisplayAsPopup,Q.GroupLevel,Q.Width ,Q.Height,Q.mapxml,Q.MapType
	FROM ADM_RevenUReports R  with(nolock)
	inner join ADM_DocumentReports Q WITH(NOLOCK) on Q.DocumentReportID=R.ReportID
    left join ADM_CostCenterDef A WITH(NOLOCK) on A.CostCenterColID=Q.DocumentField 
    left join [ADM_DocReportUserRoleMap] DR WITH(NOLOCK) on DR.DocumentViewID=Q.DocumentViewID and DR.CostCenterID=Q.CostCenterID
	where  Q.CostCenterID=@CostCenterID and (DR.UserID=@UserID OR DR.RoleID=@RoleID OR GroupID IN (SELECT GroupID FROM COM_Groups WITH(NOLOCK) WHERE UserID=@UserID OR RoleID=@RoleID))
	GROUP BY  Q.ReportID, R.ReportID,Q.ReportName,Q.ReportField,Q.ReportFieldName,Q.DocumentField,Q.DocumentFieldName,A.SysColumnName,Q.Shortcut,Q.DisplayAsPopup,Q.GroupLevel ,Q.Width,Q.Height,Q.mapxml,Q.MapType  
	UNION ALL
	SELECT distinct 2 Type,MapCCID ReportID,b.documentname,0,'',0,'','',[ShortCut],[IsNewTab],0,0,0,NULL,NULL
	from [ADM_DocumentMap] a WITH(NOLOCK) 
	join adm_documenttypes b WITH(NOLOCK)  on a.MapCCID=b.costcenterid
	JOIN ADM_FeatureAction f WITH(NOLOCK) ON b.costcenterid=f.FeatureID AND FeatureActionTypeID in(1,2)
	JOIN ADM_FeatureActionRoleMap R WITH(NOLOCK) ON F.FeatureActionID=R.FeatureActionID AND R.RoleID=@RoleID
	where a.CostCenterID=@CostCenterID
	--order by ReportID
    
    select @cnt=count(*) from COM_DocumentLinkDef with(nolock) where costcenteridlinked=@CostCenterID
  
  
	set @profileID=''
	Select @profileID=PrefValue from COM_DocumentPreferences WITH(NOLOCK) where PrefName='DefaultProfileID' and CostCenterID=@CostCenterID
	
	
	declare @ProfileCC nvarchar(max),@PXML XML,@K INT,@CNTP INT;

		set @ProfileCC=''
		SelecT @ProfileCC=prefvalue from com_documentpreferences WITH(NOLOCK) where Costcenterid=@CostCenterID and prefname='DefaultProfileID'
		declare @IncludeCC nvarchar(max)
		declare @Profiletable table(ID INT IDENTITY(1,1),wef datetime,tilldate datetime,profileid NVARCHAR(50)) 
		set @PXML=@ProfileCC
		
		INSERT INTO @Profiletable      
		SELECT DISTINCT X.value('@WEFDate','DateTime') ,X.value('@TillDate','DateTime')
			,X.value('@ProfileID','INT')
		from @PXML.nodes('/DimensionDefProfile/Row') as Data(X) 
		
		SET @K=1
		SELECT  @CNTP=COUNT(*) FROM @Profiletable
		WHILE (@K<=@CNTP)
		BEGIN
				IF(ISNULL(@IncludeCC,'')='')
					SELECT  @IncludeCC=profileid FROM @Profiletable WHERE ID=@K AND ((CONVERT(DATETIME,GETDATE()) BETWEEN CONVERT(DATETIME,WEF) AND CONVERT(DATETIME,tilldate)) OR ISNULL(WEF,'')='')
				ELSE
					SELECT  @IncludeCC=@IncludeCC+','+profileid FROM @Profiletable WHERE ID=@K AND ((CONVERT(DATETIME,GETDATE()) BETWEEN CONVERT(DATETIME,WEF) AND CONVERT(DATETIME,tilldate)) OR ISNULL(WEF,'')='')
		SET @K=@K+1
		END
		
		delete from @cctable
		insert into @cctable  
		exec SPSplitString @IncludeCC,','  	
		--where ProfileID in('+ @profileID +')'    
		--select  * from COM_DimensionMappings
	iF(@profileID<>'')
	begin
	 select distinct @cnt as CNT,getdate() ServerDate,DefXml,profileID 
		from COM_DimensionMappings with(nolock) 		
		where ProfileID in (select CCID from  @cctable ) 
	 
    END
	else
		select @cnt CNT,getdate() ServerDate,'' DefXml,0 profileID
		
  --To Get Notifications On Document
  /*
  SELECT TemplateID,ActionTypeID FROM COM_NotifTemplate N WITH(NOLOCK)
  WHERE CostCenterID=@CostCenterID AND N.TemplateID IN (SELECT NotificationID FROM COM_NotifTemplateUserMap WITH(NOLOCK)
  WHERE UserID=@UserID OR RoleID=@RoleID
	OR GroupID IN (select GID from COM_Groups where UserID=@UserID or RoleID=@RoleID))
  */
  
	SELECT U.*,R.NAME Role,S.Status  FROM ADM_USERS U with(nolock)
	LEFT JOIN ADM_UserRoleMap M with(nolock) ON M.USERID=U.USERID 
	LEFT JOIN ADM_PRoles R with(nolock) ON R.ROLEID=M.ROLEID 
	LEFT JOIN COM_Status S with(nolock) ON S.STATUSID=U.STATUSID AND S.COSTCENTERID=7
	where U.UserID=@UserID

SET NOCOUNT OFF;    
RETURN 1    
END TRY    
-- TEST   
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
