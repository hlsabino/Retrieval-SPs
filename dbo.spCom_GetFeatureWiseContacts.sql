USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCom_GetFeatureWiseContacts]
	@CostCenterID [int] = 0,
	@NodeID [int] = 0,
	@ContactType [int] = 0,
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY	
SET NOCOUNT ON		
		
		Declare @CustomQuery1 nvarchar(max),@FeatureName nvarchar(100),@CustomQuery3 nvarchar(max),@i int ,@CNT int,
		@Table nvarchar(100),@TabRef nvarchar(3),@CCID int,@TypeID int,@ColumnName nvarchar(50)
		DECLARE @CustomTable table(ID int identity(1,1),CostCenterID int, TypeID int, ColumnName nvarchar(50))
		insert into @CustomTable(CostCenterID, TypeID, ColumnName)
		select ColumnCostCenterID, ColumnCCListViewTypeID, SysColumnName
		from adm_CostCenterDef WITH(NOLOCK) where CostCenterID=65 
		--and SystableName='COM_CCCCDATA' and ColumnCostCenterID>50000 
		and IsColumninuse=1
		 and (ColumnCostCenterID>50000 or (ColumnCostCenterID=44 and usercolumntype='LISTBOX' ))

		set @i=1
		set @CustomQuery1=''
		set @CustomQuery3=', '
		select @CNT=count(id) from @CustomTable
		while (@i<=	@CNT)
		begin
		
			select @CCID=CostCenterID,@TypeID=TypeID,@ColumnName=ColumnName from @CustomTable where ID=@i
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
				select @Table=TableName,@FeatureName=FeatureID from adm_features WITH(NOLOCK) where FeatureID = @CCID
				set @TabRef='A'+CONVERT(nvarchar,@i)
				set @CCID=@CCID-50000
	    	 
				if(@CCID>0)
				begin
					set @CustomQuery1=@CustomQuery1+' left join '+@Table+' '+@TabRef+' WITH(NOLOCK) on '+@TabRef+'.NodeID=CC.CCNID'+CONVERT(nvarchar,@CCID)
					set @CustomQuery3=@CustomQuery3+' '+@TabRef+'.Name as CCNID'+CONVERT(nvarchar,@CCID)+'_Name ,'
				end

			end
			set @i=@i+1
		end
		
		if(len(@CustomQuery3)>0)
		begin
			set @CustomQuery3=SUBSTRING(@CustomQuery3,0,LEN(@CustomQuery3)-1)
		end
	  
		declare @sql nvarchar(max)
		set @sql='
		SELECT c.*, l.name as Salutation,r.name as RoleLookUp, s.Status  ,CEX.*,CC.*'+@CustomQuery3+',case when birthday=0 then null else convert(datetime,c.birthday) end birthday1, case when Anniversary=0 then null else convert(Datetime,Anniversary) end anniversary1
		,ISNULL(c.UserID,0) ContactUserID
		FROM  COM_Contacts c WITH(NOLOCK) 
		left join com_lookup l with(nolock) on l.Nodeid=c.SalutationID
		left join com_lookup r with(nolock) on r.nodeid=c.rolelookupid
		left join com_status s with(nolock) on s.statusid=c.statusid 
		left JOIN COM_CONTACTSEXTENDED CEX with(nolock) ON CEX.ContactID=c.ContactID
		left JOIN COM_CCCCDATA CC with(nolock) ON CC.NODEID=c.ContactID AND CC.CostCenterID=65
		'+@CustomQuery1+''
		if (@ContactType =3)
			set @sql= @sql+' WHERE c.FeatureID='+convert(nvarchar(300),@CostCenterID)+' and  c.FeaturePK='+convert(nvarchar(300),@NodeID)+' '
		else
			set @sql= @sql+' WHERE c.FeatureID='+convert(nvarchar(300),@CostCenterID)+' and  c.FeaturePK='+convert(nvarchar(300),@NodeID)+' AND c.AddressTypeID='+convert(nvarchar(300),@ContactType)
		PRINT @sql
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

----[spCom_GetFeatureWiseContacts] 2,4432,2,1,1
GO
