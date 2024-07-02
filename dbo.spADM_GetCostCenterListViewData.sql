USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetCostCenterListViewData]
	@ListViewID [int] = 0,
	@Columns [nvarchar](max),
	@CalcColumns [nvarchar](max),
	@Join [nvarchar](max),
	@SearchOn [nvarchar](50),
	@SearchValue [nvarchar](500),
	@RowCount [int],
	@IsMoveUp [bit] = 0,
	@GroupBy [nvarchar](200) = null,
	@SelectedValue [nvarchar](200) = null,
	@CustomWhere [nvarchar](max),
	@DivisionWhere [nvarchar](max) = NULL,
	@LocationWhere [nvarchar](max) = NULL,
	@ProductID [int] = 0,
	@ExcludeFilter [bit] = 0,
	@SearchWhere [nvarchar](max) = NULL,
	@QtyWhere [nvarchar](max) = NULL,
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY      
SET NOCOUNT ON    
   --Declaration Section      
   DECLARE @HasAccess bit,@FEATUREID int,@TypeID int,@SearchOption int,@ignoreSpecial int,@FilterQOH bit
   Declare @CostCenterID int,@RestrictionWhere nvarchar(max),@SearchOldValue bit,@ignoreUserwise bit
   Declare @Primarycol varchar(50),@lessthan nvarchar(3),@SearchOldValuetext     nvarchar(max)  
   Declare @Table nvarchar(max),@PrimaryKey varchar(50),@SQL nvarchar(max),@Where nvarchar(max)      
   Declare @OrderBY nvarchar(10),@i int  ,@PrefValue  varchar(50),@GroupFilter nvarchar(max)  

   declare @pref table(name nvarchar(200),value nvarchar(max))
   insert into @pref
   select Name,Value from ADM_GlobalPreferences with(nolock)
   where Name in('Dimension List','HideInactiveDimensions','ExcludeUnMapped','Maintain Dimensionwise stock','HideBlockedAccountsandProducts','ListBoxCount','ListBoxIgnoreSpace')
        
   --Check for manadatory paramters      
   if(@ListViewID=0)      
   BEGIN      
     RAISERROR('-100',16,1)      
   END      
  
    set @FilterQOH=0 
   --Getting CostCenterID      
   SELECT @CostCenterID=CostCenterID,@Where=SearchFilter,@TypeID=ListViewTypeID,@SearchOption=SearchOption ,@ignoreUserwise=ignoreUserwise 
   ,@SearchOldValue=SearchOldValue,@GroupFilter=GroupSearchFilter,@ignoreSpecial=ignoreSpecial,@FilterQOH=FilterQOH FROM ADM_ListView WITH(NOLOCK)      
   WHERE  ListViewID =@ListViewID             
		
    if(@ignoreUserwise is not null and @ignoreUserwise=1)
		delete from @pref where name='Dimension List'
    
          
	if(@SearchOn not like '%.%')
	BEGIN
		if(@CostCenterID in(2,3,40064,92,93,94) and @SearchOn like '%alpha%')
			set @SearchOn='e.'+@SearchOn 
		else
			set @SearchOn='a.'+@SearchOn 	
	END
			
   --setting Primary Column         
   if(@CostCenterID=3)      
    SET @Primarycol='ProductID'      
   ELSE IF(@CostCenterID=2)      
    SET @Primarycol='AccountID'  
   ELSE IF(@CostCenterID=16)      
    SET @Primarycol='BatchID' 
    ELSE IF(@CostCenterID=101)      
    SET @Primarycol='BudgetDefID'    
     ELSE IF(@CostCenterID=117)      
    SET @Primarycol='DashBoardID'    
    ELSE IF(@CostCenterID=199)      
    SET @Primarycol='ID'
     ELSE IF(@CostCenterID=8)      
    SET @Primarycol='FeatureID'   
   ELSE IF(@CostCenterID=113)      
    SET @Primarycol='StatusID'     
   ELSE IF(@CostCenterID=11)      
    SET @Primarycol='UOMID'      
   ELSE IF(@CostCenterID=12)      
    SET @Primarycol='CurrencyID'   
   ELSE IF(@CostCenterID=71 or @CostCenterID=80)      
    SET @Primarycol='ResourceID'      
      ELSE IF(@CostCenterID=7)      
    SET @Primarycol='UserID'   
    ELSE IF(@CostCenterID=6)      
    SET @Primarycol='RoleID'    
    ELSE IF(@CostCenterID=76)      
    SET @Primarycol='BOMID'    
    ELSE IF(@CostCenterID=77)      
    SET @Primarycol='PostingGroupID'    
    ELSE IF(@CostCenterID=72)      
    SET @Primarycol='AssetID'      
    ELSE IF(@CostCenterID=89)      
    SET @Primarycol='OpportunityID'    
    ELSE IF(@CostCenterID=86)      
    SET @Primarycol='LeadID'    
   ELSE IF(@CostCenterID=81)      
    SET @Primarycol='ContractTemplID'   
 ELSE IF(@CostCenterID=400)
 BEGIN
	if @TypeID=2
		SET @Primarycol='DocID'
	else if @TypeID=1
		SET @Primarycol='AccDocdetailsID'
	else
		SET @Primarycol='INvDocdetailsID'
 END
 ELSE IF(@CostCenterID=40064)
 BEGIN    
	if @TypeID=1
		SET @Primarycol='INvDocdetailsID'
 END
 ELSE IF(@CostCenterID=83)      
    SET @Primarycol='CustomerID'     
 ELSE IF(@CostCenterID=88)      
    SET @Primarycol='CampaignID'   
 ELSE IF(@CostCenterID=65)      
    SET @Primarycol='ContactID'   
    ELSE IF(@CostCenterID=84)      
    SET @Primarycol='SvcContractID'   
    ELSE IF(@CostCenterID=73)      
    SET @Primarycol='CaseID'   
     ELSE IF(@CostCenterID=93)      
    SET @Primarycol='UnitID'   
 ELSE IF(@CostCenterID=94)      
    SET @Primarycol='TenantID'  
    ELSE IF(@CostCenterID=95 OR @CostCenterID=104)      
    SET @Primarycol='ContractID'  
    ELSE IF(@CostCenterID=103 OR @CostCenterID=129)      
    SET @Primarycol='QuotationID'  
    ELSE IF(@CostCenterID=200)      
  SET @Primarycol='ReportID'   
 ELSE IF(@CostCenterID=300)  
  SET @Primarycol='CostCenterID'     
 ELSE IF(@CostCenterID=502)  
  SET @Primarycol='AccountTypeID'   
 ELSE IF(@CostCenterID=503)  
  SET @Primarycol='ProductTypeID'   
 ELSE IF(@CostCenterID=23)  
  SET @Primarycol='SubstituteGroupID'   
 ELSE      
  SET @Primarycol='NodeID'  
   
  
     --Getting TableName of CostCenter      
   if(@CostCenterID=8)
	 set @Table='ADM_FEATURES'
   ELSE
	SET @Table=(SELECT  TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@CostCenterID) 

    if(@Where is not null and @Where like '%Grp.%')
			set @Join=@Join+' join '+@Table+' Grp WITH(NOLOCK) on a.lft between Grp.lft and Grp.rgt '
	
	if(@GroupFilter is not null and @GroupFilter like '%Grp.%')
	BEGIN
		if(@GroupFilter like '%Grp.'+@Primarycol+'  <>%')
		BEGIN
				set @GroupFilter =REPLACE(@GroupFilter,'Grp.'+@Primarycol+'  <>','Grp.'+@Primarycol+' =')
				set @GroupFilter =REPLACE(@GroupFilter,'and','or')
				set @Join=@Join+' LEFT join '+@Table+' Grp WITH(NOLOCK) on a.lft between Grp.lft and Grp.rgt '
				set @Join=@Join+' and ('+@GroupFilter+') '
				
				 IF (@Where IS not NULL and len(@Where) > 0)        
					SET @Where=@Where+' and Grp.'+@Primarycol+' IS NULL '      
				 else
				 	SET @Where=' Grp.'+@Primarycol+'  IS NULL '         				
		END
		ELSE
		BEGIN
			set @Join=@Join+' join '+@Table+' Grp WITH(NOLOCK) on a.lft between Grp.lft and Grp.rgt '
			set @GroupFilter =REPLACE(@GroupFilter,'and','or')
			set @Join=@Join+' and ('+@GroupFilter+') '
		END	
	end
	
   --if selected value then get data by selected  value      
   if((@SelectedValue is not null and @SelectedValue <> '' and @SelectedValue<>'0') or (@CostCenterID=3 and @SelectedValue='0'))
   BEGIN      
    Declare @tempSearchValue nvarchar(200),@tempSql nvarchar(max)    
      
    set @tempSearchValue='@SearchValue nvarchar(500) OUTPUT'      
    set @tempSql='select @SearchValue=' + @SearchOn + ' from ' + @Table + ' a with(nolock) '
    
    if(@CostCenterID =2)
		set @tempSql=@tempSql+' LEft JOIN ACC_AccountsExtended E  WITH(NOLOCK) on  E.AccountID=a.AccountID '	
	else if(@CostCenterID =3)
		set @tempSql=@tempSql+' LEft JOIN INV_ProductExtended E  WITH(NOLOCK) on  E.ProductID=a.ProductID '	
	ELSE IF(@CostCenterID=92)      
		SET @tempSql=@tempSql+' LEft JOIN ren_propertyExtended E  WITH(NOLOCK) on  E.NodeID=a.NodeID '	
	ELSE IF(@CostCenterID=93)      
		SET @tempSql=@tempSql+'  LEft JOIN ren_UnitsExtended E  WITH(NOLOCK) on  E.UnitID=a.UnitID '	   
	ELSE IF(@CostCenterID=94)      
		SET @tempSql=@tempSql+' LEft JOIN ren_TenantExtended E  WITH(NOLOCK) on  E.TenantID=a.TenantID '	 
    		
    set @tempSql=@tempSql+' where a.' + @Primarycol + ' = ' + @SelectedValue   
    if(@RowCount=3 and @SearchOldValue=1)  
		EXEC sp_executesql @tempSql, @tempSearchValue, @SearchOldValuetext OUTPUT    
    else     
        EXEC sp_executesql @tempSql, @tempSearchValue, @SearchValue OUTPUT       
   END       
          
   --format searchvalue      
   SET @SearchValue=lower(@SearchValue)      
   SET @SearchValue = replace(@SearchValue,'''','''''')      
          
      
   IF @Where IS NULL      
    SET @Where=''      
          
   If len(@Where) > 0      	
		SET @Where=' WHERE '+@Where+' AND '      
   else      
    SET @Where=@Where+' WHERE '      
     
	IF(@CostCenterID=95 OR @CostCenterID=104 OR @CostCenterID=103 OR @CostCenterID=129) 
	BEGIN
		SET @Where=@Where+' a.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' AND '
		IF(@CostCenterID=95 OR @CostCenterID=104)
			SET @Where=@Where+' a.RefContractID=0 AND '
		ELSE IF(@CostCenterID=103 OR @CostCenterID=129)
			SET @Where=@Where+' a.RefQuotation=0 AND '
	END
    
    declare  @TblList TABLE (iUserID int)  
	
	   
	if(@CustomWhere is not null and @CustomWhere<>'')
	begin
		if @CostCenterID=2
		begin
			if(@CustomWhere like '%#DEBTORTEE#%')
			BEGIN
				select @SQL=Value from adm_globalpreferences with(nolock) where Name='DebtorsControlGroup'
				INSERT INTO @TblList    
				exec spsplitstring @SQL,','  
				
				set @SQL='(a.lft=1'
				
				select @SQL=@SQL+' or (a.lft between '+convert(nvarchar,lft)+' and '+convert(nvarchar,rgt)+')' 
				from acc_accounts a with(nolock)
				join @TblList b on a.AccountID=iUserID	
							
				set @SQL=@SQL+')'
				select @CustomWhere=replace(@CustomWhere,'#DEBTORTEE#',@SQL)
			END	
			else if(@CustomWhere like '%#CREDITORTEE#%')
			BEGIN
				select @SQL=Value from adm_globalpreferences with(nolock) where Name='CreditorsControlGroup'
				INSERT INTO @TblList    
				exec spsplitstring @SQL,','  
				
				set @SQL='(a.lft=1'
				
				select @SQL=@SQL+' or (a.lft between '+convert(nvarchar,lft)+' and '+convert(nvarchar,rgt)+')' 
				from acc_accounts a with(nolock)
				join @TblList b on a.AccountID=iUserID	
							
				set @SQL=@SQL+')'
				
				select @CustomWhere=replace(@CustomWhere,'#CREDITORTEE#',@SQL)
			END	
			else if(@CustomWhere like '%#COATEE#%')			
				set @CustomWhere=replace(@CustomWhere,'#COATEE#','(a.AccountTypeID!=6 and a.AccountTypeID!=7)')   
		end 
  
		if(@CostCenterID<>11)
		begin
			IF((@CostCenterID=92 OR @CostCenterID=93 OR @CostCenterID=94) and @CustomWhere='ContractEdit')
			BEGIN
				if(@CostCenterID=92)
					SET @Where=' WHERE a.StatusID in (422,423) AND a.IsGroup = 0 and '
				else if(@CostCenterID=93)
					SET @Where=' WHERE a.Status in (424,425) AND a.IsGroup = 0 and '
				else if(@CostCenterID=94)
					SET @Where=' WHERE a.StatusID in (462,463) AND a.IsGroup = 0 and '
			END
			ELSE
			BEGIN
				set @Where=@Where+@CustomWhere+' and '      
			END
		end
		else
			set @Where=@Where+@CustomWhere
   END
   
   
     
   set @OrderBY=''      
      
         
	IF @IsMoveUp = 1 --to get Previous Records      
	BEGIN      
		set @OrderBY='Desc'
		if exists(select value from @pref where name='ListBoxIgnoreSpace' and value='true')      
			set @lessthan='<'      
		else
			set @lessthan='<N'      	
	END      
	else        
	begin      
		if exists(select value from @pref where name='ListBoxIgnoreSpace' and value='true')      
		BEGIN
			if(@RowCount=3)      
				set @lessthan='>'      
			else      
				set @lessthan='>='      
		END
		ELSE
		BEGIN
			if(@RowCount=3)      
				set @lessthan='>N'      
			else      
				set @lessthan='>=N'    
		END		
	end      
   --Prepare query      

	if(@ExcludeFilter =0 and @DivisionWhere is not null and @DivisionWhere<>'' and not (@CostCenterID =2 and @TypeID in(6,7,8)) and @CostCenterID <>6 and @CostCenterID<>113)      
	begin      
		if(@CostCenterID=50001)      
			set @Where=@Where+' (a.'+ @Primarycol+' in ('+@DivisionWhere+'))  and '      
		else if(@CostCenterID=76)      
			set @Where=@Where+' (a.DivisionID in ('+@DivisionWhere+'))  and '      
		else      
		BEGIN
			set @Join=@Join+' JOIN  COM_CostCenterCostCenterMap CCMD with(nolock) on a.'+ @Primarycol+' =CCMD.ParentNodeID and CCMD.ParentCostCenterID = '+convert(nvarchar,@CostCenterID)
			set @Where=@Where+'  (CCMD.CostCenterID=50001 and CCMD.NodeID in('+@DivisionWhere+')) and '      
		END 
	end 
	
	
       
	if(@ExcludeFilter =0 and @LocationWhere is not null and @LocationWhere<>''
	 and not (@CostCenterID=2 and @TypeID in(6,7,8) and not exists(select value from ADM_GlobalPreferences with(nolock) where Name='LWAccountGroups' and value='True')) 
	 and @CostCenterID <>7 and @CostCenterID<>113)      
	begin   
		if(@CostCenterID=50002)      
			set @Where=@Where+' (a.'+ @Primarycol+' in ('+@LocationWhere+'))  and '     
		else if(@CostCenterID=76)      
			set @Where=@Where+' (a.LocationID in ('+@LocationWhere+'))  and '      
		else if( @CostCenterID>50002)      
		begin    
			select @PrefValue=value from COM_CostCenterPreferences with(nolock) where CostCenterID=@CostCenterID and name='OverrideLocation'  
			if(@PrefValue is null or @PrefValue<>'True')  
			begin
				set @Join=@Join+' left JOIN  COM_CostCenterCostCenterMap CCMl with(nolock) on (a.'+ @Primarycol+' =CCMl.ParentNodeID and CCMl.ParentCostCenterID = '+convert(nvarchar,@CostCenterID)+')'
				set @Where=@Where+'  ((CCMl.CostCenterID=50002 and CCMl.NodeID in('+@LocationWhere+')) or CC.ccnid2 in('+@LocationWhere+')  OR a.ParentID =0 ) and '          
			end    
		end  
		else if(@CostCenterID=6)
		begin
			set @Join=@Join+' JOIN  COM_CostCenterCostCenterMap CCMl with(nolock) on (a.'+ @Primarycol+' =CCMl.ParentNodeID and CCMl.ParentCostCenterID = '+convert(nvarchar,@CostCenterID)+')'
			if @RoleID!=1
				set @Where=@Where+' a.RoleID!=1 and '
			set @Where=@Where+'  (CCMl.CostCenterID=50002 and CCMl.NodeID in('+@LocationWhere+')) and '          
		end
		else if(@CostCenterID=92)
		begin
			set @Where=@Where+' (a.LocationID IN ('+@LocationWhere+') OR A.NodeID IN (SELECT DISTINCT PropertyID FROM ADM_PropertyUserRoleMap WITH(NOLOCK) WHERE LocationID IN ('+@LocationWhere+'))) and'
		end  
		else          
		begin
			set @Join=@Join+' left JOIN  COM_CostCenterCostCenterMap CCMl with(nolock) on (a.'+ @Primarycol+' =CCMl.ParentNodeID and CCMl.ParentCostCenterID = '+convert(nvarchar,@CostCenterID)+')'
			set @Where=@Where+'  ((CCMl.CostCenterID=50002 and CCMl.NodeID in('+@LocationWhere+'))  OR a.ParentID =0) and '          
		end  
	end      
     
   -- Dimensions Wise Filter On User   
	declare @Dimensions nvarchar(max),@Did int ,@Dcnt int,@DimensionWhere nvarchar(50)  
	set @Dimensions=(select value from @pref where name='Dimension List')  
	
	
	delete from  @TblList
	INSERT INTO @TblList    
	exec spsplitstring @Dimensions,','  
	
	if(@CostCenterID=83 and EXISTS(SELECT * FROM @TblList WHERE iUserID=@CostCenterID) and @userid!=1)
	begin
		
		SET @Join=@Join+' LEFT JOIN (select test.LeadID,Grp.lft,Grp.rgt from
		(select ASS.CCNODEID LeadID from CRM_Assignment ASS with(nolock) where ISFROMACTIVITY=0 and ASS.CCID='+convert(varchar,@CostCenterID)+' AND IsTeam=0 and UserID in (select UserID from @TABLEUSERS)
		union
		select ASSS.CCNODEID from CRM_Assignment ASSS with(nolock) where ISFROMACTIVITY=0 and ASSS.CCID='+convert(varchar,@CostCenterID)+' AND ASSS.ISGROUP=1 AND ASSS.teamnodeid IN (SELECT GID FROM COM_GROUPS R with(nolock) inner join @TABLEUSERS T on R.UserID=T.USERID )
		union
		select ASROLE.CCNODEID from CRM_Assignment ASROLE with(nolock) where ISFROMACTIVITY=0 and ASROLE.CCID='+convert(varchar,@CostCenterID)+' AND ASROLE.IsRole=1 AND ASROLE.teamnodeid IN (SELECT ROLEID FROM ADM_UserRoleMap R with(nolock) inner join @TABLEUSERS T on R.UserID=T.USERID) 
		union
		select ASTEAM.CCNODEID from CRM_Assignment ASTEAM with(nolock) where ISFROMACTIVITY=0 and ASTEAM.CCID='+convert(varchar,@CostCenterID)+' AND ASTEAM.IsTeam=1 AND ASTEAM.teamnodeid IN (SELECT teamid FROM crm_teams R with(nolock)inner join @TABLEUSERS T on R.UserID=T.USERID  WHERE  isowner=0 )  
		)  as test 
		join '+@Table+' Grp on (test.LeadID=Grp.'+@Primarycol+' and Grp.'+@Primarycol+'<>1)  ) as  TBL on (a.lft between TBL.lft and TBL.rgt) '
		
		set @Where=@Where+' ('+convert(varchar,@UserID)+'=1 or (a.Createdby in  (SELECT USERNAME FROM @TABLEUSERS))   OR  TBL.LeadID Is not null) and '
	end	
	
	if (CHARINDEX('a.AssignedTo',@Columns)>0 and (@CostCenterID=86 or @CostCenterID=89 or @CostCenterID=83  or @CostCenterID=73))           
	BEGIN        
		SET @Columns=REPLACE(@Columns,'a.AssignedTo',' dbo.fnGet_GetAssignedListForFeatures('+CONVERT(nvarchar(300),@CostCenterID)+',a.'+@Primarycol+') AssignedTo ')  
	END  
  
	if(@ExcludeFilter =0 and (@CostCenterID>50000 or @CostCenterID=7)  and EXISTS(SELECT * FROM @TblList WHERE iUserID=@CostCenterID) and @userid!=1)      
	begin   
		set @PrefValue=''
		select @PrefValue=value from @pref where name='ExcludeUnMapped'
		if (@PrefValue<>'true' or (@PrefValue='true'
			and exists(select CostCenterID from COM_CostCenterCostCenterMap WITH(NOLOCK) where ParentCostCenterID=7 and ParentNodeID=@userid and CostCenterID=@CostCenterID)))
	    BEGIN
			if(@CostCenterID=7)
			begin
				set @Join=@Join+' LEFT JOIN COM_CostCenterCostCenterMap CCMU with(nolock) on  a.'+ @Primarycol+'=CCMU.NodeID and CCMU.CostCenterID=7
				LEFT JOIN COM_CostCenterCostCenterMap CCMUU with(nolock) on  a.'+ @Primarycol+'=CCMUU.ParentNodeID and CCMUU.ParentCostCenterID=7 '
				set @Where=@Where+' ((CCMU.ParentCostCenterID=7 and CCMU.ParentNodeID='+convert(nvarchar,@UserID)+') OR (CCMUU.CostCenterID=7 and CCMUU.NodeID='+convert(nvarchar,@UserID)+')) and '	
			end
			else
			begin
				set @Join=@Join+' LEFT JOIN COM_CostCenterCostCenterMap CCMUU with(nolock) on CCMUU.ParentCostCenterID = '+convert(nvarchar,@CostCenterID)+' and A.'+ @Primarycol+' =CCMUU.ParentNodeID and CCMUU.CostCenterID=7 and CCMUU.NodeID='+convert(nvarchar,@UserID)+'
				LEFT JOIN '+@Table +' CMI with(nolock) ON a.lft between  CMI.lft and CMI.rgt 
				LEFT JOIN COM_CostCenterCostCenterMap CCMU with(nolock) on CMI.'+ @Primarycol+'=CCMU.NodeID and CCMU.CostCenterID='+convert(nvarchar,@CostCenterID)
				set @Where=@Where+' (CCMU.ParentCostCenterID=7 and CCMU.ParentNodeID='+convert(nvarchar,@UserID)+' or A.'+ @Primarycol+' =CCMUU.ParentNodeID) and '	
			end
			
		END	
	end

	if (@CostCenterID=92 and EXISTS(SELECT * FROM @TblList WHERE iUserID=@CostCenterID) and @userid!=1)      
	begin
		SET  @Where=ltrim(rtrim(@Where))+' A.NODEID IN (SELECT PROPERTYID FROM ADM_PROPERTYUSERROLEMAP PropertyUserRoleMap with(nolock) WHERE PropertyUserRoleMap.USERID in ('+convert(nvarchar,@UserID)+') OR 
		PropertyUserRoleMap.ROLEID='+convert(nvarchar,@RoleID)+') and '   
	end 
	  
	 
	if((@CostCenterID=2 or @CostCenterID=3) and @Dimensions is not null and @Dimensions<>'' and EXISTS(SELECT * FROM @TblList WHERE iUserID=@CostCenterID) and @UserID!=1)
	begin
	
		set @PrefValue=''
		select @PrefValue=value from @pref where name='ExcludeUnMapped'
		if (@PrefValue<>'true' or (@PrefValue='true'
			and exists(select CostCenterID from COM_CostCenterCostCenterMap WITH(NOLOCK) where ParentCostCenterID=@CostCenterID and NodeID=@userid and CostCenterID=7)))
		BEGIN
			set @Where=@Where+'(a.Createdby in (SELECT USERNAME FROM ADM_USERS WITH(NOLOCK) WHERE USERID in
			(select nodeid from dbo.COM_CostCenterCostCenterMap with(nolock) where 
			Parentcostcenterid=7 and costcenterid=7 and ParentNodeid='+CONVERT(NVARCHAR(40),@UserID)+') or 
			userid = '+CONVERT(NVARCHAR(40),@UserID)+') or A.'+ @Primarycol+'  IN (SELECT DISTINCT CA.'+@Primarycol+' FROM '+@Table+' CAA WITH(NOLOCK)
JOIN '+@Table+' CA WITH(NOLOCK) ON CA.LFT BETWEEN CAA.LFT AND CAA.RGT
JOIN ( 
SELECT CCMU.ParentNodeID ID FROM COM_CostCenterCostCenterMap CCMU with(nolock) WHERE CCMU.ParentCostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' and CCMU.CostCenterID=7 and CCMU.NodeID='+CONVERT(NVARCHAR,@UserID)+'
UNION
SELECT CCMU.NodeID FROM COM_CostCenterCostCenterMap CCMU with(nolock) WHERE CCMU.ParentCostCenterID = 7 and CCMU.CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' and CCMU.ParentNodeID='+CONVERT(NVARCHAR,@UserID)+') AS T ON T.ID=CAA.'+@Primarycol+')'
			
			if @CostCenterID=2
				set @Where=@Where+' or a.'+ @Primarycol+'=1'    

			set @Where=@Where+') and '  
			
		END	
	end
	
   --  print @Join 
   -- Dimensions Wise Filter On User   
     
	select @PrefValue=Value from @pref 
	where name='HideBlockedAccountsandProducts'  
	
	if(@PrefValue is not null and @PrefValue='True'  and (@CostCenterID=2 or @CostCenterID=3) AND @WHERE NOT LIKE '%StatusID%')  
	begin  
		if(@CostCenterID=2)  
		set @Where=@Where+' (ISNULL((SELECT TOP 1 CCSM.[Status] FROM COM_CostCenterStatusMap CCSM WITH(NOLOCK) WHERE CCSM.CostCenterID=2 AND CCSM.NodeID=a.AccountID AND GETDATE() BETWEEN CONVERT(DATETIME,CCSM.FromDate) AND CONVERT(DATETIME,CCSM.ToDate)),a.StatusID) IN (1,33)'  --<>34
		if(@CostCenterID=3)  
		set @Where=@Where+' (ISNULL((SELECT TOP 1 CCSM.[Status] FROM COM_CostCenterStatusMap CCSM WITH(NOLOCK) WHERE CCSM.CostCenterID=3 AND CCSM.NodeID=a.ProductID AND GETDATE() BETWEEN CONVERT(DATETIME,CCSM.FromDate) AND CONVERT(DATETIME,CCSM.ToDate)),a.StatusID) IN (1,31)'   --<>32
		set @Where=@Where+') and '  
	end  
	
	select @Dimensions=isnull(value,'') from @pref where name='HideInactiveDimensions'  
	
	delete from @TblList
	--COM_CostCenterStatusMap
	IF EXISTS(select NodeID from [COM_CostCenterStatusMap] with(nolock) where CostCenterID=@CostCenterID)
	BEGIN
		IF (@CostCenterID=2 OR @CostCenterID=3 OR @CostCenterID=7 OR @CostCenterID>50000)
		BEGIN
			SET @Join=@Join+' LEFT JOIN   COM_CostCenterStatusMap CCSMP WITH(NOLOCK) ON '
			
			IF (@CostCenterID=2)
				SET @Join=@Join+' CCSMP.NODEID=A.AccountID '
			ELSE IF (@CostCenterID=3)
				SET @Join=@Join+' CCSMP.NODEID=A.ProductID '
			ELSE IF (@CostCenterID=7)
				SET @Join=@Join+' CCSMP.NODEID=A.UserID '			
			ELSE
				SET @Join=@Join+' CCSMP.NODEID=A.NODEID '			
				
			SET @Join=@Join+' AND CCSMP.CostCenterID='+ CONVERT(VARCHAR,@CostCenterID) +' and CCSMP.status=2 
							   AND ((Convert(DateTime,getdate()) between Convert(DateTime,CCSMP.FromDate) and Convert(DateTime,CCSMP.ToDate))
									 OR ( isnull(CCSMP.ToDate,'''')='''' AND Convert(DateTime,getdate()) >= Convert(DateTime,CCSMP.FromDate)) 
								   ) '	
			SET @Where=@Where+' CCSMP.NODEID IS NULL AND '
		END
	END
	ELSE
	BEGIN
		INSERT INTO @TblList    
			exec spsplitstring @Dimensions,',' 
	END
	--INSERT INTO @TblList    
	--exec spsplitstring @Dimensions,',' 
	
	if EXISTS(SELECT * FROM @TblList WHERE iUserID=@CostCenterID) and @userid!=1 
	BEGIN
		select @RestrictionWhere=StatusID from COM_Status WITH(NOLOCK) where CostCenterID=@CostCenterID and Status='In Active'			
		if(@CostCenterID=93)
			set @Where=@Where+' a.status<>'+@RestrictionWhere+' and '  
		else
			set @Where=@Where+' a.statusid<>'+@RestrictionWhere+' and '  	
	END
	
	IF @CostCenterID>50000
	BEGIN      
		if(@ExcludeFilter =0 and @ProductID>0)  
		begin  
			declare @filtercol nvarchar(200)  
			if(@CostCenterID=50006)  			
				set @Join=@Join+' join inv_product INVP with(nolock) on INVP.productid='+convert(nvarchar,@ProductID)+' and a.NODEID =INVP.CategoryID and INVP.CategoryID <>1' 
			else  if(@CostCenterID=50004)  
				set @Join=@Join+' join inv_product INVP with(nolock) on INVP.productid='+convert(nvarchar,@ProductID)+' and a.NODEID =INVP.DepartmentID and INVP.DepartmentID <>1'
			else  
				set @Join=@Join+' join inv_product INVP with(nolock) on INVP.productid='+convert(nvarchar,@ProductID)+' 
				join COM_CCCCData INVCC with(nolock) on INVP.productid=INVCC.NODEID and INVCC.CostCenterID=3 and INVCC.CCNID'+convert(nvarchar,(@CostCenterID-50000))+' =a.NODEID  and INVCC.CCNID'+convert(nvarchar,(@CostCenterID-50000))+' <>1 '
		end 
		
		SET @SQL='select distinct  convert(BIGINT,a.'+ @Primarycol+') '+@Primarycol+','+@Columns
		if exists(select value from @pref where name='ListBoxIgnoreSpace' and value='true')
			SET @SQL=@SQL+',replace('+@SearchOn + ','' '','''')'
		
		SET @SQL=@SQL+' from '+@Table +' a WITH(NOLOCK) LEFT JOIN COM_CCCCData CC ON CC.COSTCENTERID='+CONVERT(NVARCHAR,@CostCenterID)+' AND CC.NODEID= a.'+@Primarycol +@Join+ @Where   
		
		if (exists(select value from @pref where name='ListBoxIgnoreSpace' and value='true') and @SearchOption=1 and @RowCount<>3)  
			SET @SQL=@SQL+' (replace(lower('+@SearchOn+'),'' '','''') '+ @lessthan + 'replace(N'''+@SearchValue+''','' '',''''))'  
		ELSE if(@RowCount=3 or (@SelectedValue is not null and @SelectedValue <> '' and @SelectedValue<>'0')  or @SearchOption=1)  
			SET @SQL=@SQL+' lower('+@SearchOn+') '+ @lessthan + ''''+@SearchValue+''''  
		else  
		BEGIN
			if(@SearchWhere is not null and @SearchWhere<>'')
			BEGIN							
				if(@ignoreSpecial=1 or @ignoreSpecial=2)
					SET @SQL=@SQL+replace(@SearchWhere,'{0}',dbo.fnStr_IgnoreSpecialchar(@SearchValue)) 
				ELSE	
					SET @SQL=@SQL+replace(@SearchWhere,'{0}',@SearchValue) 
			END	
			ELSE if exists(select value from @pref where name='ListBoxIgnoreSpace' and value='true')
				SET @SQL=@SQL+' (replace('+@SearchOn+','' '','''') like '+  'replace(N''%'+@SearchValue+'%'','' '','''')  escape ''\'')'
			ELSE
			BEGIN	
				if(@ignoreSpecial=1)
					SET @SQL=@SQL+' dbo.fnStr_IgnoreSpecialchar('+@SearchOn+') like  N'+'''%'+dbo.fnStr_IgnoreSpecialchar(@SearchValue)+'%''  escape ''\'' '
				ELSE if(@ignoreSpecial=2)
					SET @SQL=@SQL+' '+@SearchOn+' like  N'+'''%'+dbo.fnStr_IgnoreSpecialchar(@SearchValue)+'%''  escape ''\'' '
				ELSE
					SET @SQL=@SQL+' '+@SearchOn+' like  N'+'''%'+@SearchValue+'%''  escape ''\'' '
			END	
		END
		
		IF @CostCenterID > 50000 
			set @SQL=@SQL+' and a.NodeID>0'

		
		if(@RowCount<>3 and @SelectedValue is not null and @SelectedValue<>'')   
			set @SQL=@SQL+' and a.'+@Primarycol+'>='+@SelectedValue  

		if(@SelectedValue is not null and @SelectedValue<>'' and @GroupBy<>'1')   
			set @SQL=@SQL+' or a.'+@Primarycol+'='+@SelectedValue  

		if exists(select value from @pref where name='ListBoxIgnoreSpace' and value='true')
			SET @SQL=@SQL+' ORDER BY replace('+@SearchOn + ','' '','''')  '+ @OrderBY  
		else
			SET @SQL=@SQL+' ORDER BY '+@SearchOn + '  '+ @OrderBY  	
			
		if(@RowCount<>3 and @SelectedValue is not null and @SelectedValue<>'')   
			set @SQL=@SQL+','+@Primarycol 
	
	END   
	
	ELSE if(@CostCenterID=400 and @TypeID=2)  
	begin
		set @Join=''
		if ((@LocationWhere is not null and @LocationWhere!='') or (@DivisionWhere is not null and @DivisionWhere!='') or @Where<>'')
		begin
			set @Join=' inner join com_docccdata dcc with(nolock) on dcc.InvDocDetailsID=a.InvDocDetailsID '
			if (@LocationWhere is not null and @LocationWhere!='')
				set @Where=@Where+' dcc.dcCCNID2 IN ('+@LocationWhere+') and '
			if (@DivisionWhere is not null and @DivisionWhere!='')
				set @Where=@Where+' dcc.dcCCNID1 IN ('+@DivisionWhere+') and '
		end
		SET @SQL=' SELECT distinct VoucherNo,convert(bigint,DocID) DocID FROM INV_DocDetails a WITH(NOLOCK)'+@Join+@Where
		if(@RowCount!=3)
			SET @SQL=@SQL+@SearchOn+ ' like ''%'+@SearchValue+'%'''  
		else
			SET @SQL=@SQL+' lower('+@SearchOn+') '+ @lessthan + ''''+@SearchValue+''''  
		SET @SQL=@SQL+' ORDER BY '+@SearchOn 
		if(@OrderBY<>'')
			SET @SQL=@SQL+' '+@OrderBY
		else
			SET @SQL=@SQL+' asc'
		print(@SQL)
	end
	ELSE if(@CostCenterID=40064 and @TypeID=1)  
	begin
		set @Join=''
		if ((@LocationWhere is not null and @LocationWhere!='') or (@DivisionWhere is not null and @DivisionWhere!=''))
		begin
			set @Join=' inner join com_docccdata dcc with(nolock) on dcc.InvDocDetailsID=a.InvDocDetailsID '
			if (@LocationWhere is not null and @LocationWhere!='')
				set @Where=@Where+' dcc.dcCCNID2 IN ('+@LocationWhere+') and '
			if (@DivisionWhere is not null and @DivisionWhere!='')
				set @Where=@Where+' dcc.dcCCNID1 IN ('+@DivisionWhere+') and '
		end
		set @Join=@Join+' inner join COM_DocTextData e with(nolock) on e.InvDocDetailsID=a.InvDocDetailsID '
		
		SET @SQL=' SELECT distinct '+@Columns+',DocID FROM INV_DocDetails a WITH(NOLOCK)'+@Join+@Where
		if(@RowCount!=3)
			SET @SQL=@SQL+@SearchOn+ ' like ''%'+@SearchValue+'%'''  
		else
			SET @SQL=@SQL+' lower('+@SearchOn+') '+ @lessthan + ''''+@SearchValue+''''  
		SET @SQL=@SQL+' ORDER BY '+@SearchOn + '  asc'
	end
	ELSE if(@CostCenterID=400 and @TypeID=1)  
	begin
		set @Join=''
		if ((@LocationWhere is not null and @LocationWhere!='') or (@DivisionWhere is not null and @DivisionWhere!=''))
		begin
			set @Join=' inner join com_docccdata dcc with(nolock) on dcc.AccDocDetailsID=a.AccDocDetailsID '
			if (@LocationWhere is not null and @LocationWhere!='')
				set @Where=@Where+' dcc.dcCCNID2 IN ('+@LocationWhere+') and '
			if (@DivisionWhere is not null and @DivisionWhere!='')
				set @Where=@Where+' dcc.dcCCNID1 IN ('+@DivisionWhere+') and '
		end
		SET @SQL=' SELECT distinct VoucherNo,DocID FROM ACC_DocDetails a WITH(NOLOCK)'+@Join+@Where
		if(@RowCount!=3)
			SET @SQL=@SQL+@SearchOn+ ' like ''%'+@SearchValue+'%'''  
		else
			SET @SQL=@SQL+' lower('+@SearchOn+') '+ @lessthan + ''''+@SearchValue+''''  
		SET @SQL=@SQL+' ORDER BY '+@SearchOn + '  asc'
	end
	ELSE if(@CostCenterID=42)
	begin  
		SET @SQL=' SELECT distinct SerialNumber,max(SerialProductID) SerialProductID FROM INV_SerialStockProduct a  WITH(NOLOCK)' +@Where+' lower('+@SearchOn+') '+ @lessthan + ''''+@SearchValue+''''  
		
		SET @SQL=@SQL+' group by SerialNumber ORDER BY '+@SearchOn + '  asc'    
	end
	ELSE      
	BEGIN  
		if(@CalcColumns<>'' and (@CostCenterID=2 or @CostCenterID=3))
		BEGIN
			if(@CalcColumns like '%AssignLocs%')
				set @CalcColumns=replace(@CalcColumns,'AssignLocs',(select dbo.fnCom_GetAssignedNodesForUser(50002,@UserID,@RoleID)))
			if(@CalcColumns like '%AssignDivs%')
				set @CalcColumns=replace(@CalcColumns,'AssignDivs',(select dbo.fnCom_GetAssignedNodesForUser(50001,@UserID,@RoleID)))
			if(@CalcColumns like '%AssignDims%')
			BEGIN
				select @PrefValue=Value from @pref 
				where name='Maintain Dimensionwise stock' and isnumeric(Value)=1
	
				set @CalcColumns=replace(@CalcColumns,'AssignDims',(select dbo.fnCom_GetAssignedNodesForUser(@PrefValue,@UserID,@RoleID)))	
			END
			
			SET @SQL='select *,'+@CalcColumns+' from (select '

			if(@RowCount>0)
				SET @SQL=@SQL+'distinct top '+CONVERT(nvarchar,@RowCount)+' convert(BIGINT,a.'+ @Primarycol+') '+@Primarycol+','+@Columns 		
			else
				SET @SQL=@SQL+' a.'+ @Primarycol+','+@Columns 		
		END	
		else
		begin
			if @CostCenterID in (6,113,503,502)
				SET @SQL='select distinct convert(BIGINT,a.'+ @Primarycol+') '+@Primarycol+','+@Columns   
			else if @CostCenterID=200 and @RowCount>0
				SET @SQL='select distinct top '+CONVERT(nvarchar,@RowCount)+' convert(BIGINT,a.'+ @Primarycol+') '+@Primarycol+',a.StaticReportType,a.ParentID,'+@Columns   
			else
				SET @SQL='select distinct convert(BIGINT,a.'+ @Primarycol+') '+@Primarycol+','+@Columns   
		end

		if(@CostCenterID=113)  
			SET @SQL='select  convert(BIGINT,a.'+ @Primarycol+') as NodeID,'+@Columns  
		
		if(@CostCenterID=3)
		begin
			if @TypeID=82 or @TypeID=83
				SET @SQL=@SQL+',e.ptAlpha503,e.ptAlpha504,ptAlpha534,ptAlpha535,ptAlpha536,ptAlpha537'
			SET @SQL=@SQL+',f.FileExtension,f.GUID FileGUID '
		end
		if exists(select value from @pref where name='ListBoxIgnoreSpace' and value='true')
			SET @SQL=@SQL+',replace('+@SearchOn + ','' '','''') abc'
		
		SET @SQL=@SQL+' from '+@Table +' a WITH(NOLOCK) '

		if(@CostCenterID=3) 
		BEGIN 
			if(@FilterQOH=1)
			BEGIN
				SET @SQL=' declare @tab table(Pid int)
					insert into @tab
					SELECT ProductID 
					FROM INV_DocDetails i  WITH(NOLOCK) 
					join COM_DocCCData d  WITH(NOLOCK) on i.InvDocDetailsID=d.InvDocDetailsID 
					where IsQtyIgnored=0 and ' + @QtyWhere + ' i.StatusID in(371,441,369)  and docdate<=floor(convert(float,getdate()))
					group by ProductID
					having round(isnull(sum(UOMConvertedQty*case when vouchertype=1 and statusid in(371,441) then 0 else  VoucherType end),0),2)>0.01
					
				'+@SQL+' join @tab BQ on a.ProductID=BQ.Pid '
			END
			SET @SQL=@SQL+' LEft JOIN INV_ProductExtended E  WITH(NOLOCK) on  E.ProductID=a.ProductID 
							left join COM_Files f WITH(NOLOCK) on FeaturePK=a.ProductID and FeatureID=3 and IsDefaultImage=1  
							LEft JOIN COM_UOM U  WITH(NOLOCK) on  a.UOMID=U.UOMID '  
		END					
		Else if(@CostCenterID=2)  
			SET @SQL=@SQL+' LEft JOIN ACC_AccountsExtended E  WITH(NOLOCK) on  E.AccountID=a.AccountID '
		ELSE IF(@CostCenterID=92)      
			SET @SQL=@SQL+' LEft JOIN ren_propertyExtended E  WITH(NOLOCK) on  E.NodeID=a.NodeID '	
		ELSE IF(@CostCenterID=93)      
			SET @SQL=@SQL+'  LEft JOIN ren_UnitsExtended E  WITH(NOLOCK) on  E.UnitID=a.UnitID '	   
		ELSE IF(@CostCenterID=94)      
			SET @SQL=@SQL+' LEft JOIN ren_TenantExtended E  WITH(NOLOCK) on  E.TenantID=a.TenantID '	 
    		
		if(@CostCenterID in(2,3,16) or (@Join<>'' and @CostCenterID in(92,93,94,95)))
			SET @SQL=@SQL+' LEFT JOIN COM_CCCCData CC with(nolock) ON CC.COSTCENTERID='+CONVERT(NVARCHAR,@CostCenterID)+' AND CC.NODEID=a.'+@Primarycol+@Join       
			
		if(@CostCenterID=7)
		begin
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
					set @Join=@Join+' inner join ADM_UserRoleMap ROLE WITH(NOLOCK) ON A.UserID=ROLE.UserId'
					set @Where=@Where+@RoleWhere+' and '
				end
			end
			SET @SQL=@SQL+@Join
		end
		else if(@CostCenterID=200 and @RoleID!=1 and @UserID!=1)
		begin 
			SET @SQL='DECLARE @UserID INT,@RoleID INT
	declare @TblRID as table(RID INT)
	SET @UserID='+CONVERT(NVARCHAR,@UserID)+'              
	SELECT @RoleID='+CONVERT(NVARCHAR,@RoleID)+'

	insert into @TblRID
	SELECT R.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=0 and (M.ActionType=1 or M.ActionType=0)
	WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)
	union
	SELECT SR.ReportID FROM ADM_ReportsUserMap M with(nolock) inner join ADM_RevenUReports R with(nolock) on R.ReportID=M.ReportID and R.IsGroup=1 and (M.ActionType=1 or M.ActionType=0)
	inner join ADM_RevenUReports SR with(nolock) on SR.lft between R.lft and R.rgt and SR.ReportID>0
	WHERE UserID=@UserID OR RoleID = @RoleID OR GroupID IN (SELECT GID FROM COM_Groups with(nolock) WHERE UserID=@UserID or RoleID=@RoleID)'
	+@SQL
			set @Where=@Where+'
			 ReportID IN 
	(
		select RID from @TblRID
		union
		select G.ReportID
		from @TblRID T
		inner join ADM_RevenUReports C with(nolock) ON T.RID=C.ReportID
		inner join ADM_RevenUReports G with(nolock) ON C.lft between G.lft and G.rgt
		group by G.ReportID
	) and '
		end
		else if(@CostCenterID=6 OR @CostCenterID=86  OR @CostCenterID=89)
		begin
			if(@Join is not null and @Join<>'')
				SET @SQL=@SQL+@Join
		end
		ELSE if (@CostCenterID=83)
		begin
			if(@Join is not null and @Join<>'' and Charindex('@TABLEUSERS',@Join,0)>0)
			begin
				SET @SQL=' DECLARE @TABLEUSERS TABLE(USERNAME NVARCHAR(300),USERID INT) 
				INSERT INTO @TABLEUSERS
				EXEC spCOM_GetUserHierarchy '+convert(varchar,@UserID)+','+convert(varchar,@CostCenterID)+','+convert(varchar,@CostCenterID)+' '+@SQL
				SET @SQL=@SQL+@Join
			end
		end
		
		
		SET @SQL=@SQL+ @Where 
		
		IF(@CostCenterID=6 AND @RoleID!=1)
			SET @SQL=@SQL+' Name<>''ADMIN'' AND '
			
		if(@RowCount=3 and @SearchOldValue=1 and @SelectedValue is not null and @SelectedValue <> '' and @SelectedValue<>'0' and exists(select value from @pref where name='ListBoxIgnoreSpace' and value='true'))  
			SET @SQL=@SQL+' replace('+@SearchOn+','' '','''') like '+  'replace(N''%'+@SearchValue+'%'','' '','''')  escape ''\'' ' 
		else if(@RowCount=3 and @SearchOldValue=1 and @SelectedValue is not null and @SelectedValue <> '' and @SelectedValue<>'0')  
		BEGIN
			if(@SearchOption=3 and @SearchWhere is not null and @SearchWhere<>'')							
			BEGIN
				if(@ignoreSpecial=1 or @ignoreSpecial=2)
					SET @SQL=@SQL+replace(@SearchWhere,'{0}',dbo.fnStr_IgnoreSpecialchar(@SearchValue))
				ELSE
					SET @SQL=@SQL+replace(@SearchWhere,'{0}',@SearchValue) 			
			END	
			ELSE if(@ignoreSpecial=1)
				SET @SQL=@SQL+' dbo.fnStr_IgnoreSpecialchar('+@SearchOn+') like N'+  '''%'+dbo.fnStr_IgnoreSpecialchar(@SearchValue)+'%''  escape ''\'' ' 
			ELSE if(@ignoreSpecial=2)
				SET @SQL=@SQL+' '+@SearchOn+' like N'+  '''%'+dbo.fnStr_IgnoreSpecialchar(@SearchValue)+'%''  escape ''\'' ' 
			ELSE	
				SET @SQL=@SQL+' '+@SearchOn+' like N'+  '''%'+@SearchValue+'%''  escape ''\'' ' 
		END	
		else if(@RowCount<>3 and @CostCenterID<>11 and @SearchOption=1 and exists(select value from @pref where name='ListBoxIgnoreSpace' and value='true'))  
			SET @SQL=@SQL+'  (replace(lower('+@SearchOn+'),'' '','''')  '+ @lessthan + 'replace(N'''+@SearchValue+''','' '',''''))'  	 
		else if (@CostCenterID<>11 and (@RowCount=3 or (@SelectedValue is not null and @SelectedValue <> '' and @SelectedValue<>'0') or @SearchOption=1 ))
		BEGIN
			if(@ignoreSpecial=1 or @ignoreSpecial=2)
				SET @SQL=@SQL+' dbo.fnStr_IgnoreSpecialchar(lower('+@SearchOn+')) '+ @lessthan + ''''+dbo.fnStr_IgnoreSpecialchar(@SearchValue)+'''' 
			ELSE	
				SET @SQL=@SQL+' lower('+@SearchOn+') '+ @lessthan + ''''+@SearchValue+''''  
		END	
		else  if(@CostCenterID<>11)
		BEGIN
		
			if(@SearchWhere is not null and @SearchWhere<>'')							
			BEGIN
				if(@ignoreSpecial=1 or @ignoreSpecial=2)
					SET @SQL=@SQL+replace(@SearchWhere,'{0}',dbo.fnStr_IgnoreSpecialchar(@SearchValue))
				ELSE
					SET @SQL=@SQL+replace(@SearchWhere,'{0}',@SearchValue) 			
			END	
			ELSE if exists(select value from @pref where name='ListBoxIgnoreSpace' and value='true')
				SET @SQL=@SQL+' (replace('+@SearchOn+','' '','''') like '+  'replace(N''%'+@SearchValue+'%'','' '','''')  escape ''\'')'  
			ELSE
			BEGIN
				if(@ignoreSpecial=1)
					SET @SQL=@SQL+' dbo.fnStr_IgnoreSpecialchar('+@SearchOn+') like N'+  '''%'+dbo.fnStr_IgnoreSpecialchar(@SearchValue)+'%''  escape ''\'' '  
				ELSE if(@ignoreSpecial=2)
					SET @SQL=@SQL+' '+@SearchOn+' like N'+  '''%'+dbo.fnStr_IgnoreSpecialchar(@SearchValue)+'%''  escape ''\'' '  
				ELSE
					SET @SQL=@SQL+' '+@SearchOn+' like N'+  '''%'+@SearchValue+'%''  escape ''\'' '  	
			END		
		END
		
		if(@SelectedValue is not null and @SelectedValue <> '' and @SelectedValue<>'0')  
		begin  
			if(@RowCount=3 and @SearchOldValue=1)  
			begin  
				if(@IsMoveUp=1)   
					SET @SQL=@SQL+' and '+ @SearchOn+'<N'''+@SearchOldValuetext+''''  
				else  
					SET @SQL=@SQL+' and '+ @SearchOn+'>N'''+@SearchOldValuetext+''''  
			end  
			else  if(@CostCenterID=2 or @CostCenterID=3)  
				SET @SQL=@SQL+' and a.'+ @Primarycol+'>='+@SelectedValue          
		end  
		 
		if(@CostCenterID<>11 and @SelectedValue is not null and @SelectedValue<>'' and @GroupBy<>'1')   
			set @SQL=@SQL+' or a.'+@Primarycol+'='+@SelectedValue

		if not (@CalcColumns<>'' and (@CostCenterID=2 or @CostCenterID=3) and @RowCount=0)	
		BEGIN
			if (exists(select value from @pref where name='ListBoxIgnoreSpace' and value='true')
				and not (@SelectedValue is not null and @SelectedValue<>''))
				SET @SQL=@SQL+' ORDER BY replace('+@SearchOn + ','' '','''')  '+ @OrderBY 
			else if (@CostCenterID<>11 and @SelectedValue is not null and @SelectedValue <> '' and @SelectedValue<>'0' and (@ignoreSpecial=1 or @ignoreSpecial=2))
			begin		
				if(@ignoreSpecial=1 or @ignoreSpecial=2)
					SET @SQL=@SQL+' ORDER BY '+@SearchOn + ' , '+@Primarycol + '  '+ @OrderBY      
				else	
					SET @SQL=@SQL+' ORDER BY '+@Primarycol + '  '+ @OrderBY      
			end
			else   
				SET @SQL=@SQL+' ORDER BY '+@SearchOn + '  '+ @OrderBY      
		END		
	END      
         
    if(@CostCenterID<>11 and @CostCenterID!=200)
		SET ROWCOUNT @RowCount      
   
    if(@CalcColumns<>'' and (@CostCenterID=2 or @CostCenterID=3))	
		SET @SQL=@SQL+' ) as a ORDER BY '+replace(@SearchOn,'e.','') + '  '+ @OrderBY   
   --Execute statement  
   
   print @SQL    
   Exec sp_executesql @SQL    
      
	if(@RowCount<>3 and exists(select Value from @pref where name='ListBoxCount' and Value='true'))
	BEGIN
		--if(@SelectedValue is not null and @SelectedValue <> '' and @SelectedValue<>'0')
		--	select @i=Charindex('lower(',@SQL,0)
		--else	
		if(@CalcColumns<>'' and (@CostCenterID=2 or @CostCenterID=3))
		BEGIN
			select @i=Charindex('ORDER BY',@SQL,0)
			select @SQL=SUBSTRING(@SQL,0,@i)			
			
			select @i=Charindex('top '+convert(nvarchar,@RowCount),@SQL,0)	
			set @i=@i+len(@RowCount)+4
			select @SQL=SUBSTRING(@SQL,@i,len(@SQL))
	
			set @SQL='select count(*) cnt from (select distinct '+@SQL+' ) as t' 			
		END
		ELSE
		BEGIN
			select @i=Charindex('ORDER BY',@SQL,0)
			select @SQL=SUBSTRING(@SQL,0,@i)
			set @SQL=' select count(*) cnt from ('+@SQL+' ) as t'    
		END	
		print @SQL 
		
		BEGIN TRY  
			Exec sp_executesql @SQL      
		END TRY      
		BEGIN CATCH  	
			SELECT 0
		END CATCH
	END
	
	if(@CostCenterID=3 and @TypeID=82 and @SelectedValue is not null and @SelectedValue <> '' and @SelectedValue<>'0')
	begin
		SET ROWCOUNT 0
		select GUID,FileExtension from COM_Files WITH(NOLOCK) where FeaturePK=@SelectedValue and FeatureID=3 and IsProductImage=1 order by IsDefaultImage desc
		
		select S.GroupName
		,case when L.NodeID is null then S.Val else isnull(LT.LookupName,'') end Name
		,case when L.NodeID is null then '' else L.Name end Val
		,S.ShowinHeader Hdr--,S.* 
		from INV_ProductSpecification S with(nolock)
		left join COM_Lookup L with(nolock) on L.NodeID=S.LookUpVal
		left join COM_LookupTypes LT with(nolock) on LT.NodeID=S.LookUpID
		where S.ProductID=@SelectedValue
		order By S.DisplayOrder
	end
       

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
