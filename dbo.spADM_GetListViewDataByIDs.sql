USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetListViewDataByIDs]
	@Data [nvarchar](max),
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY
SET NOCOUNT ON

			--Declaration Section
			DECLARE @ColumnName varchar(50),@ListViewID int,@CostCenterID int=0,@ListViewTypeID INT,@NodeIDs nvarchar(MAX)
			Declare @Table nvarchar(50),@Primarycol varchar(50),@SQL nvarchar(max),@xml xml,@I int,@Cnt int,@colID INT
			
			declare @tbData TABLE(NodeID INT,Value NVARCHAR(MAX),DBColumnID INT,TypeID int)

			set @xml=@Data
			declare @tblList TABLE(ID int identity(1,1),CCID int,TypeID int,NodeIDs NVARCHAR(MAX),DBColumnID INT)      
			INSERT INTO @tblList    
			SELECT X.value('@CCID','int'),X.value('@TypeID','int'),X.value('@NodeID','nvarchar(MAX)'),X.value('@DBColumnID','INT')
			from @xml.nodes('/XML/Row') as Data(X)    
			SELECT @I=0,@Cnt=COUNT(ID) FROM @tblList

			WHILE(@I<@Cnt)      
			BEGIN    
				SET @I=@I+1     
				SELECT @CostCenterID=CCID,@ListViewTypeID=TypeID,@NodeIDs=NodeIDs,@colID=DBColumnID  FROM @tblList WHERE ID=@I      
				set @ListViewID=null
				--setting Primary Column			
				if(@CostCenterID=3)
					SET @Primarycol='ProductID'
				ELSE IF(@CostCenterID=2)
					SET @Primarycol='AccountID'
				ELSE IF(@CostCenterID=101)
					SET @Primarycol='BudgetDefID'
				ELSE IF(@CostCenterID=11)
					SET @Primarycol='UOMID'
				ELSE IF(@CostCenterID=12)
					SET @Primarycol='CurrencyID'
				ELSE IF(@CostCenterID=81)
					SET @Primarycol='ContractTemplID'
				ELSE IF(@CostCenterID=16)
					SET @Primarycol='BatchID'
				ELSE IF(@CostCenterID=71)
					SET @Primarycol='ResourceID'
				ELSE IF(@CostCenterID=72)
					SET @Primarycol='AssetID'
				ELSE IF(@CostCenterID=65)
					SET @Primarycol='ContactID'	
				ELSE IF(@CostCenterID=83)
					SET @Primarycol='CustomerID'
				ELSE IF(@CostCenterID=88)
					SET @Primarycol='CampaignID'
				ELSE IF(@CostCenterID=84)
					SET @Primarycol='SvcContractID'
				ELSE IF(@CostCenterID=86)
					SET @Primarycol='LeadID'
				ELSE IF(@CostCenterID=73)
					SET @Primarycol='CaseID'
				ELSE IF(@CostCenterID=81)
					SET @Primarycol='ContractTemplID'
				ELSE IF(@CostCenterID=89)
					SET @Primarycol='OpportunityID'
				ELSE IF(@CostCenterID=113)
					SET @Primarycol='StatusID'
				ELSE IF(@CostCenterID=144)
					SET @Primarycol='ActivityID'
				ELSE IF(@CostCenterID=115)
					SET @Primarycol='ProductMapID'
				ELSE IF(@CostCenterID=119)
					SET @Primarycol='CampaignResponseID'
				ELSE IF(@CostCenterID=200)
					SET @Primarycol='ReportID'
				ELSE IF(@CostCenterID=7)
					SET @Primarycol='UserID'
				ELSE IF(@CostCenterID=76)
					SET @Primarycol='BOMID'
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

					IF(@ListViewID IS NULL)
						SELECT @ListViewID=[ListViewID] from ADM_ListView WITH(NOLOCK) 
						where CostCenterID=@CostCenterID and IsUserDefined=0 
				END
				ELSE
				BEGIN	
			 
					SELECT @ListViewID=[ListViewID] from ADM_ListView WITH(NOLOCK) 
					where CostCenterID=@CostCenterID and ListViewTypeID =@ListViewTypeID
						
		 		END

print @ListViewID
				--Getting FIRST COLUMN IN LIST
				SET @ColumnName=(SELECT Top 1 SysColumnName FROM ADM_CostCenterDef A WITH(NOLOCK)
								JOIN ADM_ListViewColumns B WITH(NOLOCK) ON A.CostCenterColID=B.CostCenterColID 
								WHERE B.ListViewID= @ListViewID and ColumnType=1
								ORDER BY B.ColumnOrder)

				--Prepare query	
				SET @SQL='select '+ @Primarycol+' AS NodeID ,'+@ColumnName+','+convert(nvarchar,@colID)+' ,'+convert(nvarchar,@ListViewTypeID)+' from '+@Table +'  WITH(NOLOCK) where '+@Primarycol+ ' in ( '+@NodeIDs+')'

				print @SQL
				insert into @tbData
				Exec(@SQL)
				 
			END 
			
			select * from @tbData

 
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
