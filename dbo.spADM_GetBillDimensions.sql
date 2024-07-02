USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetBillDimensions]
	@accids [nvarchar](max),
	@frmdate [datetime],
	@todate [datetime],
	@locID [bigint],
	@DivID [bigint],
	@where [nvarchar](max),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON
BEGIN TRY 
   
declare @DimCCID INT,@DimTable nvarchar(50),@sql nvarchar(max)
 
declare @tabDim table(Dimid bigint,Name nvarchar(max))


set @DimCCID=0
select @DimCCID=value from adm_globalpreferences WITH(NOLOCK) 
where name='Maintain Dimensionwise Bills' and ISNUMERIC(value)=1 and CONVERT(bigint,value)>50000
 
select @DimTable=TableName from ADM_Features WITH(NOLOCK)
where FeatureID=@DimCCID
set @DimCCID=@DimCCID-50000

set @sql='select b.Dcccnid'+convert(nvarchar,@DimCCID)+',c.Name from acc_docdetails a WITH(NOLOCK)
	join COM_DocCCData b WITH(NOLOCK) on a.AccDocDetailsID=b.AccDocDetailsID
	join '+@DimTable+' c WITH(NOLOCK) on c.NODEID=b.Dcccnid'+convert(nvarchar,@DimCCID)+'
	where (CreditAccount  in('+@accids+') or DebitAccount  in('+@accids+')) and docdate>='+convert(nvarchar,convert(float,@frmdate))+
	' and docdate<='+convert(nvarchar,convert(float,@todate))
	set @sql=@sql+@where	
	set @sql=@sql+' and ((DocumentType not in (14,19) and a.StatusID not in(376,447,448,449)) or (DocumentType in (14,19) and a.statusid=370))		
	union
	select b.Dcccnid'+convert(nvarchar,@DimCCID)+',c.Name from acc_docdetails a WITH(NOLOCK)
	join COM_DocCCData b WITH(NOLOCK) on a.InvDocDetailsID=b.InvDocDetailsID
	join '+@DimTable+' c WITH(NOLOCK) on c.NODEID=b.Dcccnid'+convert(nvarchar,@DimCCID)+'
	where (CreditAccount  in('+@accids+') or DebitAccount  in('+@accids+')) and docdate>='+convert(nvarchar,convert(float,@frmdate))+
	' and docdate<='+convert(nvarchar,convert(float,@todate))
	set @sql=@sql+@where	
	set @sql=@sql+' and ((DocumentType not in (14,19) and a.StatusID not in(376,447,448,449)) or (DocumentType in (14,19) and a.statusid=370))		'
print @sql
insert into @tabDim
exec (@sql)

select * from @tabDim
 
		
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
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() AS ErrorNumber, ERROR_PROCEDURE()AS ProcedureName, ERROR_LINE() AS ErrorLine
		FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
