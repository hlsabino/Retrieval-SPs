USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetFloorWiseExpiry]
	@PropertyID [int] = 0,
	@Date [datetime],
	@Status [int],
	@StatusDimension [int],
	@SelectTag [nvarchar](max),
	@FromTag [nvarchar](max),
	@WhereCondition [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
    
BEGIN TRY     
SET NOCOUNT ON    
declare @T1 nvarchar(100),@T2 nvarchar(100),@Sql nvarchar(max),@CountSql nvarchar(max),@StatusSelect nvarchar(max)
  
set @T1=(select TableName from adm_features with(nolock) where featureid=(select value from ADM_GlobalPreferences with(nolock) where Name='UnitLinkDimension'))   
if @StatusDimension=0
begin
	set @SelectTag=',LKP.Name StatusName,U.UnitStatus'+@SelectTag
	set @FromTag=' LEFT JOIN COM_LOOKUP LKP with(nolock) ON U.UnitStatus = LKP.NodeID AND (LKP.LookupType = 46 or LKP.LookupType IS NULL)'+@FromTag
	set @StatusSelect='SELECT NodeID,Name,Status,IsDefault FROM COM_Lookup with(nolock) WHERE LookupType=46'
end
else
begin
	select @StatusSelect=TableName from ADM_Features with(nolock) where FeatureID=@StatusDimension
	set @SelectTag=',UCCT.Name StatusName,UCCT.NodeID UnitStatus'+@SelectTag
	set @FromTag=' LEFT JOIN COM_CCCCData UCC with(nolock) ON UCC.NodeID=U.UnitID AND UCC.CostCenterID=93 JOIN '+@StatusSelect+' AS UCCT with(nolock) ON UCCT.NodeID=UCC.CCNID'+convert(nvarchar,@StatusDimension-50000)+@FromTag
	set @StatusSelect='SELECT NodeID,Name FROM '+@StatusSelect+' with(nolock) where IsGroup=0 order by lft'
end

SET @Sql ='SELECT T2.Name AS [Property] ,U.FloorLookUpID,LKf.Name FloorName ,U.Name AS [Unit] ,U.UnitID  UnitID    
,(select top 1 CONVERT(DATETIME,T1.EndDate)  from  REN_Contract T1 with(nolock) where '+convert(nvarchar,convert(float,@Date))+' between T1.StartDate and T1.EndDate and T1.UnitID=U.UnitID AND U.Name is not null and U.Name <>''''  AND T1.IsGroup <> 1) AS [ContractExpiryDate],  
 0 Occupied ,  T2.NodeId AS PropertyId,'  
SET @CountSql='SELECT top 1 count(U.FloorLookUpID) cnt,FloorLookUpID,U.PropertyID '  
if(@T1 is  not null and @T1<>'')  
 SET @Sql =@Sql+' UNTTYPE.Name UnitTypeName  '  
else  
 SET @Sql =@Sql+' '''' UnitTypeName  '  

SET @Sql =@Sql+@SelectTag
  
SET @Sql =@Sql+' FROM REN_Units U with(nolock)
  
INNER JOIN REN_Property T2 with(nolock)  ON U.PropertyID=T2.NodeID   '+@FromTag+'
LEFT JOIN COM_LOOKUP LKf with(nolock) ON U.FloorLookUpID = LKf.NodeID AND (LKf.LookupType = 39 or LKf.LookupType IS NULL)'

SET @CountSql=@CountSql+' FROM REN_Units U with(nolock)   
left JOIN REN_Contract T1 with(nolock) ON T1.UnitID=U.UnitID AND U.Name is not null and U.Name <>''''  AND T1.IsGroup <> 1  
INNER JOIN REN_Property T2 with(nolock)  ON U.PropertyID=T2.NodeID    '+@FromTag+'
LEFT JOIN COM_LOOKUP LKf with(nolock) ON U.FloorLookUpID = LKf.NodeID AND (LKf.LookupType = 39 or LKf.LookupType IS NULL)'  
if(@T1 is  not null and @T1<>'')  
begin  
 SET @Sql =@Sql+' LEFT JOIN '+@T1+' UNTTYPE with(nolock) ON U.NodeID = UNTTYPE.NodeID'  
 SET @CountSql=@CountSql+' LEFT JOIN '+@T1+' UNTTYPE with(nolock) ON U.NodeID = UNTTYPE.NodeID'  
end  
 
 SET @Sql =@Sql+' where U.IsGroup=0 AND U.ContractID=0'  
SET @CountSql=@CountSql+' where U.IsGroup=0 AND U.ContractID=0'  
  
if(isnull(@WhereCondition,'')<>'')
begin
	SET @Sql =@Sql+' and '+@WhereCondition+''  
	SET @CountSql =@CountSql+' and '+@WhereCondition+''  
end
     

if(@PropertyID>0)  
begin  
 SET @Sql =@Sql+' and U.PropertyID='+convert(nvarchar,@PropertyID)  
   SET @CountSql=@CountSql+' and U.PropertyID='+convert(nvarchar,@PropertyID)  
   
end  

if(@Status>0 )  
begin  
	if @StatusDimension=0
	begin
		SET @Sql =@Sql+' and   U.UnitStatus='+convert(nvarchar,@Status)  
		SET @CountSql=@CountSql+' and  U.UnitStatus='+convert(nvarchar,@Status)   
	end
	else
	begin
		SET @Sql =@Sql+' and UCCT.NodeID='+convert(nvarchar,@Status)  
		SET @CountSql=@CountSql+' and UCCT.NodeID='+convert(nvarchar,@Status)   
	end
end  
  
  
SET @Sql =@Sql+' ORDER BY T2.Name,U.FloorLookUpID'  
SET @CountSql=@CountSql+' group by  U.PropertyID,U.FloorLookUpID order by cnt desc'  
EXEC (@Sql)  
print @Sql   
EXEC (@CountSql)  
  
EXEC(@StatusSelect)
  
    
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
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS      
ErrorLine    
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID   
 END    
    
SET NOCOUNT OFF      
RETURN -999       
END CATCH
GO
