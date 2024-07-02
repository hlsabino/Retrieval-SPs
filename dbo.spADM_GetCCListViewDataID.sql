USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetCCListViewDataID]
	@CostCenterID [int] = 0,
	@ListViewTypeID [int],
	@Names [nvarchar](max),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON

			--Declaration Section
			DECLARE @ColumnName varchar(50),@ListViewID int
			Declare @Table nvarchar(50),@Primarycol varchar(50),@SQL nvarchar(max)
  
			--Check for manadatory paramters
			if(@CostCenterID=0)
			BEGIN
				 RAISERROR('-100',16,1)
			END
			
			--setting Primary Column			
			if(@CostCenterID=3)
				SET @Primarycol='ProductID'
			ELSE IF(@CostCenterID=2)
				SET @Primarycol='AccountID'
			ELSE IF(@CostCenterID=11)
				SET @Primarycol='UOMID'
			ELSE IF(@CostCenterID=12)
				SET @Primarycol='CurrencyID'
			ELSE IF(@CostCenterID=81)
				SET @Primarycol='ContractTemplID'
			ELSE IF(@CostCenterID=71)
				SET @Primarycol='ResourceID'
			ELSE IF(@CostCenterID=65)
				SET @Primarycol='ContactID'	
			ELSE IF(@CostCenterID=83)
				SET @Primarycol='CustomerID'
			ELSE IF(@CostCenterID=200)
				SET @Primarycol='ReportID'
			ELSE IF(@CostCenterID=7)
				SET @Primarycol='UserID'
			ELSE
				SET @Primarycol='NodeID'

			--Getting TableName of CostCenter
			SELECT @Table=TableName FROM ADM_Features  WITH(NOLOCK) WHERE FeatureID=@CostCenterID
			 
			IF(@ListViewTypeID = 0)
			BEGIN	
				SELECT @ListViewID=[ListViewID] from ADM_ListView WITH(NOLOCK) 
				where CostCenterID=@CostCenterID and UserID=@UserID and IsUserDefined=1 and ListViewTypeID is null
						

				IF(@ListViewID IS NULL)
					SELECT @ListViewID=[ListViewID] from ADM_ListView WITH(NOLOCK) 
					where CostCenterID=@CostCenterID and IsUserDefined=0 and ListViewTypeID is null
			END
			ELSE
			BEGIN	
		 
				SELECT @ListViewID=[ListViewID] from ADM_ListView WITH(NOLOCK) 
				where CostCenterID=@CostCenterID and ListViewTypeID =@ListViewTypeID
					
		 	END


			--Getting FIRST COLUMN IN LIST
			SET @ColumnName=(SELECT Top 1 SysColumnName FROM ADM_CostCenterDef A WITH(NOLOCK)
							JOIN ADM_ListViewColumns B WITH(NOLOCK) ON A.CostCenterColID=B.CostCenterColID 
							WHERE B.ListViewID= @ListViewID and ColumnType=1
							ORDER BY B.ColumnOrder)

			--Prepare query	
			SET @SQL='select '+ @Primarycol+' AS NodeID ,'+@ColumnName+' from '+@Table +'  WITH(NOLOCK) where '+@ColumnName+ ' in ( '''+@Names+''')'

		 	--Execute statement
			Exec sp_executesql @SQL
			 

 
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
