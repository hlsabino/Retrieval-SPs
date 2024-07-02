USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetParticularsScreenDetails]
	@CCID [bigint] = 0,
	@CCNodeID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON

	declare @T1 nvarchar(100),@Dimension nvarchar(100),@Sql nvarchar(max),@dimid INT

	select @Dimension=value from ADM_GlobalPreferences WITH(NOLOCK) 
	where  Name='DepositLinkDimension'
	
	select @T1=TableName from adm_features WITH(NOLOCK) 
	where featureid =@Dimension

	set @Sql ='select NodeID,Name as Particulars from '+@T1+' WITH(NOLOCK) WHERE IsGroup=0 AND
	StatusID IN (SELECT StatusID FROM COM_Status WHERE Status=''Active'' AND [CostCenterID]='+@Dimension+')'
	exec (@Sql)

	select @Dimension=value from ADM_GlobalPreferences WITH(NOLOCK) 
	where  Name='UnitLinkDimension'

	select @T1=TableName from adm_features WITH(NOLOCK) 
	where featureid =@Dimension

	set @Sql ='select NodeID,Name as Type from '+@T1+' WITH(NOLOCK) WHERE IsGroup=0 AND
	StatusID IN (SELECT StatusID FROM COM_Status WHERE Status=''Active'' AND [CostCenterID]='+@Dimension+')'
	exec (@Sql)

	select value from ADM_GlobalPreferences WITH(NOLOCK)
	where Name='DepositLinkDimension'
	
	SELECT Name,Value FROM [COM_CostCenterPreferences] WITH(NOLOCK)
	where ((Name='CrAccListview' OR Name='DrAccListview') AND [CostCenterID]=92)
	or (Name='DimensionWiseContract' AND [CostCenterID]=95)
	
	set @dimid=0
	SELECT @dimid=Value FROM [COM_CostCenterPreferences] WITH(NOLOCK)
	where Name='DimensionWiseContract' AND [CostCenterID]=95
	and isnumeric(Value)=1 and convert(int,Value)>50000
	
	if(@dimid>0)
		SELECT Name from adm_features with(NOLOCK) where featureid=@dimid
	else
		select 1 where 1<>1
	
	SELECT C.CostCenterColID,ResourceData,C.UserColumnName,C.ResourceID,C.SysColumnName,C.UserColumnType,C.ColumnDataType,                              
	C.UserDefaultValue,isnull(C.IsVisible,1) IsVisible,C.ColumnCCListViewTypeID,C.ColumnCostCenterID,uiwidth
	FROM ADM_CostCenterDef c with(nolock) 
	join com_languageresources b with(nolock)  on c.resourceid=b.resourceid
	WHERE COSTCENTERID=95  and SYSCOLUMNNAME like 'CCNID%'
	and SysTableName='REN_ContractParticulars' and b.LanguageID=@LangID
	and IsColumnInUse=1
		
COMMIT TRANSACTION
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
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH  
GO
