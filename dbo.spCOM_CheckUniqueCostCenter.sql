USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_CheckUniqueCostCenter]
	@CostCenterID [int],
	@NodeID [nvarchar](20),
	@LangID [int]
WITH ENCRYPTION, EXECUTE AS CALLER
AS
declare @SQL nvarchar(max),@TableName nvarchar(200),@UNIQUECNT int,@I int,@PK nvarchar(50),@PKTemp nvarchar(50),@val nvarchar(max),@Exists bit,@IDTemp INT
		,@SysTableName nvarchar(50),@SysColumnName nvarchar(100),@UserColumnName nvarchar(100),@ISUNIQUE int,@ParentID INT
	
	Declare @TEMPUNIQUE TABLE(ID INT identity(1,1),SysTableName NVARCHAR(50),SysColumnName NVARCHAR(50),UserColumnName NVARCHAR(50),ISUNIQUE int)
	
	INSERT INTO @TEMPUNIQUE     
	SELECT CC.SysTableName,CC.SysColumnName,R.RESOURCEDATA,CC.ISUNIQUE FROM ADM_COSTCENTERDEF CC WITH(NOLOCK)
	JOIN COM_LANGUAGERESOURCES R WITH(NOLOCK) ON CC.RESOURCEID = R.RESOURCEID    
	WHERE CC.COSTCENTERID=@CostCenterID AND CC.ISUNIQUE is not null AND CC.ISUNIQUE>=1 and CC.IsColumnInUse=1 and R.LanguageID=@LangID

	select @UNIQUECNT=count(*) from @TEMPUNIQUE
	
	select @TableName=TableName,@PK=PrimaryKey from ADM_Features WiTh(NOLOCK) where FeatureID=@CostCenterID

	SET  @I = 0 
	WHILE @I<@UNIQUECNT
	BEGIN     
		SET @I=@I+1
		SELECT @SysTableName=SysTableName,@SysColumnName=SysColumnName,@UserColumnName=UserColumnName,@ISUNIQUE=ISUNIQUE FROM @TEMPUNIQUE WHERE ID=@I     
		
		--set @ISUNIQUE=2
		
		--set @SQL='select @val='+@SysColumnName+' from '+@SysTableName+' where '+@PK+'='+convert(nvarchar,@NodeID)+' and '+@SysColumnName+' is not null'
		--exec sp_executesql @SQL,N'@val nvarchar(max) output',@val output		
		--select @val
		set @PKTemp=@PK
		
		if @ISUNIQUE=2
		begin
			set @SQL='select @ParentID=ParentID from '+@TableName+' with(nolock) where '+@PK+'='+@NodeID
			exec sp_executesql @SQL,N'@ParentID INT output',@ParentID output

			if @SysTableName='COM_CCCCData'
			begin
				set @SQL='declare @IDTemp INT
				select @IDTemp='+@SysColumnName+' from COM_CCCCData with(nolock) where CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID='+@NodeID+'
				if @IDTemp is not null and exists(select top 1 C.'+@SysColumnName+' from COM_CCCCData C with(nolock) inner join '+@TableName+' G with(nolock) ON G.'+@PK+'=C.NodeID where G.ParentID='+convert(nvarchar,@ParentID)+' and C.CostCenterID='+convert(nvarchar,@CostCenterID)+' and C.NodeID!='+@NodeID+' and C.'+@SysColumnName+'=@IDTemp)
					set @Exists=1
				else
					set @Exists=0'
				exec sp_executesql @SQL,N'@Exists bit output',@Exists output
			end
			else
			begin
				set @SQL='if exists (select '+@SysColumnName+' from '+@SysTableName+' with(nolock) where '+@PKTemp+'='+@NodeID+' and '+@SysColumnName+' is not null and (isnumeric('+@SysColumnName+')=1 or '+@SysColumnName+'!=''''))
and exists (select top 1 S.'+@SysColumnName+' from '+@SysTableName+' S with(nolock) inner join '+@TableName+' G with(nolock) ON G.'+@PK+'=S.'+@PK+'
	where G.ParentID='+convert(nvarchar,@ParentID)+' and S.'+@PKTemp+'!='+@NodeID+' and S.'+@SysColumnName+'=(select '+@SysColumnName+' from '+@SysTableName+' with(nolock) where '+@PKTemp+'='+@NodeID+') )
	set @Exists=1
else
	set @Exists=0'
				print(@SQL)		
				exec sp_executesql @SQL,N'@Exists bit output',@Exists output
			end
		end
		else if @ISUNIQUE=1
		begin
			if @SysTableName='COM_CCCCData'
			begin
				set @SQL='declare @IDTemp INT
				select @IDTemp='+@SysColumnName+' from COM_CCCCData with(nolock) where CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID='+@NodeID+'
				if @IDTemp is not null and exists(select top 1 '+@SysColumnName+' from COM_CCCCData with(nolock) where CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID!='+@NodeID+' and '+@SysColumnName+'=@IDTemp)
					set @Exists=1
				else
					set @Exists=0'
				exec sp_executesql @SQL,N'@Exists bit output',@Exists output
			end
			else if @SysTableName='CRM_Contacts'
			begin
				SET @PKTemp='FeaturePK' 
				set @SQL='if exists (select '+@SysColumnName+' from '+@SysTableName+' with(nolock) where FeatureID='+convert(nvarchar,@CostCenterID)+' and '+@PKTemp+'='+@NodeID+' and '+@SysColumnName+' is not null and (isnumeric('+@SysColumnName+')=1 or '+@SysColumnName+'!=''''))
				and exists (select top 1 '+@SysColumnName+' from '+@SysTableName+' with(nolock) where FeatureID='+convert(nvarchar,@CostCenterID)+' and '+@PKTemp+'!='+@NodeID+' and '+@SysColumnName+'=(select '+@SysColumnName+' from '+@SysTableName+' with(nolock) where FeatureID='+convert(nvarchar,@CostCenterID)+' and '+@PKTemp+'='+@NodeID+') )
					set @Exists=1
				else
					set @Exists=0'
				print(@SQL)		
				exec sp_executesql @SQL,N'@Exists bit output',@Exists output
			end
			else
			begin		
				set @SQL='if exists (select '+@SysColumnName+' from '+@SysTableName+' with(nolock) where '+@PKTemp+'='+@NodeID+' and '+@SysColumnName+' is not null and (isnumeric('+@SysColumnName+')=1 or '+@SysColumnName+'!=''''))
				and exists (select top 1 '+@SysColumnName+' from '+@SysTableName+' with(nolock) where '+@PKTemp+'!='+@NodeID+' and '+@SysColumnName+'=(select '+@SysColumnName+' from '+@SysTableName+' with(nolock) where '+@PKTemp+'='+@NodeID+') )
					set @Exists=1
				else
					set @Exists=0'
				print(@SQL)		
				exec sp_executesql @SQL,N'@Exists bit output',@Exists output
			end
		end
		else if @ISUNIQUE>50000--Dimension Wise
		begin
			set @SQL='declare @CurrDim INT
select @CurrDim=CCNID'+convert(nvarchar,@ISUNIQUE-50000)+' from COM_CCCCData with(nolock) where CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID='+@NodeID

			if @SysTableName='COM_CCCCData'
			begin
				set @SQL=@SQL+'
declare @IDTemp INT
select @IDTemp='+@SysColumnName+' from COM_CCCCData with(nolock) where CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID='+@NodeID+'
if @IDTemp is not null and exists(select top 1 '+@SysColumnName+' from COM_CCCCData with(nolock) where CostCenterID='+convert(nvarchar,@CostCenterID)+' and NodeID!='+@NodeID+' and '+@SysColumnName+'=@IDTemp and CCNID'+convert(nvarchar,@ISUNIQUE-50000)+'=@CurrDim)
	set @Exists=1
else
	set @Exists=0'
				print(@SQL)
				exec sp_executesql @SQL,N'@Exists bit output',@Exists output
			end
			else
			begin
				set @SQL=@SQL+'
if exists (select '+@SysColumnName+' from '+@SysTableName+' with(nolock) where '+@PKTemp+'='+@NodeID+' and '+@SysColumnName+' is not null and (isnumeric('+@SysColumnName+')=1 or '+@SysColumnName+'!=''''))
and exists (select top 1 '+@SysColumnName+' from '+@SysTableName+' P with(nolock) inner join COM_CCCCData PCC with(nolock) on PCC.NodeID=P.'+@PKTemp+'
	where P.'+@PKTemp+'!='+@NodeID+' and PCC.CostCenterID='+convert(nvarchar,@CostCenterID)+' and P.'+@SysColumnName+'=(select '+@SysColumnName+' from '+@SysTableName+' with(nolock) where '+@PKTemp+'='+@NodeID+')
		and PCC.CCNID'+convert(nvarchar,@ISUNIQUE-50000)+'=@CurrDim
)
	set @Exists=1
else
	set @Exists=0'
				print(@SQL)		
				exec sp_executesql @SQL,N'@Exists bit output',@Exists output
			end
		end

		if @Exists=1
		begin
			SELECT @SQL=isnull(@UserColumnName,'')+' '+ErrorMessage+' '+ISNULL((SELECT TOP 1 ResourceData 
			from ADM_Features FA WiTh(NOLOCK) 
			JOIN COM_LanguageResources LR WiTh(NOLOCK) ON LR.ResourceID=FA.ResourceID AND LR.LanguageID=@LangID  
			where FA.FeatureID=@CostCenterID),'') 
			FROM COM_ErrorMessages EM WITH(nolock)
			WHERE EM.ErrorNumber=-142 AND EM.LanguageID=@LangID    
			RAISERROR(@SQL,16,1)
		end
	END


GO
