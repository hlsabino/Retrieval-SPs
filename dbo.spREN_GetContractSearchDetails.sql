USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetContractSearchDetails]
	@PropertyID [nvarchar](100),
	@UnitID [nvarchar](100),
	@strWhere [nvarchar](max),
	@Dt [datetime] = null,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
      
BEGIN TRY       
SET NOCOUNT ON      

	declare  @str nvarchar(100)

	--set @strWhere=' where  ( T2.TenantID = 6)'
	--set @PropertyID='11'
	--set @UnitID= '27'
	   
		declare @SQL nvarchar(max), @CNT int, @tempSQL nvarchar(max)
		set @CNT=0
		--select @PropertyID,@UnitID
		set @str= '    @CNT bigint output ' 
		set @tempSQL= ' select  @CNT=COUNT(PROPERTYID) FROM REN_CONTRACT T3 
		LEFT JOIN REN_Tenant T2 ON  T3.TenantID=T2.TenantID
		left join REN_TenantExtended t2ext on t2.tenantid=t2ext.tenantid  '
		if (@PropertyID<>'')
			set @tempSQL=@tempSQL+ ' and PropertyID= '+@PropertyID+' '
		if (@UnitID<>'')
			set @tempSQL=@tempSQL+ ' and UnitID= '+@UnitID+' ' 
		if (@strWhere<>'')
			set @tempSQL=@tempSQL+ @strWhere 
		--select (@tempSQL)
		exec sp_executesql  @tempSQL , @str, @CNT output 
		if (@CNT is null)
			set @CNT=0 
   
	if  (@CNT>0)
	BEGIN
		set @SQL='	SELECT 1 RowNo, 0 SNO ,T1.UnitID  UnitID,T0.Name AS Property,T1.Name AS Unit,T2.FirstName AS [Tenant],CONVERT(DATETIME,T3.StartDate) AS [StartDate],
		CONVERT(DATETIME,T3.EndDate) AS EndDate ,  '''' AS ToDate , T3.TotalAmount AS RentAmount , T3.ContractID ContractID, t2ext.alpha1 Remarks,T2.Phone1,T2.Phone2, T2.Profession UIDNo
		FROM REN_Property T0  
		JOIN REN_Contract T3 ON T3.PropertyID=T0.NodeID  AND T3.COSTCENTERID = 95  '
		if (@PropertyID<>'')
			set @SQL=@SQL+ ' and PropertyID='+@PropertyID+' '  
		set @SQL=@SQL +' JOIN REN_Units T1  ON T3.UnitID=T1.UnitID  '
		if (@UnitID<>'')
			set @SQL=@SQL +' and T3.UnitID='+@UnitID+'  '
		set @SQL=@SQL +' 
		JOIN REN_ContractParticulars T4 ON T3.CONTRACTID = T4.CONTRACTID  AND T4.SNO = 1 
		LEFT JOIN REN_Tenant T2 ON  T3.TenantID=T2.TenantID
		left join REN_TenantExtended t2ext on t2.tenantid=t2ext.tenantid
		AND T3.IsGroup <> 1   '
		 if (@strWhere<>'')
			set @SQL=@SQL+  @strWhere+'' 
	END
	else
	BEGIN
		set @SQL=' SELECT 1 RowNo, 0 SNO ,0 UnitID,'''' AS Property,'''' AS Unit,T2.FirstName AS [Tenant],
		null AS [StartDate], null AS EndDate ,  null AS ToDate ,
		 0 AS RentAmount , '''' ContractID, t2ext.alpha1 Remarks,T2.Phone1,T2.Phone2, T2.Profession UIDNo
		FROM   REN_Tenant T2  
		left join REN_TenantExtended t2ext on t2.tenantid=t2ext.tenantid '
		 if (@strWhere<>'')
			set @SQL=@SQL+  @strWhere+'' 
	END
    print (@SQL)
    exec (@SQL)
    
      
SET NOCOUNT OFF;      
RETURN 1      
END TRY      
BEGIN CATCH  
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
