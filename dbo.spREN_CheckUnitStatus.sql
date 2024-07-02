USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_CheckUnitStatus]
	@UnitID [int] = 0,
	@PropertyID [int] = 0,
	@ContractStartDate [datetime],
	@ContractType [int] = 0,
	@ContractEndDate [datetime],
	@ContractID [int],
	@MultiUnitIDs [nvarchar](max),
	@RenewRefID [int],
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY                       
SET NOCOUNT ON                      
                   
                   
	declare @T1 nvarchar(100),@T2 nvarchar(100),@Sql nvarchar(max)   , @Rent FLOAT,@PropRRA INT,@isvat bit
	declare @PrefValue NVARCHAR(500),@colnames nvarchar(max)   
	declare @dimCid int,@table nvarchar(50),@partCCID int,@RentNodeid int
	declare @ServiceUnitDims int,@ServiceUnitTypes nvarchar(max) 
	             
    select  @PrefValue = Value from COM_CostCenterPreferences   WITH(nolock)  where CostCenterID=95 and  Name = 'StopContifnotrefund'
    
    select  @ServiceUnitDims=Value from COM_CostCenterPreferences   WITH(nolock)  where CostCenterID=95 And Name ='ServiceUnitDims'
	select  @ServiceUnitTypes=Value from COM_CostCenterPreferences   WITH(nolock)  where CostCenterID=95 And Name ='ServiceUnitTypes'
    
	if(@MultiUnitIDs is not null and  @MultiUnitIDs<>'')
		BEGIN                  
			set @Sql ='SELECT RefContractID,UnitID,StatusID,CONVERT(datetime, StartDate) StartDate, CONVERT(datetime, EndDate) EndDate,contractid     FROM '
			
			if(@PrefValue is not null and @PrefValue='true')
				set @Sql =@Sql+' (select a.RefContractID,a.ContractPrefix,a.UnitID,a.StatusID,a.contractid,a.startdate,
				case when  b.contractid is null and a.statusid in(426,427) then 73048
					when a.statusid in(480,481) and a.VacancyDate is not null then a.VacancyDate 
					when a.statusid in(428,465) then a.TerminationDate else a.enddate end enddate
				from ren_contract a
				left join ren_contract b on a.contractid=b.renewrefid and b.statusid<>451
				where a.statusid<>451) as t  '
			else
				set @Sql =@Sql+' (select a.RefContractID,a.ContractPrefix,a.UnitID,a.StatusID,a.contractid,a.startdate,
				case when a.statusid in(480,481) and a.VacancyDate is not null then a.VacancyDate when  a.statusid in(428,465) then a.TerminationDate else a.enddate end enddate
				from ren_contract a WITH(NOLOCK)) as t '
			
			if(@ServiceUnitDims>0 and @ServiceUnitTypes is not null and @ServiceUnitTypes<>'')
				set @Sql =@Sql+' join COM_ccccdata u with(nolock) on u.NodeID=t.contractid '
			
			set @Sql =@Sql+' WHERE ( '''+convert(nvarchar,@ContractStartDate)+'''   between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)      
			or       '''+convert(nvarchar,@ContractEndDate)+'''  between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)
	 		or	CONVERT(datetime, StartDate) between '''+convert(nvarchar,@ContractStartDate)+''' and  '''+convert(nvarchar,@ContractEndDate)+''' 
	 		or CONVERT(datetime, EndDate) between '''+convert(nvarchar,@ContractStartDate)+''' and  '''+convert(nvarchar,@ContractEndDate)+'''  )             
			AND t.UnitID in('+@MultiUnitIDs+') and    t.StatusID not in(477,451) '
			
			if(@ServiceUnitDims>0 and @ServiceUnitTypes is not null and @ServiceUnitTypes<>'')
				set @Sql =@Sql+' and u.CostCenterID=95 and u.CCNID'+convert(nvarchar(max),(@ServiceUnitDims-50000))+' not in('+@ServiceUnitTypes+')'
			
			if(@ContractID>0)
				set @Sql =@Sql+' and t.ContractID<>'+convert(nvarchar,@ContractID)+' and t.RefContractID<>'+convert(nvarchar,@ContractID)			
		END
		ELSE
		BEGIN
			set @Sql='SELECT RefContractID,UnitID,StatusID,CONVERT(datetime, StartDate) StartDate, CONVERT(datetime, EndDate) EndDate,contractid FROM '
			
			if(@PrefValue is not null and @PrefValue='true')
				set @Sql =@Sql+' (select a.RefContractID,a.ContractPrefix,a.UnitID,a.StatusID,a.contractid,a.startdate,
				case when a.contractid='+convert(nvarchar,@RenewRefID)+' then a.enddate
				 when  b.contractid is null and a.statusid in(426,427) then 73048
				 when a.statusid in(480,481) and a.VacancyDate is not null then a.VacancyDate 
					when a.statusid in(428,465) then a.TerminationDate else a.enddate end enddate
				from ren_contract a
				left join ren_contract b on a.contractid=b.renewrefid and b.statusid<>451
				where a.statusid<>451) as t  '
			else
				set @Sql =@Sql+' (select a.RefContractID,a.UnitID,a.StatusID,a.ContractPrefix,a.contractid,a.startdate,
				case when a.statusid in(480,481) and a.VacancyDate is not null then a.VacancyDate when  a.statusid in(428,465) then a.TerminationDate else a.enddate end enddate
				from ren_contract a WITH(NOLOCK)) as t '
			
			if(@ServiceUnitDims>0 and @ServiceUnitTypes is not null and @ServiceUnitTypes<>'')
				set @Sql =@Sql+' join COM_ccccdata u with(nolock) on u.NodeID=t.contractid '
		
			set @Sql =@Sql+' WHERE ( '''+convert(nvarchar,@ContractStartDate)+'''   between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)      
			or       '''+convert(nvarchar,@ContractEndDate)+'''  between CONVERT(datetime, StartDate) and CONVERT(datetime, EndDate)
			or	CONVERT(datetime, StartDate) between '''+convert(nvarchar,@ContractStartDate)+''' and  '''+convert(nvarchar,@ContractEndDate)+''' 
	 		or CONVERT(datetime, EndDate) between '''+convert(nvarchar,@ContractStartDate)+''' and  '''+convert(nvarchar,@ContractEndDate)+'''   )             
			AND t.UnitID = '+convert(nvarchar,@UnitID)+' and    t.StatusID <> 477   and    t.StatusID <> 451   '
			
			if(@ServiceUnitDims>0 and @ServiceUnitTypes is not null and @ServiceUnitTypes<>'')
				set @Sql =@Sql+' and u.CostCenterID=95 and u.CCNID'+convert(nvarchar(max),(@ServiceUnitDims-50000))+' not in('+@ServiceUnitTypes+')'
		
			set @Sql =@Sql+' and t.ContractID<>'+convert(nvarchar,@ContractID )		 		
		END	  
	exec(@Sql)	  
		         
   
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
