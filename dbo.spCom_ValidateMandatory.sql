USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_ValidateMandatory]
	@CostCenterID [bigint] = 0,
	@NodeID [bigint],
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
SET NOCOUNT ON    


		Declare @Srccol nvarchar(50),@TableName nvarchar(50),@i int,@ctn int
		Declare @sql nvarchar(max),@Val nvarchar(max),@PrimCol nvarchar(max),@FeatName nvarchar(max)
		
		select @PrimCol=PrimaryKey,@FeatName=Name from ADM_Features where FeatureID=@CostCenterID

		declare @tab table(id bigint identity(1,1),Srccol nvarchar(50), TblName nvarchar(50),RName nvarchar(200),ColType nvarchar(200))   
		insert into @tab
		SELECT B.SysColumnName,B.SysTableName,L.ResourceData,ColumnDataType FROM ADM_CostCenterDef B with(nolock)
		left JOIN COM_LanguageResources L with(nolock) ON L.ResourceID=B.ResourceID  and L.LanguageID=@LangID  
		WHERE B.CostCenterID=@CostCenterID  and B.IsMandatory=1 and B.SysColumnName not like '%ccnid%'
		
		set @i=0
		select @ctn=COUNT(id) from @tab
		while(@i<@ctn)
		BEGIN
			set @i=@i+1
			SELECT @Srccol=Srccol,@TableName=TblName from @tab where id=@i
			set @Val=''
			set @sql='select @Val='+@Srccol +' from '+@TableName
			
			set @sql=@sql+' with(nolock) where '+@PrimCol+'='+convert(nvarchar,@NodeID)
			EXEC sp_executesql @sql,N'@Val nvarchar(max) OUTPUT',@Val output
			
			if (exists(select ColType from @tab where id=@i and ColType='float') and ISNUMERIC(@Val)=1 and CONVERT(float,@Val)=0)
				set @Val=''
				
			if(@Val='' or @Val is null)
			BEGIN
				  SELECT RName+' Mandatory to save '+@FeatName ErrorMessage, RName+'Mandatory'  AS ServerMessage
				  from @tab where id=@i      
				  				  
				  return -999 
			END
		END
		 
    
SET NOCOUNT OFF;    
GO
