USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCOM_GetParentCodeData]
	@CostCenterID [int],
	@ParentID [int],
	@Code [nvarchar](500) OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY  
SET NOCOUNT ON;    
				declare @PK nvarchar(50),@ColCode nvarchar(50),@TblName nvarchar(50),@tempCode Nvarchar(500) ,@length int
				declare @SQL nvarchar(max),@i int,@cnt int,@Dep int,@tempprnt INT
				declare @tab table(id int identity(1,1),levelno int,clen int)
				set @Code=''
				insert into @tab
				select [LEVELNO],[CodeLength]  FROM COM_CCParentCodeDef
				where [CostCenterID]=@COSTCENTERID
				
				select @i=0,@cnt=COUNT(id) from @tab
				select @TblName=TableName,@PK=PrimaryKey from adm_features with(nolock) where featureid=@CostCenterID
				
				if @ParentID=0
					set @ParentID=1
						
				if @CostCenterID=2
				begin
					set @ColCode='AccountCode'
				end
				else if @CostCenterID=3
				begin
					set @ColCode='ProductCode'
				end
				else if @CostCenterID=16
				begin
					set @PK='BatchID'
					set @ColCode='BatchCode'
				end
				else if @CostCenterID=72
				begin
					set @ColCode='AssetCode'
				end
				else if @CostCenterID=73
				begin
					set @PK='CaseID'
					set @ColCode='CaseNumber'
				end
				else if @CostCenterID=88
				begin
					set @PK='CampaignID'
					set @ColCode='Code'
				end
				else if @CostCenterID=94
				begin
					set @PK='TenantID'
					set @ColCode='TenantCode'
				end
				else
				begin
					if @PK is null or @PK=''
						set @PK='NodeID'
					set @ColCode='Code'
				end
				
				set @SQL='select @Dep=depth from '+@TblName+' with(nolock)'+'where '+@PK+'='+CONVERT(NVARCHAR,@ParentID)
				exec sp_executesql @SQL,N'@Dep NVARCHAR(100) OUTPUT',@Dep OUTPUT
			
				if(@cnt=0)
				BEGIN
					set @SQL='select @Code='+@ColCode+' from '+@TblName+' with(nolock)'+'where '+@PK+'='+CONVERT(NVARCHAR,@ParentID)
					
					exec sp_executesql @SQL,N'@Code NVARCHAR(100) OUTPUT',@Code OUTPUT
				END
				ELSE
				BEGIN				
					while(@Dep>=0)
					BEGIN
						
						set @SQL='select @Code='+@ColCode+' from '+@TblName+' with(nolock)'+'where '+@PK+'='+CONVERT(NVARCHAR,@ParentID)						
						print @SQL
						exec sp_executesql @SQL,N'@Code NVARCHAR(200) OUTPUT',@tempCode OUTPUT
						
						set @SQL='select @ParentID=ParentID from '+@TblName+' with(nolock)'+'where '+@PK+'='+CONVERT(NVARCHAR,@ParentID)						
						exec sp_executesql @SQL,N'@ParentID INT OUTPUT',@ParentID OUTPUT
						
						select @length=clen from @tab where levelno=@Dep
						if(@length=-1)
							set @Code=@tempCode+@Code
						else if(@length>0)
							set @Code=substring(@tempCode,0,@length+1)+@Code
						
						set @Dep=@Dep-1
					END
				END	

    
SET NOCOUNT OFF;     
RETURN 1
END TRY
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
		IF ERROR_NUMBER()=50000  
		BEGIN  
			SELECT 'ERROR' 
		END  
		ELSE
			SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
			FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=1 
			
   
 SET NOCOUNT OFF    
 RETURN -999     
END CATCH
GO
