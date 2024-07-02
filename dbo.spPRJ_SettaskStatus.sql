USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spPRJ_SettaskStatus]
	@CostCenterID [int],
	@NodeID [int],
	@Mode [nvarchar](50),
	@progressxml [nvarchar](max),
	@dt [datetime],
	@ActDays [float] = 0,
	@ActWorkHrs [float] = 0,
	@ActDurDays [float] = 0,
	@UserName [nvarchar](50),
	@RoleID [int] = 0,
	@UserID [int] = 0,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  
	declare @Sql nvarchar(max),@Status int,@tabName nvarchar(100),@depend nvarchar(max),@noteid INT
	set @noteid=1
	select @tabName=TableName from ADM_Features WITH(NOLOCK) WHERE FeatureID=@CostCenterID
	
	if(@Mode='Start')
	begin
		
		SET @Sql='Select @depend=ccalpha12 from '+@tabName+' WITH(NOLOCK) where NodeID='+convert(nvarchar,@NodeID)
		EXEC sp_executesql @sql,N'@depend nvarchar(max) OUTPUT',@depend output
		
		create table #Tempcode(code nvarchar(max))
		insert into #Tempcode
		exec SPSplitString @depend,','  
		
		select @Status=StatusID from com_status WITH(NOLOCK) 
	    where costcenterid=@CostCenterID and status='Close'
	
		SET @Sql=' set @depend= ''''
		Select @depend=a.code from '+@tabName+'  a WITH(NOLOCK)
		join #Tempcode b on a.code collate database_default=b.code collate database_default
		where statusid<>'+convert(nvarchar,@Status)
		print @sql
		EXEC sp_executesql @sql,N'@depend nvarchar(max) OUTPUT',@depend output
		
		if(@depend!='')
			RAISERROR('-570',16,1)

		select @Status=StatusID from com_status WITH(NOLOCK) 
		where costcenterid=@CostCenterID and status='In Process'

		SET @Sql='update '+@tabName+'
		set StatusID='+convert(nvarchar,@Status)+',ccalpha22='''+convert(nvarchar,@dt,100)+'''
		where NodeID='+convert(nvarchar,@NodeID)
		print @Sql
		EXEC (@Sql)
		
		SET @Sql='
		declare @vno nvarchar(max),@ProjStart Datetime,@diff int
		select @vno=voucherno,@ProjStart=case when isdate(dcAlpha25)=1 then convert(datetime,dcAlpha25) else null end
		from inv_docdetails a WITH(NOLOCK)
		join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where documenttype=45 and dcccnid'+convert(nvarchar,(@CostCenterID-50000))+'='+convert(nvarchar,@NodeID)+'
		
		set @diff=0
		if(@ProjStart is not null)
			set @diff=datediff(d,convert(datetime,@ProjStart),convert(datetime,'''+convert(nvarchar,@dt,100)+'''))
		
		update c 
		set dcalpha20=''In Process'',dcalpha22='''+convert(nvarchar,@dt,100)+''',dcAlpha25='''+convert(nvarchar,@dt,100)+'''
		from inv_docdetails a WITH(NOLOCK)
		join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where documenttype=45 and dcccnid'+convert(nvarchar,(@CostCenterID-50000))+'='+convert(nvarchar,@NodeID)+'
		
		if(@diff<>0)
		BEGIN
			update c 
			set dcAlpha25=case when isdate(dcAlpha25)=1 and convert(datetime,dcAlpha25)>@ProjStart then convert(nvarchar,convert(datetime,dcAlpha25)+@diff,100) else dcAlpha25 end,
				dcAlpha26=case when isdate(dcAlpha26)=1 and convert(datetime,dcAlpha26)>@ProjStart then convert(nvarchar,convert(datetime,dcAlpha26)+@diff,100) else dcAlpha26 end
			from inv_docdetails a WITH(NOLOCK)			
			join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
			where Voucherno=@vno
		END	'
		print @Sql
		EXEC (@Sql)
		
		EXEC spCOM_SetNotifEvent 475,@COSTCENTERID,@NodeID,'admin',@UserName,@UserID,@RoleID  
		
	
	end
	ELSE if(@Mode='ReOpen')
	begin
		set @Status=472

		SET @Sql='update '+@tabName+'
		set StatusID='+convert(nvarchar,@Status)+',ccalpha22='''+convert(nvarchar,@dt,100)+'''
		where NodeID='+convert(nvarchar,@NodeID)
		EXEC (@Sql)
		
		SET @Sql='update c 
		set dcalpha20=''Open''
		from inv_docdetails a WITH(NOLOCK)
		join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where documenttype=45 and dcccnid'+convert(nvarchar,(@CostCenterID-50000))+'='+convert(nvarchar,@NodeID)
		EXEC (@Sql)
		
				
		SET @Sql='
		declare @vno nvarchar(max),@compPer float,@InProcPer float
		select @vno=voucherno
		from inv_docdetails a WITH(NOLOCK)
		join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where documenttype=45 and dcccnid'+convert(nvarchar,(@CostCenterID-50000))+'='+convert(nvarchar,@NodeID)
		
		
		SET @Sql=@Sql+' select @compPer=isnull(sum(convert(float,dcalpha14)),0)
		from inv_docdetails a WITH(NOLOCK)		
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where voucherno=@vno and dcalpha20=''Close'' and dcalpha14 is not null and isnumeric(dcalpha14)=1  
		
		select @InProcPer=isnull(sum(convert(float,dcalpha19)*convert(float,dcalpha14)/100),0)
		from inv_docdetails a WITH(NOLOCK)		
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where voucherno=@vno and dcalpha20=''In Process'' and dcalpha19 is not null and isnumeric(dcalpha19)=1  
		and dcalpha14 is not null and isnumeric(dcalpha14)=1
		
		update c 
		set dcalpha4=convert(nvarchar,@compPer),dcalpha9=convert(nvarchar,@InProcPer),dcalpha8=convert(nvarchar,@InProcPer+@compPer)
		from inv_docdetails a WITH(NOLOCK)			
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where Voucherno=@vno' 
		
		EXEC (@Sql)
		EXEC spCOM_SetNotifEvent 472,@COSTCENTERID,@NodeID,'admin',@UserName,@UserID,@RoleID  
		
	end
	else if(@Mode='Hold')
	begin
	   select @Status=StatusID from com_status WITH(NOLOCK) 
	   where costcenterid=@CostCenterID and status='Hold'
		
		SET @Sql='update '+@tabName+'
		set StatusID='+convert(nvarchar,@Status)+' 
		where NodeID='+convert(nvarchar,@NodeID)
		
		EXEC (@Sql)
		
		SET @Sql='update c 
		set dcalpha20=''Hold''
		from inv_docdetails a WITH(NOLOCK)
		join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where documenttype=45 and dcccnid'+convert(nvarchar,(@CostCenterID-50000))+'='+convert(nvarchar,@NodeID)
		EXEC (@Sql)
		EXEC spCOM_SetNotifEvent 474,@COSTCENTERID,@NodeID,'admin',@UserName,@UserID,@RoleID  

	end 
	else if(@Mode='Stop')
	begin
	   select @Status=StatusID from com_status WITH(NOLOCK) 
	   where costcenterid=@CostCenterID and status='Close'
		
		
		SET @Sql='update '+@tabName+'
		set StatusID='+convert(nvarchar,@Status)+',ccalpha23='''+convert(nvarchar,@dt,100)+''',ccAlpha24=case when isdate(ccAlpha22)=1 then datediff(d,convert(datetime,ccAlpha22),convert(datetime,'''+convert(nvarchar,@dt,100)+''')) else 0 end
		where NodeID='+convert(nvarchar,@NodeID)
		
		EXEC (@Sql)
		
		SET @Sql='
		declare @vno nvarchar(max),@compPer float,@InProcPer float,@Projend Datetime,@diff int
		select @vno=voucherno,@Projend=case when isdate(dcAlpha26)=1 then convert(datetime,dcAlpha26) else null end
		from inv_docdetails a WITH(NOLOCK)
		join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where documenttype=45 and dcccnid'+convert(nvarchar,(@CostCenterID-50000))+'='+convert(nvarchar,@NodeID)
		
		SET @Sql=@Sql+'update c 
		set dcalpha20=''Close'',dcalpha23='''+convert(nvarchar,@dt,100)+''',dcAlpha24='''+convert(nvarchar,@ActDays)+''',dcAlpha33='''+convert(nvarchar,@ActWorkHrs)+''',dcAlpha34='''+convert(nvarchar,@ActDurDays)+'''
		,dcAlpha26='''+convert(nvarchar,@dt,100)+'''
		from inv_docdetails a WITH(NOLOCK)
		join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where documenttype=45 and dcccnid'+convert(nvarchar,(@CostCenterID-50000))+'='+convert(nvarchar,@NodeID)
		
		--dcAlpha24=case when isdate(dcAlpha22)=1 then datediff(d,convert(datetime,dcAlpha22),convert(datetime,'''+convert(nvarchar,@dt,100)+''')) else 0 end
		 		
		SET @Sql=@Sql+' select @compPer=isnull(sum(convert(float,dcalpha14)),0)
		from inv_docdetails a WITH(NOLOCK)		
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where voucherno=@vno and dcalpha20=''Close'' and dcalpha14 is not null and isnumeric(dcalpha14)=1  
		
		select @InProcPer=isnull(sum(convert(float,dcalpha19)*convert(float,dcalpha14)/100),0)
		from inv_docdetails a WITH(NOLOCK)		
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where voucherno=@vno and dcalpha20=''In Process'' and dcalpha19 is not null and isnumeric(dcalpha19)=1  
		and dcalpha14 is not null and isnumeric(dcalpha14)=1
		
		set @diff=0
		if(@Projend is not null)
			set @diff=datediff(d,convert(datetime,@Projend),convert(datetime,'''+convert(nvarchar,@dt,100)+'''))
		
		update c 
		set dcalpha4=convert(nvarchar,@compPer),dcalpha9=convert(nvarchar,@InProcPer),dcalpha8=convert(nvarchar,@InProcPer+@compPer)
		,dcAlpha25=case when @diff<>0 and isdate(dcAlpha25)=1 and convert(datetime,dcAlpha25)>@Projend then convert(nvarchar,convert(datetime,dcAlpha25)+@diff,100) else dcAlpha25 end
		,dcAlpha26=case when @diff<>0 and isdate(dcAlpha26)=1 and convert(datetime,dcAlpha26)>@Projend then convert(nvarchar,convert(datetime,dcAlpha26)+@diff,100) else dcAlpha26 end		
		from inv_docdetails a WITH(NOLOCK)			
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where Voucherno=@vno' 
		print @Sql
		EXEC (@Sql)
		
		EXEC spCOM_SetNotifEvent 473,@COSTCENTERID,@NodeID,'admin',@UserName,@UserID,@RoleID  
	end 
	else if(@Mode='Progress')
	begin
		
		declare @xml xml
		set @xml=@progressxml
		select @Status=X.value('@progress','int'),@noteid= X.value('@NoteID','int'),@Sql=X.value('@Note','nvarchar(max)')
		from @xml.nodes('/XML') as Data(X)
		
		if(@noteid=0)
		BEGIN
		   --If Action is NEW then insert new Notes  
		   INSERT INTO COM_Notes(FeatureID,CostCenterID,FeaturePK,Note,
		   GUID,CreatedBy,CreatedDate,Progress)
		   values(@CostCenterID,@CostCenterID,@NodeID,@Sql,  
		   newid(),@UserName,CONVERT(FLOAT,GETDATE()),@Status)	
		   set @noteid=@@identity		
		END
		ELSE
		BEGIN
			   UPDATE COM_Notes  
			   SET Note=@Sql,
				GUID=newid(),  
				Progress=@Status,
				ModifiedBy=@UserName,  
				ModifiedDate=CONVERT(FLOAT,GETDATE())  
			  where NoteID=@noteid
		END
		
			
		SET @Sql='update '+@tabName+'
		set ccalpha19='''+convert(nvarchar,@Status)+'''
		where NodeID='+convert(nvarchar,@NodeID)
		
		EXEC (@Sql)
		
		SET @Sql='update c 
		set dcalpha19='''+convert(nvarchar,@Status)+'''
		from inv_docdetails a WITH(NOLOCK)
		join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where documenttype=45 and dcccnid'+convert(nvarchar,(@CostCenterID-50000))+'='+convert(nvarchar,@NodeID)
		EXEC (@Sql)
		
		SET @Sql='
		declare @vno nvarchar(max),@InProcPer float
		select @vno=voucherno
		from inv_docdetails a WITH(NOLOCK)
		join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where documenttype=45 and dcccnid'+convert(nvarchar,(@CostCenterID-50000))+'='+convert(nvarchar,@NodeID)
		
		
		SET @Sql=@Sql+' select @InProcPer=isnull(sum(convert(float,dcalpha19)*convert(float,dcalpha14)/100),0)
		from inv_docdetails a WITH(NOLOCK)		
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where voucherno=@vno and dcalpha20=''In Process'' and dcalpha19 is not null and isnumeric(dcalpha19)=1  
		and dcalpha14 is not null and isnumeric(dcalpha14)=1
		
		update c 
		set dcalpha9=convert(nvarchar,@InProcPer)
		,dcalpha8=convert(nvarchar,case when dcalpha4 is not null and isnumeric(dcalpha4)=1 then convert(float,dcalpha4) else 0 end+@InProcPer)
		from inv_docdetails a WITH(NOLOCK)			
		join com_doctextdata c WITH(NOLOCK) on a.invdocdetailsid=c.invdocdetailsid
		where Voucherno=@vno' 
		
		EXEC (@Sql)

	end 
	
SELECT ErrorMessage ,ERROR_MESSAGE(),ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
WHERE ErrorNumber=100 AND LanguageID=@LangID  


COMMIT TRANSACTION
SET NOCOUNT OFF;   
Return @noteid
END TRY      
BEGIN CATCH   
	
 --Return exception info [Message,Number,ProcedureName,LineNumber]      
 IF ERROR_NUMBER()=50000    
 BEGIN  
	IF (ERROR_MESSAGE() in('-570'))    
	BEGIN    
		SELECT ErrorMessage + @depend  as ErrorMessage , ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)      
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID        
	END   
	ELSE
		SELECT ErrorMessage ,ERROR_MESSAGE(),ErrorNumber FROM COM_ErrorMessages WITH(nolock)     
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
	
 END    
 ELSE IF ERROR_NUMBER()=547    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-110 AND LanguageID=@LangID    
 END  
  ELSE IF ERROR_NUMBER()=1205  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-350 AND LanguageID=@LangID  
 END   
 ELSE IF ERROR_NUMBER()=2627    
 BEGIN    
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)    
  WHERE ErrorNumber=-116 AND LanguageID=@LangID    
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
