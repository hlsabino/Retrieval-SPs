USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_GetAddress]
	@CostCenterID [bigint] = 0,
	@NodeID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON		
		
		Declare @CustomQuery1 nvarchar(max),@FeatureName nvarchar(100),@CustomQuery3 nvarchar(max),@i int ,@CNT int,
		@Table nvarchar(100),@TabRef nvarchar(3),@CCID int,@TypeID int,@ColumnName nvarchar(50)
		create table #CustomTable(ID int identity(1,1),CostCenterID int, TypeID int, ColumnName nvarchar(50))
		insert into #CustomTable(CostCenterID, TypeID, ColumnName)
		select ColumnCostCenterID, ColumnCCListViewTypeID, SysColumnName 
		from adm_CostCenterDef WITH(NOLOCK) 
		where CostCenterID=110 and (ColumnCostCenterID>50000 or (ColumnCostCenterID=44 and usercolumntype='LISTBOX' ))

		set @i=1
		set @CustomQuery1=''
		set @CustomQuery3=', '
		select @CNT=count(id) from #CustomTable
		while (@i<=	@CNT)
		begin
		
			select @CCID=CostCenterID,@TypeID=TypeID,@ColumnName=ColumnName from #CustomTable where ID=@i
			if(@CCID=44 and @TypeID>0)
			begin
				set @Table='Com_Lookup'
				set @TabRef='A'+CONVERT(nvarchar,@i) 
				set @CustomQuery1=@CustomQuery1+' left join '+@Table+' '+@TabRef+' WITH(NOLOCK) on '+@TabRef+'.LookupType='+CONVERT(nvarchar,@TypeID) +' 
				and '+@ColumnName+'='+@TabRef+'.NodeID'
				set @CustomQuery3=@CustomQuery3+' '+@TabRef+'.Name as '+@ColumnName+'_Name ,'
			end
			else
			begin
				if exists (select TableName from adm_features WITH(NOLOCK) where FeatureID = @CCID)
				begin
					select @Table=TableName,@FeatureName=FeatureID from adm_features WITH(NOLOCK) where FeatureID = @CCID
					set @TabRef='A'+CONVERT(nvarchar,@i)
					set @CCID=@CCID-50000
		    	 
					if(@CCID>0)
					begin
						set @CustomQuery1=@CustomQuery1+' left join '+@Table+' '+@TabRef+' WITH(NOLOCK) on '+@TabRef+'.NodeID=c.CCNID'+CONVERT(nvarchar,@CCID)
						set @CustomQuery3=@CustomQuery3+' '+@TabRef+'.Name as CCNID'+CONVERT(nvarchar,@CCID)+'_Name ,'
					end
				end
			end
			set @i=@i+1
		end
		
		if(len(@CustomQuery3)>0)
		begin
			set @CustomQuery3=SUBSTRING(@CustomQuery3,0,LEN(@CustomQuery3)-1)
		end

		drop table #CustomTable
		declare @sql nvarchar(max)
		set @sql='
		SELECT c.*'+@CustomQuery3+' FROM  COM_Address c WITH(NOLOCK)  
		'+@CustomQuery1+'
		WHERE c.FeatureID='+convert(nvarchar(300),@CostCenterID)+' and  c.FeaturePK='+convert(nvarchar(300),@NodeID) 
		PRINT @sql
		PRINT substring(@sql,4001,4000)
		exec(@sql)
		
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
