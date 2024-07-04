USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetSelectedDocs]
	@FromDate [datetime],
	@ToDate [datetime],
	@CostCenterID [int],
	@IsVoucherWise [bit],
	@prefix [nvarchar](200),
	@From [int],
	@To [int],
	@where [nvarchar](max),
	@isResave [bit],
	@UserName [nvarchar](200),
	@UserID [int],
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
       
BEGIN TRY        
SET NOCOUNT ON;      

	declare @sql nvarchar(max),@IsInventory bit,@UserWise bit,@table nvarchar(50) ,@ID nvarchar(50) 
	
	if(@CostCenterID=0)
		set @IsInventory=0
	else
		select @IsInventory=IsInventory from adm_documenttypes with(nolock) 
		where CostCenterID=@CostCenterID
	
	SET @UserWise=dbo.fnCOM_HasAccess(@RoleID,43,137)

	IF @CostCenterID=95
	BEGIN
		if exists(select name from sys.tables where name='REN_CONTRACT')
		begin
			if(@IsVoucherWise=0)
			BEGIN
				set @sql='SELECT ContractID DocID,95 CostCenterID,CONVERT(DATETIME,CONTRACTDATE) DocDate,
				CONTRACTPREFIX DOCprefix,convert(INT,CONTRACTNUMBER) CONTRACTNUMBER,SNO VoucherNo,0 RefCCID,0 RefNodeid
				FROM REN_CONTRACT with(nolock) 
				WHERE RefContractID=0 AND CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' AND CONTRACTDATE between convert(float,@FromDate) and convert(float,@ToDate)'  
				
				EXEC sp_executesql @SQL,N'@FromDate datetime,@ToDate datetime',@FromDate,@ToDate
			END
			ELSE
			BEGIN
				set @sql='SELECT ContractID DocID,95 CostCenterID,CONVERT(DATETIME,CONTRACTDATE) DocDate,
				CONTRACTPREFIX DOCprefix,convert(INT,CONTRACTNUMBER) CONTRACTNUMBER,SNO VoucherNo,0 RefCCID,0 RefNodeid
				FROM REN_CONTRACT with(nolock) 
				WHERE RefContractID=0 AND CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' AND SNO between '+CONVERT(NVARCHAR,@From)+' and '+CONVERT(NVARCHAR,@To)
				exec (@sql)
			END
		END
	END
	ELSE
	BEGIN
		if(@IsInventory=1)
		BEGIN	
			set @table='INV_DocDetails'
			set @ID='InvDocDetailsID'
		END
		ELSE
		BEGIN
			set @table='ACC_DocDetails'
			set @ID='ACCDocDetailsID'
		END
		  
		set @sql='select distinct DocID,CostCenterID,DocDate,DOCprefix,convert(INT,docnumber),VoucherNo,RefCCID,RefNodeid 
		from '+@table+' a with(nolock) 
		join ACC_Accounts cr with(nolock) on a.CreditAccount=cr.AccountID
		join ACC_Accounts dr with(nolock) on a.DebitAccount=dr.AccountID
		join COM_DocCCData b with(nolock) on a.'+@ID+'=b.'+@ID
		set @sql =@sql +' where 1=1'
		
		if(@isResave=1)
		begin
			if(@IsInventory=1)
				set @sql =@sql +' and a.statusid=369'
			else
				set @sql =@sql +' and a.statusid in (369,370)'
		end	
		
		if(@CostCenterID>0)
			set @sql=@sql +' and a.CostCenterID ='+convert(nvarchar,@CostCenterID) 
		if(@IsVoucherWise=0)
			set @sql=@sql+' and a.DocDate between '+convert(nvarchar,convert(float,@FromDate))+' and '+convert(nvarchar,convert(float,@ToDate))
		else
			set @sql=@sql+' and a.DOCprefix='''+@prefix+''' and a.docnumber between '+convert(nvarchar,@From)+' and '+convert(nvarchar,@To)
        
        --For AllDocs
        if(@CostCenterID=0)
        BEGIN
			
			set @table='INV_DocDetails'
			set @ID='InvDocDetailsID'
			
			set @sql=@sql+@where +'
			UNION
			select distinct DocID,CostCenterID,DocDate,DOCprefix,convert(INT,docnumber),VoucherNo,RefCCID,RefNodeid 
			from '+@table+' a with(nolock) 
			join ACC_Accounts cr with(nolock) on a.CreditAccount=cr.AccountID
			join ACC_Accounts dr with(nolock) on a.DebitAccount=dr.AccountID
			join COM_DocCCData b with(nolock) on a.'+@ID+'=b.'+@ID
			set @sql =@sql +' where 1=1'
			
			if(@IsVoucherWise=0)
				set @sql=@sql+' and a.DocDate between '+convert(nvarchar,convert(float,@FromDate))+' and '+convert(nvarchar,convert(float,@ToDate))
			else
				set @sql=@sql+' and a.DOCprefix='''+@prefix+''' and a.docnumber between '+convert(nvarchar,@From)+' and '+convert(nvarchar,@To)
        END
        --For AllDocs
        
		if(@where is not null and @where<>'')
			set @sql =@sql+@where
		if(@UserID<>1 and @UserWise=1)
			set @sql =@sql+' and a.CreatedBy ='''+@UserName+''''
		set @sql =@sql+' order by a.DocDate,a.DOCprefix,convert(INT,a.docnumber)'
	END  
	print @sql
	exec(@sql) 
     
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
      
SET NOCOUNT OFF        
RETURN -999         
END CATCH        
--SELECT * FROM ADM_FEATURES WHERE FEATUREID=40034
GO
