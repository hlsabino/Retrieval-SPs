USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetPriceChart]
	@Type [int],
	@PriceChartID [int],
	@Param [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
--  
BEGIN TRY  
SET NOCOUNT ON;

	DECLARE @SQL NVARCHAR(MAX),@GroupBy NVARCHAR(200),@Join NVARCHAR(MAX)

	IF @Type=0 /*TO GET SCREEN DETAILS*/
	BEGIN
		SELECT FEATUREID ID,NAME FROM ADM_FEATURES WITH(NOLOCK) 
		WHERE (FEATUREID>50000 OR FEATUREID=2 OR FEATUREID=3 OR FEATUREID=12) and IsEnabled=1

		SELECT * FROM COM_CCPricesDefn WITH(NOLOCK) WHERE ProfileID=@PriceChartID
		
		SELECT [Value],Name FROM ADM_GlobalPreferences with(nolock) WHERE [Name] in ('Price Chart Rates','Price Chart Widths') 
		
		DECLARE @Decimal INT
		SELECT @Decimal=ISNULL(Value,0) FROM ADM_GlobalPreferences WITH(NOLOCK) WHERE Name='DecimalsinAmount'
		select C.SysColumnName,LR.ResourceData,ISNULL(C.[Decimal],@Decimal) DecimalPoints
		FROM ADM_CostCenterDef C WITH(NOLOCK) 
		JOIN COM_LanguageResources LR WITH(NOLOCK) ON LR.ResourceID=C.ResourceID AND LR.LanguageID=@LangID
		WHERE CostCenterID=3 AND (SysColumnName LIKE 'PurchaseRate%' OR SysColumnName LIKE 'SellingRate%' 
									OR SysColumnName LIKE 'ReorderLevel%' OR SysColumnName LIKE 'ReorderQty%'
									OR SysColumnName LIKE 'MaxInventoryLevel%' OR SysColumnName LIKE 'ReorderMinOrderQty%'	OR SysColumnName LIKE 'ReorderMaxOrderQty%')
		ORDER BY SysColumnName
		--SysColumnName LIKE 'PurchaseRate%' OR SysColumnName LIKE 'SellingRate%' OR SysColumnName LIKE 'ReorderLevel%' OR SysColumnName LIKE 'ReorderQty%')
		
		if @PriceChartID=-100
			set @PriceChartID=0
		select CostCenterID from COM_CCPriceTaxCCDefn WITH(NOLOCK) where DefType=1 and ProfileID=@PriceChartID
		
		SELECT UR.RoleID,U.UserID,dbo.fnCOM_HasAccess(UR.RoleID,40,156) HasAccess
		FROM COM_CCPricesDefn PD WITH(NOLOCK) 
		LEFT JOIN ADM_Users U WITH(NOLOCK) ON U.UserName=PD.CreatedBy
		LEFT JOIN ADM_UserRoleMap UR WITH(NOLOCK) ON UR.UserID=U.UserID
		WHERE PD.ProfileID=@PriceChartID
	END
	ELSE IF @Type=2 /*TO GET PROFILE DATA BY PROFILEID*/
	BEGIN
		if @PriceChartID=-100
			set @PriceChartID=0
		declare @i int,@Cnt int,@CCID int,@TblName nvarchar(50)
		declare @Tbl as table(ID int IDENTITY(1,1),CCID int,TableName nvarchar(50))
		insert into @Tbl
		select D.CostCenterID,F.TableName 
		from COM_CCPriceTaxCCDefn D with(nolock) 
		inner join ADM_Features F with(nolock) ON D.CostCenterID=F.FeatureID
		where DefType=1 and ProfileID=@PriceChartID and D.CostCenterID!=3 and D.CostCenterID!=11
		
		select @i=1,@Cnt=count(*) from @Tbl
		set @SQL=''
		set @Join=''
		while(@i<=@Cnt)
		begin
			select @CCID=CCID,@TblName=TableName from @Tbl where ID=@i						
			if(@CCID=2)
			begin
				set @Join=@Join+' left join '+@TblName+' A with(nolock) on '
				set @Join=@Join+' A.AccountID=T.AccountID'
				set @SQL=@SQL+',A.AccountName'
			end
			else if(@CCID=12)
			begin
				set @Join=@Join+' left join COM_Currency C with(nolock) on C.CurrencyID=T.CurrencyID'
				set @SQL=@SQL+',C.Name Currency'
			end
			else
			begin
				set @Join=@Join+' left join '+@TblName+' D'+convert(nvarchar,(@CCID-50000))+' with(nolock) on '
				set @Join=@Join+' D'+convert(nvarchar,(@CCID-50000))+'.NodeID=T.CCNID'+CONVERT(NVARCHAR,(@CCID-50000))
				set @SQL=@SQL+',D'+convert(nvarchar,(@CCID-50000))+'.Name CC'+CONVERT(NVARCHAR,(@CCID-50000))
			end
			set @i=@i+1
		end
		
		if(@PriceChartID<1)
		begin
			set @Join=@Join+' INNER JOIN COM_CCPricesDefn TD WITH(NOLOCK) ON TD.ProfileID=T.ProfileID and TD.StatusID=1'
			set @SQL=@SQL+',TD.ProfileName'
		end
		SET @SQL='SELECT P.ProductCode,P.ProductName,CONVERT(DATETIME,T.WEF) WEF_DATE'+@SQL+',T.*,U.UnitName UOMName
		,CONVERT(DATETIME,T.TillDate) Till_Date,T.Remarks
		FROM COM_CCPrices T WITH(NOLOCK)			
		INNER JOIN INV_Product P WITH(NOLOCK) ON P.ProductID=T.ProductID
		INNER JOIN COM_CCCCData	CCD WITH(NOLOCK) ON CCD.NodeID=P.ProductID AND CCD.CostCenterID=3		
		LEFT JOIN COM_UOM U WITH(NOLOCK) ON U.UOMID=T.UOMID	
		'+@Join+'
		WHERE 1=1 '+@Param
		if(@PriceChartID>0)
			SET @SQL=@SQL+' AND T.ProfileID='+convert(nvarchar,@PriceChartID)
		
		SET @SQL=@SQL+' ORDER BY ProductName,WEF DESC'
		
		Exec sp_executesql @SQL     
	END	
	ELSE IF @Type=4 /*TO GET CUSTOMIZATION INFO*/
	BEGIN
		SELECT [Value] FROM ADM_GlobalPreferences with(nolock) WHERE [Name]='Price Chart Rates'

		select 'TillDate' SysColumnName,'TillDate' ResourceData
		union all
		select 'Remarks' SysColumnName,'Remarks' ResourceData
		union all 
		select SysColumnName,(SELECT TOP 1 ResourceData FROM COM_LanguageResources with(nolock) WHERE LanguageID=@LangID AND ResourceID=C.ResourceID) ResourceData 
		FROM ADM_CostCenterDef C with(nolock)
		WHERE CostCenterID=3 AND (SysColumnName LIKE 'PurchaseRate%' OR SysColumnName LIKE 'SellingRate%' 
		OR SysColumnName LIKE 'ReorderLevel%' OR SysColumnName LIKE 'ReorderQty'
		OR SysColumnName LIKE 'MaxInventoryLevel%' OR SysColumnName LIKE 'ReorderMinOrderQty%'	OR SysColumnName LIKE 'ReorderMaxOrderQty%'
		)
		ORDER BY SysColumnName
		
		SELECT [Value],Name FROM ADM_GlobalPreferences with(nolock) WHERE [Name] in ('Price Chart Default CC','Price Chart Widths')
		
		SELECT FEATUREID ID,NAME FROM ADM_FEATURES WITH(NOLOCK) 
		WHERE (FEATUREID>50000 OR FEATUREID=2 or FEATUREID=61) and IsEnabled=1
		
		DECLARE @FIELDS NVARCHAR(MAX)
		SELECT @FIELDS=''''+REPLACE([Value],',',''',''')+'''' FROM ADM_GlobalPreferences with(nolock) WHERE [Name]='Price Chart Rates'

		SET @SQL='
		select C.CostCenterColID,C.SysColumnName,LR.ResourceData UserColumnName,UserColumnType,ColumnCostCenterID,ColumnCCListViewTypeID 
		FROM ADM_CostCenterDef C with(nolock)
		JOIN COM_LanguageResources LR with(nolock) ON LR.LanguageID='+CONVERT(NVARCHAR,@LangID)+' AND LR.ResourceID=C.ResourceID
		WHERE C.CostCenterID=40 AND (C.SysColumnName IN ( '+@FIELDS +') OR C.SysColumnName=''WEF'' OR C.SysColumnName=''PriceType'')
		union
		select F.FeatureID,CASE WHEN F.FeatureID>50000 THEN ''CCNID''+CONVERT(NVARCHAR,F.FeatureID-50000) ELSE F.PrimaryKey END,LR.ResourceData UserColumnName,''LISTBOX'',F.FeatureID,
		CASE WHEN F.FeatureID=2 THEN 2 WHEN F.FeatureID=3 THEN 10 ELSE 1 END
		from COM_CCPriceTaxCCDefn Def WITH(NOLOCK)
		join ADM_Features F WITH(NOLOCK) ON F.FeatureID=DEF.CostCenterID 
		JOIN COM_LanguageResources LR with(nolock) ON LR.LanguageID='+CONVERT(NVARCHAR,@LangID)+' AND LR.ResourceID=F.ResourceID
		where Def.DefType=1 and Def.ProfileID='+CONVERT(NVARCHAR,@PriceChartID)+'
		union
		select C.CostCenterColID,C.SysColumnName,''Product_''+LR.ResourceData UserColumnName,UserColumnType,ColumnCostCenterID,ColumnCCListViewTypeID 
		FROM ADM_CostCenterDef C with(nolock)
		JOIN COM_LanguageResources LR with(nolock) ON LR.LanguageID='+CONVERT(NVARCHAR,@LangID)+' AND LR.ResourceID=C.ResourceID
		WHERE C.CostCenterID=3 AND C.ColumnCostCenterID>50000 and C.IsColumnInUse=1
		ORDER BY SysColumnName'
		Exec sp_executesql @SQL     
		
	END
	ELSE IF @Type=5 /*TO DELETE PROFILE*/
	BEGIN
	BEGIN TRANSACTION
		DELETE FROM COM_CCPrices WHERE ProfileID=@PriceChartID
		DELETE FROM COM_CCPriceTaxCCDefn WHERE DefType=1 and ProfileID=@PriceChartID
		DELETE FROM COM_CCPricesDefn WHERE ProfileID=@PriceChartID
		
		--All Used Dimensions in all profiles
		delete from COM_CCPriceTaxCCDefn where DefType=1 and ProfileID=0
		
		insert into COM_CCPriceTaxCCDefn
		select 1,0,CostCenterID,max(convert(int,IsGroupExists))
		from COM_CCPriceTaxCCDefn with(nolock)
		where DefType=1
		group by CostCenterID
	COMMIT TRANSACTION
	END
	ELSE IF @Type=6 /*TO GET DEFAULT PROFILE*/
	BEGIN
		DECLARE @CC NVARCHAR(100)
		CREATE TABLE #TblCCD(ID INT IDENTITY(1,1),CC INT)
		
		SELECT @CC=[Value] FROM ADM_GlobalPreferences with(nolock) WHERE [Name]='Price Chart Default CC'
		
		SELECT @CC DefaultCC
		
		INSERT INTO #TblCCD(CC)
		EXEC SPSplitString @CC,','

	--	select * from @TblCCD
		SET @GroupBy='P.UOMID'
		SET @Join='P.UOMID=T.UOMID'
		
		DECLARE @WHERE NVARCHAR(MAX),@OrderBY NVARCHAR(MAX),@COUNT INT,@J INT
		
		SET @WHERE='P.WEF<='+CONVERT(NVARCHAR,CONVERT(FLOAT,getdate()))+' and ProductID='+CONVERT(NVARCHAR,@PriceChartID)
		
		IF (select count(*) from #TblCCD WHERE CC=2)=0
			SET @WHERE=@WHERE+' AND AccountID=1'
		ELSE
		BEGIN
			SET @GroupBy=@GroupBy+',AccountID'
			SET @Join=@Join+' AND P.AccountID=T.AccountID'
		END
		
		TRUNCATE TABLE #TblCCD
		
		INSERT INTO #TblCCD
		select CONVERT(INT,REPLACE(name,'CCNID',''))
		from sys.columns WITH(NOLOCK)
		where object_id=object_id('COM_CCPrices') and name LIKE 'ccnid%'
		
		SELECT @J=1,@COUNT=COUNT(*) FROM #TblCCD WITH(NOLOCK)
		
		WHILE(@J<@COUNT)
		BEGIN
			SELECT @I=CC FROM #TblCCD WITH(NOLOCK) WHERE ID=@J		
			IF PATINDEX('%'+CONVERT(NVARCHAR,@I)+'%',@CC)=0
				SET @WHERE=@WHERE+' AND CCNID'+convert(nvarchar,@I-50000)+'=1'
			ELSE
			BEGIN
				SET @GroupBy=@GroupBy+',P.CCNID'+convert(nvarchar,@I-50000)
				SET @Join=@Join+' AND P.CCNID'+convert(nvarchar,@I-50000)+'=T.CCNID'+convert(nvarchar,@I-50000)
			END
			SET @J=@J+1	
		END
		
		
		DROP TABLE #TblCCD	
		--SET @SQL='SELECT * FROM COM_CCPrices P WHERE '+@WHERE
		--EXEC(@SQL)
		
		SET @SQL='SELECT *,CONVERT(DATETIME,WEF) WEF_DATE 
		,(SELECT TOP 1 UnitName FROM COM_UOM WITH(NOLOCK) WHERE UOMID=P.UOMID AND P.UOMID>0) UOMName
		,(SELECT TOP 1 AccountName FROM ACC_Accounts WITH(NOLOCK) WHERE AccountID=P.AccountID AND P.AccountID!=0) AccountName
		,CONVERT(DATETIME,TillDate) Till_Date	

		FROM COM_CCPrices P with(nolock) WHERE PriceCCID IN( SELECT MAX(PriceCCID) FROM COM_CCPrices P with(nolock),
		(SELECT MAX(WEF) WEF,'+@GroupBy+' FROM COM_CCPrices P with(nolock) WHERE '+@WHERE+' GROUP BY '+@GroupBy+') T
					WHERE '+@Join+' AND '+@WHERE+' GROUP BY '+@GroupBy+')'
		Exec sp_executesql @SQL     
			
	END
	ELSE IF @Type=7 /* ACTIVE/INACTIVE */
	BEGIN
	BEGIN TRANSACTION
		UPDATE COM_CCPrices 
		SET StatusID=@Param
		WHERE ProfileID=@PriceChartID
		
		UPDATE COM_CCPricesDefn 
		SET StatusID=@Param
		WHERE ProfileID=@PriceChartID
	COMMIT TRANSACTION
	END
	ELSE IF @Type=8 /* GET PRICE CHART DATA */
	BEGIN
		DECLARE @isGrp BIT,@NODEID INT,@UOMID int,@XML xml,@PCType int
		declare @PTCC table(id 	int identity(1,1),CCID int,isgrp bit,tblname nvarchar(200))		
		insert into @PTCC
		SELECT [CostCenterID],[IsGroupExists],b.TableName
		FROM COM_CCPriceTaxCCDefn a WITH(NOLOCK)
		join ADM_Features b WITH(NOLOCK) on a.[CostCenterID]=b.FeatureID
		where [DefType]=1 and ProfileID=0
		
		set @UOMID=charindex('~',@Param)
		set @PCType=charindex('#',@Param)		
		set @XML=substring(@Param,@PCType+1,len(@Param))
		set @PCType=substring(@Param,@UOMID+1,@PCType-(@UOMID+1))
		set @UOMID=substring(@Param,1,@UOMID-1)		
		--select @UOMID,@PCType,@XML
		
		DECLARE @tblCC AS TABLE(ID int identity(1,1),CostCenterID int,NodeId INT)        
	   INSERT INTO @tblCC(CostCenterID,NodeId)        
	   SELECT X.value('@CostCenterID','int'),X.value('@NODEID','INT')        
	   FROM @XML.nodes('/XML/Row') as Data(X)   
		
		set @WHERE=''
		Select @I=MIN(id),@CNT=Max(id) from @PTCC
		set @JOIN=''
		while(@I<=@CNT)        
		begin      
			 select @CcID=CCID,@isGrp=isgrp,@tblName=tblname from @PTCC where id=@I
	       
			if(@CcID=2)
				set @CC=' AccountID ='
			ELSE if(@CcID=3)
				set @CC=' ProductID ='	
			--ELSE if(@CcID=12)
			--	set @CC=' CurrencyID ='	
			ELSE  if(@CcID>50000)
				set @CC='CCNID'+convert(nvarchar,@CcID-50000)+'='  
			ELSE
			BEGIN
				set @I=@I+1
				Continue;	
			END
			/* ADIL
			if not exists(select CostCenterID from @tblCC where CostCenterID=@CcID)
			BEGIN
					if exists(select b.CostcenterCOlID from adm_costcenterdef a
					join adm_costcenterdef b on a.CostcenterCOlID=b.LocalReference
					where a.costcenterid=@CostCenterID and b.costcenterid=@CostCenterID and a.syscolumnname='productid'
					and b.ColumnCostCenterID=@CcID)
					BEGIN
						set @SQL='Select @NID='+REPLACE(@CC,'=','')+' from com_CCCCData WITH(NOLOCK) 
						where CostcenterID=3 and NOdeID='+convert(nvarchar,@ProductID)
						EXEC sp_executesql @SQL, N'@NID INT OUTPUT', @NID OUTPUT  
						if(@NID>1)
						 insert into @tblCC(CostCenterID,NodeId)values(@CcID,@NID)
					END
			END*/
			 
			 set @WHERE=@WHERE+' and (' 
			 if (exists(select CostCenterID from @tblCC where CostCenterID=@CcID) or @CcID=3)
			 BEGIN
				if(@CcID=3)
					set @NODEID=@PriceChartID
				ELSE	
					select @NODEID=NodeId from @tblCC where CostCenterID=@CcID			
				if(@isGrp=1)
				BEGIN				
					if(@CcID in(2,3))
					BEGIN
						set @JOIN=@JOIN+' join '+@tblName+' CC'+CONVERT(nvarchar,@I)+' on P.'+@CC+'CC'+CONVERT(nvarchar,@I)+'.'+REPLACE(@CC,'=','')+'
									join '+@tblName+'  CJ'+CONVERT(nvarchar,@I)+' on CJ'+CONVERT(nvarchar,@I)+'.lft between CC'+CONVERT(nvarchar,@I)+'.lft and CC'+CONVERT(nvarchar,@I)+'.rgt'				
						set @WHERE=@WHERE+'CJ'+CONVERT(nvarchar,@I)+'.'+@CC+convert(nvarchar,@NODEID)+' or '
					END
					ELSE
					BEGIN
						set @JOIN=@JOIN+' join '+@tblName+' CC'+CONVERT(nvarchar,@I)+' on P.'+@CC+'CC'+CONVERT(nvarchar,@I)+'.NodeID
									join '+@tblName+'  CJ'+CONVERT(nvarchar,@I)+' on CJ'+CONVERT(nvarchar,@I)+'.lft between CC'+CONVERT(nvarchar,@I)+'.lft and CC'+CONVERT(nvarchar,@I)+'.rgt'				
						set @WHERE=@WHERE+'CJ'+CONVERT(nvarchar,@I)+'.NODEID='+convert(nvarchar,@NODEID)+' or '
					END
				END
				ELSE
				BEGIN
					set @WHERE=@WHERE+@CC+convert(nvarchar,@NODEID)+' or '
				END         
			 END
			set @WHERE=@WHERE+' p.'+@CC+'1)'	
				
			set @I=@I+1
		END	
			
		set @OrderBY=',p.ProductID Desc,p.AccountID Desc'      
	  
		set @SQL='select top 1 [WEF],[PurchaseRate],[PurchaseRateA],[PurchaseRateB],[PurchaseRateC],[PurchaseRateD]
		  ,[PurchaseRateE],[PurchaseRateF],[PurchaseRateG],[SellingRate],[SellingRateA],[SellingRateB],[SellingRateC]
		  ,[SellingRateD],[SellingRateE],[SellingRateF],[SellingRateG] from COM_CCPrices P WITH(NOLOCK) '+@JOIN+'
			where WEF<='+convert(nvarchar,convert(float,getdate()))+@WHERE
			
   		if(@PCType=1)
			set @SQL=@SQL+' and PriceType in(0,1) '
		else if(@PCType=2)
			set @SQL=@SQL+' and PriceType in(0,2) '
		else if(@PCType=3)
			set @SQL=@SQL+' and PriceType in(0,3) '

		set @SQL=@SQL+' and (UOMID=' +convert(nvarchar,isnull(@UOMID,1))+' or UOMID=1)   order by WEF Desc'+@OrderBY+',UOMID Desc'          
		
		select * from inv_product with(nolock) where ProductID=@PriceChartID
		
	   Exec sp_executesql @SQL     
	   
   END
	
-- 
SET NOCOUNT OFF;   
RETURN 1
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
