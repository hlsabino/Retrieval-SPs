USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetTaxChart]
	@Type [int],
	@TaxChartID [int],
	@Param [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
--  
BEGIN TRY  
SET NOCOUNT ON;

	DECLARE @SQL NVARCHAR(MAX),@Join NVARCHAR(MAX)
	declare @i int,@Cnt int,@CCID int,@TblName nvarchar(50)

	IF @Type=0  /*TO GET SCREEN DETAILS*/
	BEGIN
		SELECT FEATUREID ID,NAME FROM ADM_FEATURES WITH(NOLOCK) 
		WHERE (FEATUREID>50000 OR FEATUREID=2 OR FEATUREID=3) and IsEnabled=1
		ORDER BY FEATUREID

		SELECT FEATUREID ID,NAME FROM ADM_FEATURES WITH(NOLOCK)
		WHERE FEATUREID>40000 AND FEATUREID<50000  
		
		SELECT * FROM COM_CCTaxesDefn WITH(NOLOCK) WHERE ProfileID=@TaxChartID
		
		if @TaxChartID=-100
			set @TaxChartID=0
		select CostCenterID from COM_CCPriceTaxCCDefn WITH(NOLOCK) where DefType=2 and ProfileID=@TaxChartID
		
		SELECT UR.RoleID,U.UserID,dbo.fnCOM_HasAccess(UR.RoleID,45,156) HasAccess
		FROM COM_CCTaxesDefn TD WITH(NOLOCK) 
		LEFT JOIN ADM_Users U WITH(NOLOCK) ON U.UserName=TD.CreatedBy
		LEFT JOIN ADM_UserRoleMap UR WITH(NOLOCK) ON UR.UserID=U.UserID
		WHERE TD.ProfileID=@TaxChartID
		
	END
	ELSE IF @Type=1 /*TO GET COLUMNS OF DOCUMENT*/
	BEGIN
		if @TaxChartID=401
			select convert(INT,substring(name,6,10)) ID,'Field '+substring(name,6,10) ColumnName,convert(int,substring(name,6,10)) [Index]
			from sys.columns with(nolock) where object_id=object_id('COM_DocNumData') and name like 'dcNum%'
			order by [Index]
		else
			SELECT C.CostCenterColID ID,ISNULL(R.ResourceData,C.UserColumnName) ColumnName,replace(C.SysColumnName,'dcNum','') [Index]
			FROM ADM_CostCenterDef C WITH(NOLOCK)
			LEFT JOIN COM_LanguageResources R WITH(NOLOCK) ON R.ResourceID=C.ResourceID AND R.LanguageID=@LangID
			WHERE CostCenterID=@TaxChartID AND SysColumnName LIKE 'dcNum%' AND IsColumnInUse=1
	END
	ELSE IF @Type=2 /*TO GET PROFILE DATA BY PROFILEID*/
	BEGIN
		if @TaxChartID=-100
			set @TaxChartID=0
		declare @Tbl as table(ID int IDENTITY(1,1),CCID int,TableName nvarchar(50))
		insert into @Tbl
		select D.CostCenterID,F.TableName 
		from COM_CCPriceTaxCCDefn D with(nolock) 
		inner join ADM_Features F with(nolock) ON D.CostCenterID=F.FeatureID
		where DefType=2 and ProfileID=@TaxChartID
		
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
			else if(@CCID=3)
			begin
				set @Join=@Join+' left join '+@TblName+' P with(nolock) on '
				set @Join=@Join+' P.ProductID=T.ProductID'
				set @SQL=@SQL+',P.ProductName'
			end
			else
			begin
				set @Join=@Join+' left join '+@TblName+' D'+convert(nvarchar,(@CCID-50000))+' with(nolock) on '
				set @Join=@Join+' D'+convert(nvarchar,(@CCID-50000))+'.NodeID=T.CCNID'+CONVERT(NVARCHAR,(@CCID-50000))
				set @SQL=@SQL+',D'+convert(nvarchar,(@CCID-50000))+'.Name CC'+CONVERT(NVARCHAR,(@CCID-50000))
			end
			set @i=@i+1
		end
		
		if(@TaxChartID<1 and @TaxChartID>-500)
		begin
			set @Join=@Join+' INNER JOIN COM_CCTaxesDefn TD WITH(NOLOCK) ON TD.ProfileID=T.ProfileID and TD.StatusID=1'
			set @SQL=@SQL+',TD.ProfileName'
		end
		
		DECLARE @MessageSQL NVARCHAR(MAX)
		SET @MessageSQL=' UNION
		SELECT T.DocID,D.NAME Doc,T.ColID,''Message'' Col,CONVERT(DATETIME,T.WEF) WEF_DATE'+@SQL+',T.*,CONVERT(DATETIME,T.TillDate) Till_Date
		FROM COM_CCTaxes T WITH(NOLOCK)
		INNER JOIN ADM_FEATURES D WITH(NOLOCK) ON D.FEATUREID=DocID
		'+@Join+'
		WHERE 1=1 AND T.ColID=-1'+@Param
		
		SET @SQL='SELECT T.DocID,D.NAME Doc,T.ColID,
			ISNULL((SELECT TOP 1 ResourceData FROM COM_LanguageResources WITH(NOLOCK) WHERE ResourceID=C.ResourceID AND LanguageID='+convert(nvarchar,@LangID)+'),C.UserColumnName) Col,
			CONVERT(DATETIME,T.WEF) WEF_DATE'+@SQL+',T.*,CONVERT(DATETIME,T.TillDate) Till_Date
		FROM COM_CCTaxes T WITH(NOLOCK)
		INNER JOIN ADM_FEATURES D WITH(NOLOCK) ON D.FEATUREID=DocID
		INNER JOIn ADM_CostCenterDef C WITH(NOLOCK) ON C.CostCenterColID=T.ColID
		'+@Join+'
		WHERE 1=1'+@Param
		if(@TaxChartID>0 or @TaxChartID<-500)
		BEGIN
			SET @SQL=@SQL+' AND T.ProfileID='+convert(nvarchar,@TaxChartID)
			SET @MessageSQL=@MessageSQL+' AND T.ProfileID='+convert(nvarchar,@TaxChartID)
			SET @SQL=@SQL+@MessageSQL
		END
		else
		BEGIN
			SET @SQL=@SQL+@MessageSQL
			SET @SQL=@SQL+' ORDER BY WEF DESC'
		END
		Exec sp_executesql @SQL     
	END
	ELSE IF @Type=5 /*TO DELETE PROFILE*/
	BEGIN
	BEGIN TRANSACTION
		DELETE FROM COM_CCTaxes WHERE ProfileID=@TaxChartID
		DELETE FROM COM_CCPriceTaxCCDefn WHERE DefType=2 and ProfileID=@TaxChartID
		DELETE FROM COM_CCTaxesDefn WHERE ProfileID=@TaxChartID
		
		--All Used Dimensions in all profiles
		delete from COM_CCPriceTaxCCDefn where DefType=2 and ProfileID=0
		
		insert into COM_CCPriceTaxCCDefn
		select 2,0,CostCenterID,max(convert(int,IsGroupExists))
		from COM_CCPriceTaxCCDefn with(nolock)
		where DefType=2
		group by CostCenterID
	COMMIT TRANSACTION
	END
	ELSE IF @Type=7 /* ACTIVE/INACTIVE */
	BEGIN
	BEGIN TRANSACTION
		UPDATE COM_CCTaxes 
		SET StatusID=@Param
		WHERE ProfileID=@TaxChartID
		
		UPDATE COM_CCTaxesDefn 
		SET StatusID=@Param
		WHERE ProfileID=@TaxChartID
	COMMIT TRANSACTION
	END
	ELSE IF @Type=8  /*TO GET DIMENSION PICKED*/
	BEGIN

		if @TaxChartID=-100
			set @TaxChartID=0
		select T.CostCenterID,F.Name from COM_CCPriceTaxCCDefn T WITH(NOLOCK)
		inner join ADM_FEATURES F with(nolock) on T.CostCenterID=F.FeatureID
		where T.DefType=@Param and T.ProfileID=@TaxChartID and T.CostCenterID!=11
		
		declare @Tbl1 as table(ID int IDENTITY(1,1),CCID int,TableName nvarchar(50))
		insert into @Tbl1
		select D.CostCenterID,F.TableName 
		from COM_CCPriceTaxCCDefn D with(nolock) 
		inner join ADM_Features F with(nolock) ON D.CostCenterID=F.FeatureID
		where DefType=@Param and ProfileID=@TaxChartID and D.CostCenterID!=11
		
		if(@Param='1')
			set @Join='COM_CCPrices'
		else
			set @Join='COM_CCTaxes'
		
		select @i=1,@Cnt=count(*) from @Tbl1
		set @SQL=''
		while(@i<=@Cnt)
		begin
			select @CCID=CCID,@TblName=TableName from @Tbl1 where ID=@i						
			if(@CCID=2)
			begin
				set @SQL=' 
				select T.AccountID PK,max(A.AccountName) Name,A.IsGroup from '+@Join+' T with(nolock) inner join acc_accounts A with(nolock) on A.AccountID=T.AccountID
				where ProfileID='+convert(nvarchar,@TaxChartID)+' group by T.AccountID,A.IsGroup having T.AccountID>1'
				Exec sp_executesql @SQL 
			end
			else if(@CCID=3)
			begin
				if(@Param='1')
					select 1 where 1!=1
				else
				begin
					set @SQL='
					select T.ProductID PK,max(A.ProductName) Name,A.IsGroup from '+@Join+'  T with(nolock) inner join inv_product A with(nolock) on A.ProductID=T.ProductID
					where ProfileID='+convert(nvarchar,@TaxChartID)+' group by T.ProductID,A.IsGroup having T.ProductID>1'
					Exec sp_executesql @SQL 
				end
			end
			else if(@CCID=12)
			begin
				set @SQL=' 
				select T.CurrencyID PK,A.Name Name,0 IsGroup from '+@Join+' T with(nolock) inner join COM_Currency A with(nolock) on A.CurrencyID=T.CurrencyID
				where ProfileID='+convert(nvarchar,@TaxChartID)+' group by T.CurrencyID,A.Name having T.CurrencyID>1'
				Exec sp_executesql @SQL 
			end
			else
			begin
				set @SQL='
				select A.NodeID PK,max(A.Name) Name,A.IsGroup from '+@Join+'  T with(nolock) inner join '+@TblName+' A with(nolock) on A.NodeID=T.CCNID'+CONVERT(NVARCHAR,(@CCID-50000))+'
				where ProfileID='+convert(nvarchar,@TaxChartID)+' group by A.NodeID,A.IsGroup having A.NodeID>1'
				Exec sp_executesql @SQL 
			end
			set @i=@i+1
		end

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
