USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spINV_GetProductDetails]
	@ProductID [int] = 0,
	@UserID [int] = 1,
	@LangID [int] = 1,
	@RoleID [int] = 0
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY  
SET NOCOUNT ON;  
		--Declaration Section
		DECLARE @HasAccess bit,@SQL nvarchar(max)

		--SP Required Parameters Check
		IF @ProductID =0
		BEGIN
			RAISERROR('-100',16,1)
		END

	    --Getting data from Products main table  
	    SELECT * FROM INV_Product WITH(NOLOCK)    
	    WHERE ProductID=@ProductID  
	     
	    --Getting data from Products extended table  
	    SELECT * FROM  INV_ProductExtended WITH(NOLOCK)   
	    WHERE ProductID=@ProductID 

		--Getting Contacts
		SELECT c.*, l.name as Salutation FROM  COM_Contacts c WITH(NOLOCK) 
		left join com_lookup l WITH(NOLOCK) on l.Nodeid=c.SalutationID
		WHERE FeatureID=3 and  FeaturePK=@ProductID

		--Getting Notes
		SELECT  NoteID, Note, FeatureID, FeaturePK, CompanyGUID, GUID, CreatedBy, convert(datetime,CreatedDate) as CreatedDate, 
		ModifiedBy, ModifiedDate, CostCenterID
		FROM COM_Notes WITH(NOLOCK) 
		WHERE FeatureID=3 and  FeaturePK=@ProductID

		--Getting Files
		EXEC [spCOM_GetAttachments] 3,@ProductID,@UserID

		--Getting product substitutes.  
		if exists (select value from COM_costcenterpreferences with(nolock) where CostCenterID=3 and Name='EnableSubstituteType' and value='True')
		begin
 			SELECT DISTINCT --S.SubstituteGroupID,S.SubstituteGroupName,
 			S.SProductID,P.ProductName,P.ProductCode,S.SubstituteGroupID GroupID,L.Name [Type],ISNULL(S.SNo,0) SNo
			FROM INV_ProductSubstitutes S WITH(NOLOCK)   
			INNER JOIN INV_Product P WITH(NOLOCK) on S.SProductID=P.ProductID
			INNER JOIN COM_Lookup L WITH(NOLOCK) on S.SubstituteGroupID=L.NodeID
			WHERE S.ProductID=@ProductID
		end
		else
		begin
			SELECT DISTINCT S.SubstituteGroupID,S.SubstituteGroupName,
 			P.ProductName, P.ProductID,P.ProductCode,ISNULL(S.SNo,0) SNo
			FROM INV_ProductSubstitutes S WITH(NOLOCK)   
			INNER JOIN INV_Product P WITH(NOLOCK) on S.ProductID=P.ProductID
			WHERE S.SubstituteGroupID  IN (SELECT SubstituteGroupID FROM INV_ProductSubstitutes WITH(NOLOCK) WHERE PRODUCTID in (@ProductID))
			and S.ProductID<>@ProductID
		end

		--Getting Vendors info
		SELECT V.ProductVendorID,V.AccountID,V.Priority,V.LeadTime,A.AccountCode,A.AccountName,B.Barcode,V.MinOrderQty,V.Volume,V.Weight,V.Remarks
		FROM INV_ProductVendors V WITH(NOLOCK)
		INNER JOIN ACC_Accounts A WITH(NOLOCK) ON A.AccountID=V.AccountID
		left JOIN inv_productbarcode B WITH(NOLOCK) ON V.AccountID=B.VenderID and B.ProductID=@ProductID and B.UNITID=0
		WHERE V.ProductID=@ProductID

		--Getting CostCenter data
		SELECT * FROM  COM_CCCCDATA WITH(NOLOCK) 
		WHERE NodeID=@ProductID and CostCenterID = 3 

		--Getting ProductBundles	 
		SELECT B.ProductID,B.Quantity,B.Rate,PRODUCTNAME,LinkType, ProductCode,Remarks ,u.UnitName,b.unit,
		B.ModifierName,b.MinSelect,B.MaxSelect
		FROM [INV_ProductBundles] B WITH(NOLOCK) 
		LEFT JOIN INV_Product WITH(NOLOCK) ON INV_Product.PRODUCTID=B.PRODUCTID
		left join COM_UOM u WITH(NOLOCK) on b.unit =u.UOMID
		where B.[ParentProductID]=@ProductID

		--Getting ProductSerialization
		SELECT * FROM INV_Product WITH(NOLOCK)    
	    WHERE ProductID=@ProductID AND [ProductTypeID]=2	

		--Getting INV_ProductSubItemMap
		select ProductID,GroupName,FldType,LookUpID,Val,ShowinHeader,Name,LookUpVal,DisplayOrder
		from INV_ProductSpecification a WITH(NOLOCK)
		left join com_lookup b WITH(NOLOCK) on a.LookUpVal=b.NodeID
		where ProductID=@ProductID		
		
		-- GET CCCCC MAP DATA
		EXEC [spCOM_GetCCCCMapDetails] 3,@ProductID,@LangID
		
		-- Getting Vehicle Information
		select 1 where 1<>1

		IF((SELECT ISNULL(COUNT(*),0) FROM [COM_UOM] WITH(NOLOCK) WHERE PRODUCTID=@ProductID)>0)			
			SELECT U.*,B.Barcode,B.Barcode_Key FROM COM_UOM U WITH(NOLOCK) 
			LEFT JOIN INV_PRODUCTBARCODE B WITH(NOLOCK) ON B.UNITID=U.UomID WHERE U.PRODUCTID=@ProductID AND U.ISPRODUCTWISE=1
			ORDER BY U.UnitID
		else
			SELECT U.*,B.Barcode,B.Barcode_Key FROM COM_UOM U WITH(NOLOCK) LEFT JOIN INV_PRODUCTBARCODE B WITH(NOLOCK) ON B.UNITID=U.UomID WHERE U.PRODUCTID=@ProductID
					
		select ProductCode,ProductName from INV_PRODUCT WITH(NOLOCK) where 
		 ProductID in (select ParentID from INV_PRODUCT WITH(NOLOCK) where ProductID=@ProductID)
		
		--select * from COM_CostCenterCostCenterMap
		--CCmap display data 
		CREATE TABLE #TBLTEMP(ID INT IDENTITY(1,1) PRIMARY KEY,COSTCENTERID INT,NODEID INT)
		CREATE TABLE #TBLTEMP1 (CostCenterId INT,CostCenterName nvarchar(max),NodeID INT,[Value] NVARCHAR(300),Code nvarchar(300))
		INSERT INTO #TBLTEMP
		SELECT CostCenterID,NODEID  FROM COM_CostCenterCostCenterMap WITH(NOLOCK) WHERE ParentCostCenterID=3 AND ParentNodeID=@ProductID
		DECLARE @COUNT INT,@I INT,@TABLENAME NVARCHAR(300), @CCID INT,@NODEID INT,@FEATURENAME NVARCHAR(300), @IsGroup bit
		SELECT @I=1,@COUNT=COUNT(*) FROM #TBLTEMP WITH(NOLOCK)
		WHILE @I<=@COUNT
		BEGIN
			SELECT @NODEID=NODEID,@CCID=CostCenterId FROM #TBLTEMP WITH(NOLOCK) WHERE ID=@I
			SELECT @FEATURENAME=NAME,@TABLENAME=TABLENAME FROM ADM_FEATURES WITH(NOLOCK) WHERE FEATUREID =@CCID 
		
			--IF @CCID>50000
			if(@CCID=7)
				SET @SQL='if exists (select UserID FROM '+@TABLENAME +' with(nolock) 
									WHERE UserID='+CONVERT(VARCHAR,@NODEID) +')
							INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',UserID NODEID,UserName NAME, UserName FROM '+@TABLENAME +' with(nolock) 
							WHERE UserID='+CONVERT(VARCHAR,@NODEID) +'' 
			else 
				SET @SQL='if exists (select NodeID FROM '+@TABLENAME +' WITH(NOLOCK)
									WHERE NODEID='+CONVERT(VARCHAR,@NODEID) +' and IsGroup=0)
							INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',NODEID,NAME,Code FROM '+@TABLENAME +' WITH(NOLOCK)
							WHERE NODEID='+CONVERT(VARCHAR,@NODEID) +'
						 else
							INSERT INTO #TBLTEMP1 SELECT '+CONVERT(VARCHAR,@CCID)+','''+@FEATURENAME+''',NODEID,NAME,Code FROM '+@TABLENAME +' WITH(NOLOCK)
							WHERE ParentID='+CONVERT(VARCHAR,@NODEID) 
					     
			--print(@SQL)
			 EXEC (@SQL)
			SET @I=@I+1
		END
		
		SELECT * FROM #TBLTEMP1 WITH(NOLOCK)
		DROP TABLE #TBLTEMP1
		DROP TABLE #TBLTEMP 
		
		--WorkFlow
		EXEC spCOM_CheckCostCentetWFApprove 3,@ProductID,@UserID,@RoleID

		
		SET @FEATURENAME=''
		SET @CCID=0
		SELECT @CCID=ISNULL(VALUE,0) FROM [COM_CostCenterPreferences] WITH(NOLOCK)  WHERE NAME='BinsDimension'
		IF @CCID>0 
		BEGIN
			--To get costcenter table name  
			SELECT @FEATURENAME=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@CCID 
			
			SET @SQL='declare @Binused table(BinNODEID INT,isUsed INT)
			insert into @Binused
			SELECT M.BinNODEID,count(b.BinID) 
			FROM [INV_ProductBins] M WITH(NOLOCK)
			LEFT JOIN INV_BinDetails b WITH(NOLOCK) ON b.BinID=M.BinNODEID 
			WHERE COSTCENTERID=3 AND M.NodeID='+convert(nvarchar,@ProductID) 
			SET @SQL=@SQL+' group by M.BinNODEID,b.BinID'
			
			SET @SQL=@SQL+' SELECT M.*,C.Name,l.name LocationText,d.name DivisionText,b.isUsed'			
			
			set @NODEID=0
			select @NODEID=[Value] from [ADM_GlobalPreferences] WITH(NOLOCK)
			where Name='DimensionwiseBins' and isnumeric([Value])=1
			if(@NODEID>50000)
			BEGIN
				SELECT @TABLENAME=TableName FROM ADM_Features WITH(NOLOCK) WHERE FeatureID=@NODEID  
				SET @SQL=@SQL+',t.name DimText FROM [INV_ProductBins] M WITH(NOLOCK)
				LEFT JOIN '+@FEATURENAME+' C WITH(NOLOCK) ON C.NODEID=M.BinNODEID   
				LEFT JOIN com_location l WITH(NOLOCK) ON l.NODEID=M.location 
				LEFT JOIN com_division d WITH(NOLOCK) ON d.NODEID=M.division
				LEFT JOIN @Binused b ON b.BinNODEID=M.BinNODEID 
				LEFT JOIN '+@TABLENAME+' t WITH(NOLOCK) ON t.NODEID=M.DimNodeID and M.DimCCID='+convert(nvarchar,@NODEID) 
			END	
			ELSE			
				SET @SQL=@SQL+' FROM [INV_ProductBins] M WITH(NOLOCK)
				LEFT JOIN '+@FEATURENAME+' C WITH(NOLOCK) ON C.NODEID=M.BinNODEID   
				LEFT JOIN com_location l WITH(NOLOCK) ON l.NODEID=M.location 
				LEFT JOIN com_division d WITH(NOLOCK) ON d.NODEID=M.division
				LEFT JOIN @Binused b ON b.BinNODEID=M.BinNODEID '

			SET @SQL=@SQL+' WHERE COSTCENTERID=3 AND M.NodeID='+convert(nvarchar,@ProductID) 
			print @SQL
			EXEC(@SQL)    
		END
		ELSE
			SELECT 1 WHERE 1<>1
			
		SELECT * FROM [INV_ProductTestcases] WITH(NOLOCK) WHERE ProductID=@ProductID
		
		--History Details
		select H.HistoryID,H.HistoryCCID CCID,H.HistoryNodeID,convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate,H.Remarks
		from COM_HistoryDetails H with(nolock) 
		where H.CostCenterID=3 and H.NodeID=@ProductID and H.HistoryCCID>0
		order by FromDate,H.HistoryID
		
		--Status Details
		select StatusMapID,CostCenterID,[Status],convert(datetime,FromDate) FromDate,convert(datetime,ToDate) ToDate
		from [COM_CostCenterStatusMap] with(nolock)
		where CostCenterID=3 and NodeID=@ProductID
		order by FromDate,ToDate


		

		Declare @WID INT,@Userlevel int,@StatusID int,@Level int,@canApprove bit,@canEdit bit,@Type int,@escDays int,@CreatedDate datetime
		SELECT @StatusID=StatusID,@WID=WorkFlowID,@Level=WorkFlowLevel,@CreatedDate=CONVERT(datetime,createdDate)
		FROM INV_Product WITH(NOLOCK) where  ProductID=@ProductID
		 
		
		if(@WID is not null and @WID>0)  
		BEGIN  
			SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow]   WITH(NOLOCK)   
			where WorkFlowID=@WID and  UserID =@UserID

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow]  WITH(NOLOCK)    
				where WorkFlowID=@WID and  RoleID =@RoleID

			if(@Userlevel is null )       
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.UserID=@UserID and WorkFlowID=@WID

			if(@Userlevel is null )  
				SELECT @Userlevel=LevelID,@Type=[type] FROM [COM_WorkFlow] W WITH(NOLOCK)
				JOIN COM_Groups G WITH(NOLOCK) on w.GroupID=g.GID     
				where g.RoleID =@RoleID and WorkFlowID=@WID
			
			if(@Userlevel is null )  	
				SELECT @Type=[type] FROM [COM_WorkFlow] WITH(NOLOCK) where WorkFlowID=@WID
		end 
     
		set @canEdit=1  
       
		if(@StatusID =1002)  
		begin  
			if(@Userlevel is not null and  @Level is not null and @Userlevel<@level)  
			begin  
				set @canEdit=0   
			end    
		end
		ELSE if(@StatusID=1003)
		BEGIN
		    if(@Userlevel is not null and  @Level is not null and @Userlevel<@level)  
			begin  
				set @canEdit=1
			end
			ELSE
				set @canEdit=0
		END
     
		if(@StatusID=1001 or @StatusID=1002)  
		begin    
			if(@Userlevel is not null and  @Level is not null and @Userlevel>@level)  
			begin
				if(@Type=1 or @Level+1=@Userlevel)
					set @canApprove=1   
				ELSE
				BEGIN
					if exists(select EscDays FROM [COM_WorkFlow]
					where workflowid=@WID and ApprovalMandatory=1 and LevelID<@Userlevel and LevelID>@Level)
						set @canApprove=0
					ELSE
					BEGIN	
						select @escDays=sum(escdays) from (select max(escdays) escdays from [COM_WorkFlow] WITH(NOLOCK) 
						where workflowid=@WID and LevelID<@Userlevel and LevelID>@Level
						group by LevelID) as t
						 
						set @CreatedDate=dateadd("d",@escDays,@CreatedDate)
						
						select @escDays=sum(escdays) from (select max(eschours) escdays from [COM_WorkFlow] WITH(NOLOCK) 
						where workflowid=@WID and LevelID<@Userlevel and LevelID>@Level
						group by LevelID) as t
						
						set @CreatedDate=dateadd("HH",@escDays,@CreatedDate)
						
						if (@CreatedDate<getdate())
							set @canApprove=1   
						ELSE
							set @canApprove=0
					END	
				END	
			end   
			else  
				set @canApprove= 0   
		end  
		else  
			set @canApprove= 0   

		IF @WID is not null and @WID>0
		begin

			
			select @canEdit canEdit,@canApprove canApprove

			SELECT CONVERT(DATETIME, A.CreatedDate) Date,A.WorkFlowLevel,
			(SELECT TOP 1 LevelName FROM COM_WorkFlow L with(nolock) WHERE L.WorkFlowID=@WID AND L.LevelID=A.WorkFlowLevel) LevelName,
			A.CreatedBy,A.StatusID,S.Status,A.Remarks,U.FirstName,U.LastName
			FROM COM_Approvals A with(nolock),COM_Status S with(nolock),ADM_Users U with(nolock)
			WHERE A.RowType=1 AND S.StatusID=A.StatusID AND CCID=3 AND CCNodeID=@ProductID AND A.USERID=U.USERID
			ORDER BY A.CreatedDate
			
			select @WID WID,levelID,LevelName from COM_WorkFlow with(nolock) 
			where WorkFlowID=@WID
			group by levelID,LevelName

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
