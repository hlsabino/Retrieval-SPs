USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_GetOnlineData]
	@Type [int],
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

	declare @prof  int,@sql nvarchar(max),@TblName nvarchar(50)

	if @Type=1
	begin
		select name,value from adm_globalpreferences WITH(NOLOCK)
		where name in('OnlineProfile','MandOnlineLogin','OnlineLevel1Dim','OnlineSearchFields','OnlineLevel2Dim','OnlineOrderDoc','OnlineRecptDoc','DecimalsinAmount','Date Format',
		'OnlineLogo','OnlineStatDim','OnlinePaymodes','OnlineRefNoFld','OnlinePaymodeFld')
		select CurrencyID,Symbol,Name from COM_Currency WITH(NOLOCK) where CurrencyID=1
	end
	else if(@Type=2)
	begin
		select @prof=value from adm_globalpreferences P WITH(NOLOCK) where name='OnlineLevel1Dim'
		select @TblName=TableName from ADM_Features with(nolock) where FeatureID=@prof
		
		--select * from 
		/*select @sql='select T.NodeID,T.Name,T.IsGroup,T.ParentID,(select top 1 GUID+''.''+FileExtension from com_Files F with(nolock) where F.FeatureID='+convert(nvarchar,@prof)+' and FeaturePK=T.NodeID and IsProductImage=1 order by IsDefaultImage desc) ImgPath
			from '+@TblName+ ' T 
			join COM_Status S on S.StatusID=T.StatusID and S.Status=''Active''
			join (select lft,rgt from com_category where IsGroup=1 and ccAlpha507=''YES'') G on T.lft between G.lft and G.rgt
			where NodeID>0'
			+' order by T.lft'
		exec(@sql)*/
		select @sql='select T.NodeID,T.Name,T.IsGroup,T.ParentID,T.ccAlpha506 SubMenu,T.ccAlpha507 MainMenu,(select top 1 GUID+''.''+FileExtension from com_Files F with(nolock) where F.FeatureID='+convert(nvarchar,@prof)+' and FeaturePK=T.NodeID and IsProductImage=1 order by IsDefaultImage desc) ImgPath
			from '+@TblName+ ' T 
			join COM_Status S on S.StatusID=T.StatusID and S.Status=''Active''
			where NodeID>0'
			+' order by T.lft'
		exec(@sql)
		
		select Name,LogoExt,Address1,Address2,Address3,City,State,Zip,Country,Phone1,Email1,Phone2,Email2
		from pact2c.dbo.adm_company C where DBName=db_name()
		
		SELECT a.[ListViewTypeID] TypeID,D.ResourceData Label,c.SysColumnName SysCol
		from ADM_ListView a WITH(NOLOCK)   
		LEFT JOIN ADM_ListViewColumns b WITH(NOLOCK) on a.ListViewID=b.ListViewID
		LEFT JOIN ADM_CostCenterDef c  WITH(NOLOCK) on c.CostCenterColID=b.CostCenterColID  
		LEFT JOIN COM_LanguageResources D  WITH(NOLOCK) ON D.ResourceID=C.ResourceID AND D.LanguageID=1
		where a.CostCenterID=3 and (a.ListViewTypeID=81 or a.ListViewTypeID=82 or a.ListViewTypeID=83)
		and b.columnType=1 and c.syscolumnName not in ('ptAlpha516','ProductName')
		order by b.ColumnOrder
		--'ptAlpha514','ptAlpha501','ptAlpha502'
	end
	else if(@Type=3)
	begin
		select @prof=Value from adm_globalpreferences WITH(NOLOCK)
		where name='OnlineProfile' and isnumeric(Value)=1
				
		select a.*,(select top 1 GUID+'.'+FileExtension from COM_Files b where a.NodeID=b.FeaturePK   and a.CCID=b.FeatureID and b.IsDefaultImage=1) ImgPath
		from ADM_OnlineProfile a WITH(NOLOCK)
		Order By Sno
		
		set @sql='select P.ProductID,P.ProductCode code,PE.ptAlpha514,PE.ptAlpha515,PE.ptAlpha516
		from ADM_OnlineProfile H with(nolock)
		join INV_Product P with(nolock) on P.ProductID=H.NodeID
		join INV_ProductExtended PE with(nolock) on PE.ProductID=P.ProductID
		where H.ccid=3'
		exec(@sql)
	end
		
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
