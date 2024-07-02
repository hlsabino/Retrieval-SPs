USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetClientUserDetails]
	@UserName [nvarchar](500),
	@LangID [int] = 1,
	@EXEVersionNo [nvarchar](max) = '',
	@IsDWLogin [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY     
SET NOCOUNT ON    
    
	--Declaration Section    
	DECLARE @HasAccess bit,@Ret int,@UserID INT,@RoleID INT,@VersionNo nvarchar(50),@EmpID INT,@StatusID int,@DLPWd nvarchar(50),@DLFeatureID int,@DLNodeID int
			,@SQL NVARCHAR(MAX)
	--SP Required Parameters Check    
	if(@UserName='')    
	BEGIN    
		RAISERROR('-100',16,1)    
	END

	
	if @IsDWLogin!=0
	begin
		declare @i int,@Cnt int
		declare @TblDims as Table(ID int identity(1,1), FeatureID int,Name nvarchar(100),TblName nvarchar(100))

		insert into @TblDims
		select FeatureID,Name,TableName from ADM_Features with(nolock) where FeatureID IN (select CostCenterID from COM_CostCenterPreferences with(nolock) where Name='CreateUserOnDim' and Value='True') order by FeatureID

		select @i=1,@Cnt=count(*) from @TblDims
		while(@i<=@Cnt)
		begin
			select @DLFeatureID=FeatureID,@DLPWd=TblName from @TblDims where ID=@i
			set @i=@i+1
			set @DLNodeID=0
			--set @SQL='select @DUPNODENO=NodeID,@DLPWd=PasswordAlpha from '+@DLPWd+' with(nolock) where UserNameAlpha='''+@UserName+''''
			set @SQL='select @DUPNODENO=NodeID,@DLPWd=PasswordAlpha from '+@DLPWd+' d with(nolock) left join COM_Status s on s.StatusID = d.StatusID where d.UserNameAlpha='''+@UserName+''' and s.FeatureID = '+convert(nvarchar,@DLFeatureID)+' and s.Status = ''Active'''
			if @DLFeatureID=50170
			begin
			 set @SQL='select @DUPNODENO=NodeID,@DLPWd=PasswordAlpha from '+@DLPWd+' d with(nolock)  where d.UserNameAlpha='''+@UserName+''' and d.StatusID not in (Select StatusID  from Com_status with(nolock) where CostCenterID='+convert(nvarchar,@DLFeatureID)+' and (status=''In Active'' or Status=''Converted''))'
			end 
			EXEC sp_executesql @SQL, N'@DUPNODENO INT OUTPUT,@DLPWd nvarchar(50) OUTPUT',@DLNodeID OUTPUT,@DLPWd OUTPUT
			if @DLNodeID>0
			begin
				select @UserName=UserName from ADM_Users WITH(NOLOCK) where UserID=(select Value from COM_CostCenterPreferences with(nolock) where CostCenterID=@DLFeatureID and Name='CUUserID')
				break;
			end
		end
	end

	select @UserID=UserID from ADM_Users WITH(NOLOCK) where UserName=@UserName and IsUserDeleted = 0
	select @RoleID=RoleID from ADM_UserRoleMap WITH(NOLOCK)  where UserID =@UserID and IsDefault=1
	
	-- Toget EmpId In MobileApplication START
	if exists(select name from sys.tables with(nolock) where name='COM_CC50051')
	begin
		SET @SQL='SELECT @EmpID=EMP.NodeID 
		FROM COM_CostCenterCostCenterMap CCMAP WITH(NOLOCK),COM_CC50051 EMP WITH(NOLOCK)
		WHERE CCMAP.NodeID=EMP.NodeID AND CCMAP.COSTCENTERID=50051 AND CCMAP.ParentNodeID='+CONVERT(NVARCHAR,@UserID)

		EXEC sp_executesql @SQL,N'@EmpID INT OUTPUT',@EmpID OUTPUT
	END		
	
	declare @Dt float
	set @Dt=floor(convert(float,getdate()))
	
	select @StatusID=M.[Status]
	from [COM_CostCenterStatusMap] M WITH(NOLOCK)
	where CostCenterID=7 and NodeID=@UserID and ((FromDate is null and ToDate is null) or (FromDate is not null and FromDate<=@Dt and ToDate is null)
	 or (ToDate is not null and @Dt between FromDate and ToDate))
	
	SELECT a.UserID,a.UserName,case when @IsDWLogin!=0 then @DLPWd else a.Password end [Password],isnull(@StatusID,a.StatusID) StatusID
	,(select top 1 s.[Status] from dbo.COM_Status s  WITH(NOLOCK) where s.StatusID =isnull(@StatusID,a.StatusID)) [Status]
	,a.IsOffline,a.DefaultLanguage,r.RoleID,r.RoleType,r.Name,r.ExtraXML,a.Email1,a.IsPassEncr,@EmpID EmpID,a.LocationID,a.DivisionID,a.Phone1,TwoStepVerMode
	,datediff(d,convert(datetime,a.PwdModifiedOn),getdate()) PwdModifiedDays
	,(SELECT TOP 1 [GUID]+'.'+FileExtension FROM COM_Files WITH(NOLOCK) WHERE FeatureID=7 AND IsProductImage=1 AND FileDescription='USERPHOTO' AND  FeaturePK=a.UserID ) UserPhoto
	FROM dbo.ADM_Users a  WITH(NOLOCK)  
	JOIN [PACT2C].dbo.ADM_Users ADMUSR WITH(NOLOCK) ON ADMUSR.USERNAME collate database_default= a.USERNAME collate database_default 
	join  dbo.ADM_PRoles r  WITH(NOLOCK) on r.RoleID=@RoleID
	WHERE a.IsUserDeleted = 0 and a.UserName=@UserName
	
	set @VersionNo=(select top 1 VersionNo from dbo.ADM_Versions WITH(NOLOCK)  order by CONVERT(int,REPLACE(VersionNo,'.','')) desc)
	if exists(select PatchVersion from PACT2C.dbo.ADM_Patches with(nolock) where Version=@EXEVersionNo)
	begin
		select @VersionNo VersionNo,PatchVersion,FileName,Size,convert(datetime,LastModifiedOn) LastModifiedOn from PACT2C.dbo.ADM_Patches with(nolock) where Version=@EXEVersionNo
		order by FileName		
	end
	else
	begin
		select @VersionNo VersionNo
	end

	SELECT Name,Value FROM ADM_GlobalPreferences WITH(NOLOCK) 
	WHERE Name='LW  Login' or Name='EnableLocationWise' or Name='EnableDivisionWise' or Name='Login' or Name='Registers' or name='Application can Auto-Upgrade' or name='Upgrade Server' or name='Upgrade Server(Local)'
	 or name='IsOffline' or name='PwdHardning' or name='PwdExpiry' or name='CheckUserONLINEOFFLINE' or  Name='ValidateOTPonLogin'
	union	
	select case when FeatureID=50002 THEN 'LocationName' else 'DivisionName' end as Name,Name Value from adm_features with(nolock)
	where FeatureID in(50001,50002)

	IF EXISTS(SELECT Value FROM ADM_GlobalPreferences WITH(NOLOCK)  WHERE Name='EnableLocationWise' AND Value='True')  
	BEGIN  
		---------------
		declare @isemp bit=0,@empseqno INT,@locseqno INT
		if exists(select name from sys.tables with(nolock) where name='com_cc50051')
		begin
			SET @SQL='if exists(select nodeid from com_cc50051 with(nolock) where LoginUserID='''+@username+''')
			begin
				set @isemp=1
				select @empseqno = nodeid from com_cc50051 with(nolock) where LoginUserID='''+@username+'''
			end'
			EXEC sp_executesql @SQL,N'@isemp bit OUTPUT,@empseqno INT OUTPUT',@isemp OUTPUT,@empseqno OUTPUT
		end
		
		if(@isemp=1)
		begin
			select @locseqno= ISNULL(CCNID2,1) FROM COM_CCCCDATA WITH(NOLOCK) WHERE CostCenterID=50051 AND NodeID=@empseqno
			select DISTINCT l.NodeID,l.Code,l.Name,l.IsGroup,l.lft from COM_Location l  WITH(NOLOCK)
			where l.NodeID=@locseqno
		end
		else if @IsDWLogin!=0
		Begin
		    select @locseqno= ISNULL(CCNID2,1) FROM COM_CCCCDATA WITH(NOLOCK) WHERE CostCenterID=convert(nvarchar,@DLFeatureID) AND NodeID=@DLNodeID
			select DISTINCT l.NodeID,l.Code,l.Name,l.IsGroup,l.lft from COM_Location l  WITH(NOLOCK)
			where l.NodeID=@locseqno
		End
		else
		begin
			select DISTINCT l.NodeID,l.Code,l.Name,l.IsGroup,l.lft,CASE WHEN ParentCostCenterID=6 THEN ParentNodeID ELSE 0 END RoleID 
			from COM_Location l  WITH(NOLOCK)
			join COM_Location g  WITH(NOLOCK) on l.lft between g.lft and g.rgt 
			join COM_CostCenterCostCenterMap c WITH(NOLOCK) on g.NodeID=c.NodeID and CostCenterID=50002
			where (ParentCostCenterID=7 and ParentNodeID=@UserID) or (ParentCostCenterID=6 and (ParentNodeID=@RoleID 
			or ParentNodeID IN (select M.RoleID 
			from ADM_UserRoleMap M WITH(NOLOCK)
			where M.UserID=@UserID and M.Status=1 and M.IsDefault=0 
			and ((M.FromDate is null and M.ToDate is null) or (M.FromDate is not null and M.FromDate<=@Dt and M.ToDate is null)
			 or (M.ToDate is not null and @Dt between M.FromDate and M.ToDate)))
			 ))
			order by l.IsGroup,l.lft
		end

		---------------
			
		--select DISTINCT l.NodeID,l.Code,l.Name,l.IsGroup,l.lft from COM_Location l  WITH(NOLOCK)
		--join COM_Location g  WITH(NOLOCK) on l.lft between g.lft and g.rgt 
		--join COM_CostCenterCostCenterMap c WITH(NOLOCK) on g.NodeID=c.NodeID and CostCenterID=50002
		--where (ParentCostCenterID=7 and ParentNodeID=@UserID) or (ParentCostCenterID=6 and ParentNodeID=@RoleID)
		--order by l.IsGroup,l.lft
	END
	else
		select 1 Location where 1!=1

	select R.RoleID,R.Name RoleName,R.Description,IsDefault--,M.Status,FromDate,ToDate 
	from ADM_UserRoleMap M WITH(NOLOCK)
	inner join ADM_PRoles R with(nolock) on R.RoleID=M.RoleID
	where UserID=@UserID and M.Status=1 and IsDefault=0 and R.RoleID!=@RoleID
	and ((FromDate is null and ToDate is null) or (FromDate is not null and FromDate<=@Dt and ToDate is null)
	 or (ToDate is not null and @Dt between FromDate and ToDate))
	union all
	select RoleID,Name RoleName,Description,1  from ADM_PRoles WITH(NOLOCK) where RoleID=@RoleID
	order by IsDefault desc,RoleName

	--IF EXISTS(SELECT Value FROM ADM_GlobalPreferences WITH(NOLOCK)  WHERE Name='EnableDivisionWise' AND Value='True') 
	--BEGIN  
	--	select DISTINCT l.NodeID,l.Code,l.Name,l.IsGroup,l.lft from COM_Division l  WITH(NOLOCK)
	--	join COM_Division g WITH(NOLOCK)  on l.lft between g.lft and g.rgt 
	--	join COM_CostCenterCostCenterMap c WITH(NOLOCK) on g.NodeID=c.NodeID and CostCenterID=50001
	--	where (ParentCostCenterID=7 and ParentNodeID=@UserID) or (ParentCostCenterID=6 and ParentNodeID=@RoleID)
	--	order by l.lft
	--END
	--else
	--	select 1 Division where 1!=1

	select  NodeID,parentid,IsGroup,Name+'~'+Code Location from COM_Location  WITH(NOLOCK) 

	select  NodeID,parentid,IsGroup,Name+'~'+Code Division from COM_Division WITH(NOLOCK) 
	
	select DISTINCT RoleID from ADM_UserRoleMap WITH(NOLOCK) where UserID=@UserID and [Status]=2
	
	declare @IsServiceTenant bit = 0,@IsTenantLogin bit = 0,@LandLordCCID BIGINT,@TenantCCID BIGINT

	if @IsDWLogin=0
		select 0 DWLogin where 1!=1
	else
	begin
	    set @IsTenantLogin = 0
		if exists(select value from com_costcenterpreferences WITH(NOLOCK) where name ='LinkDocument' and costcenterid=94 and value is not null  and value <> '' and ISNumeric(value)=1 and Value = @DLFeatureID)
		begin
			set @IsTenantLogin = 1
				if exists(select name from sys.tables where name='Ren_Tenant')
				BEGIN
					SET @SQL ='select @IsServiceTenant=IsService from Ren_tenant WITH(NOLOCK) where CCNodeID = '+CONVERT(NVARCHAR(max),@DLNodeID)
					exec sp_executesql @SQL,N'@IsServiceTenant bit output',@IsServiceTenant output					
				END	
		end
		select @DLFeatureID DLFeatureID,@DLNodeID DLNodeID,@DLPWd Pwd,@IsTenantLogin IsTenantLogin,@IsServiceTenant IsServiceTenant
	end
	
	declare @BlockCount int=0,@BlockMinutes int=0
	SELECT @BlockCount=convert(int,Value) FROM ADM_GlobalPreferences WITH(NOLOCK)  
	WHERE Name='Blockuserafterattempts' AND Value is not null AND Value<>'' and isnumeric(Value)=1
	
	SELECT @BlockMinutes=convert(int,Value) FROM ADM_GlobalPreferences WITH(NOLOCK)  
	WHERE Name='Blockuserforminutes' AND Value is not null AND Value<>'' and isnumeric(Value)=1
	
	if(@BlockCount>0 and @BlockMinutes>0)
	begin
		select COUNT(*) ACNT,@BlockMinutes-DATEDIFF(MINUTE,CONVERT(DATETIME,MAX(UC.[LoginTime])),GETDATE()) MCNT
		from PACT2C.dbo.[ADM_UserLoginCheck] UC with(nolock) 
		where UC.UserName=@UserName and UC.[Status]=1 and 'PACT2C'+convert(nvarchar,UC.DBIndex)=DB_Name()
		group by UC.UserName
		having COUNT(*)>=@BlockCount AND @BlockMinutes-DATEDIFF(MINUTE,CONVERT(DATETIME,MAX(UC.[LoginTime])),GETDATE())>0
	end
	else
		select 0 ACNT,0 MCNT WHERE 1<>1
	
	
	SET @SQL =''
	CREATE TABLE #RestrictedTAB (ID INT IDENTITY(1,1) PRIMARY KEY,MachineCode NVARCHAR(MAX))
	SELECT DISTINCT @SQL=@SQL+'
		INSERT INTO #RestrictedTAB
		SELECT DISTINCT CC.AliasName FROM COM_CostCenterCostCenterMap CCM WITH(NOLOCK)
		JOIN '+TableName+' CC WITH(NOLOCK) ON CC.NodeID=CCM.NodeID
		WHERE  CCM.ParentCostCenterID=7 AND CCM.ParentNodeID='+CONVERT(NVARCHAR,@UserID)+' AND CCM.CostCenterID='+CONVERT(NVARCHAR,FeatureID)	
	FROM ADM_Features with(nolock) 
	where FeatureID>50000 AND CONVERT(NVARCHAR,FeatureID) IN (SELECT Value FROM ADM_GlobalPreferences WITH(NOLOCK)  WHERE Name='RestrictedAcessDimension')
	EXEC (@SQL)
	SELECT DISTINCT MachineCode FROM #RestrictedTAB WITH(NOLOCK)

	DROP TABLE #RestrictedTAB
	
	if @IsDWLogin<>0
	begin
		select * from REN_FM_Mobile_Configuration with(nolock) 

		declare @MappedDimensions varchar(max) = '', @sqlQ varchar(max) = '', @TenantID int = 0

		if @IsTenantLogin=1 and @IsServiceTenant=1
		begin
			
			select @MappedDimensions = Value from REN_FM_Mobile_Configuration with(nolock) where Name = 'FacilityServiceDimensions'
			
			select @TenantID = TenantID from Ren_tenant with(nolock) where CCNodeID = @DLNodeID

			if @MappedDimensions is null or @MappedDimensions = ''
				set @MappedDimensions = '' + CONVERT(NVARCHAR,@TenantID)+' TenantID'
			else
				set @MappedDimensions = (@MappedDimensions+' ,' + CONVERT(NVARCHAR,@TenantID)+' TenantID')
			
			--Property and Unit
			select P.NodeID PropertyID,P.CCNodeID PropertyNodeID,P.Name PropertyName,U.PropertyID UnitPropertyID,U.UnitID UnitID,U.CCNodeID UnitNodeID,U.Name UnitName from COM_CostCenterCostCenterMap ccmap
			left JOIN REN_Property P WITH(NOLOCK) ON ccmap.NodeID=P.CCNodeID
			left JOIN REN_Units U WITH(NOLOCK) ON ccmap.NodeID=U.CCNodeID
			where ParentCostCenterID = 94 and ParentNodeID = @TenantID and CostCenterID in (select Value from com_costcenterpreferences WITH(NOLOCK) where name ='LinkDocument' and costcenterid in (92,93))


			set @sqlQ = 'select ' + @MappedDimensions + ' from COM_CCCCData CCD with(nolock) where CCD.CostCenterID = 94 and CCD.NodeID = '+CONVERT(NVARCHAR,@TenantID)+''

			exec(@sqlQ)

		end
		else
		begin
			select 1 where 1<>1
			select 1 where 1<>1
		end
	end
	else
	begin
		select 1 where 1<>1
		select 1 where 1<>1
		select 1 where 1<>1
	end

	SELECT FA.FeatureID,FA.FeatureActionTypeID,FA.Name,M.[Description] 
FROM ADM_FeatureActionRoleMap M WITH(NOLOCK)
INNER JOIN ADM_FeatureAction FA WITH(NOLOCK) ON FA.FeatureActionID=M.FeatureActionID
WHERE M.RoleID=@RoleID AND FeatureID=10 AND (FA.Name='Mandatory Location selection on Login' OR FA.Name='Mandatory Division selection on Login')
ORDER BY FA.FeatureID,FA.FeatureActionTypeID

SET NOCOUNT OFF;    
return @Ret
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
