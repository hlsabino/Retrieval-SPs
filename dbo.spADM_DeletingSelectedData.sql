USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_DeletingSelectedData]
	@CostCenterID [int] = 0,
	@NodeID [nvarchar](max) = null,
	@Type [int] = 0,
	@SysInfo [nvarchar](500) = '',
	@AP [nvarchar](10) = '',
	@UserName [nvarchar](max) = null,
	@UserID [int] = 1,
	@LangID [int] = 1,
	@RoleID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY    
SET NOCOUNT ON;    
  
 declare @IsInventory bit,@IsDocument Bit,@Schedule INT,@return_value int,@sql nvarchar(max)  
 declare @i INT,@cnt INT,@value INT 
 DECLARE @ScheduleID INT 
 create TABLE #TblCC (ID INT IDENTITY(1,1) PRIMARY KEY,CC nvarchar(100))    
 select @IsInventory=IsInventory from ADM_DocumentTypes with(nolock) where CostCenterID=@CostCenterID  
  
 set @IsDocument=(case when @CostCenterID between 40000 and 50000 then 1 else 0 end)  
   
 IF(@Type=1)  
 BEGIN  
  if(@CostCenterID=95)   
  begin  
   insert into #TblCC(CC)   
   exec [SPSplitString] @NodeID,','  
     
   set @sql='insert into #TblCC(CC)   
   select T.CC from #TblCC T with(nolock)  
   JOIN REN_Contract RC WITH(NOLOCK) ON RC.ContractID=CONVERT(INT,T.CC)  
   WHERE RC.ParentContractID>0'  
     
   exec (@sql)  
     
   insert into #TblCC(CC)   
   SELECT CC FROM #TblCC with(nolock)  
   GROUP BY CC  
   HAVING COUNT(*)=1  
     
   select @i=(count(*)/2)+1,@cnt=count(*) from #TblCC with(nolock)  
     
   while(@i<=@cnt)  
   BEGIN   
    select @value=cc from #TblCC with(nolock) where id=@i  
      
     SET @sql='EXEC @return_value = [dbo].spREN_DeleteContract   
      @CostCenterID = '+CONVERT(NVARCHAR,@CostCenterID)+',    
      @ContractID='+CONVERT(NVARCHAR,@value)+',
      @SysInfo ='''+@SysInfo+''', 
	  @AP ='''+@AP+''', 
      @UserName='''+@UserName+''',
      @UserID = '+CONVERT(NVARCHAR,@UserID)+',    
      @RoleID='+CONVERT(NVARCHAR,@RoleID)+',  
      @LangID = '+CONVERT(NVARCHAR,@LangID)+''  
      
	EXEC sp_executesql @SQL,N'@return_value INT OUTPUT',@return_value OUTPUT
      
      --Deleting Schedules
	   SELECT @ScheduleID=ScheduleID FROM COM_CCSchedules WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND NodeID=@value  
	   IF @ScheduleID>0  
	   BEGIN  
		DELETE FROM COM_CCSchedules WHERE ScheduleID=@ScheduleID  
		DELETE FROM COM_Schedules WHERE ScheduleID=@ScheduleID  
		DELETE FROM COM_SchEvents WHERE ScheduleID=@ScheduleID  
	   END 
	   --Deleting Schedules
    set @i=@i+1  
   END  
  end  
  else   
  begin  
   insert into #TblCC(CC)   
   exec [SPSplitString] @NodeID,','  
  
   select @i=1,@cnt=count(*) from #TblCC with(nolock)  
     
   while(@i<=@cnt)  
   BEGIN   
    select @value=cc from #TblCC with(nolock) where id=@i  
    if(@IsInventory=1)  
    BEGIN    
     EXEC @return_value = [dbo].spDOC_DeleteInvDocument    
       @CostCenterID = @CostCenterID,    
       @DocPrefix = '',    
       @DocNumber = '',    
       @DOCID=@value,  
       @SysInfo =@SysInfo, 
	   @AP =@AP, 
       @UserID = @UserID,    
       @UserName = @UserName,    
       @LangID = @LangID,  
       @RoleID=@RoleID
    END  
    ELSE  
    BEGIN  
     EXEC @return_value = [dbo].spDOC_DeleteAccDocument    
       @CostCenterID = @CostCenterID,    
       @DocPrefix = '',    
       @DocNumber = '',    
       @DOCID=@value,  
       @SysInfo =@SysInfo, 
	   @AP =@AP, 
       @UserID = @UserID,    
       @UserName = @UserName,    
       @LangID = @LangID,  
       @RoleID=@RoleID  
    END
    --Deleting Schedules
	   SELECT @ScheduleID=ScheduleID FROM COM_CCSchedules WITH(NOLOCK) WHERE CostCenterID=@CostCenterID AND NodeID=@value  
	   IF @ScheduleID>0  
	   BEGIN  
		DELETE FROM COM_CCSchedules WHERE @ScheduleID=@ScheduleID  
		DELETE FROM COM_Schedules WHERE ScheduleID=@ScheduleID  
		DELETE FROM COM_SchEvents WHERE ScheduleID=@ScheduleID  
	   END   
    set @i=@i+1  
   END  
  end  
 END  
 ELSE IF(@Type=2)  
 BEGIN  
  insert into #TblCC(CC)   
  exec [SPSplitString] @NodeID,','  
  
  select @i=1,@cnt=count(*) from #TblCC with(nolock)  
    
  while(@i<=@cnt)  
  BEGIN  
   select @value=cc from #TblCC with(nolock) where id=@i  
     
   DELETE FROM COM_Schedules   
   where @Schedule=@value    
   set @i=@i+1  
  END  
    
  DELETE FROM COM_CCSCHEDULES   
  where CostCenterID=@CostCenterID AND convert(nvarchar,NodeID) in (@NodeID)  
  
  if exists(select name from sys.tables with(nolock) where name='CRM_Activities')
  begin  
	  SET @SQL='DELETE FROM  CRM_Activities   
	  WHERE CostCenterID='+CONVERT(NVARCHAR,@CostCenterID)+' AND convert(nvarchar,NodeID) in ('+@NodeID+')'  
	  EXEC (@SQL)
  end
 END  
 ELSE IF(@Type=3)  
 BEGIN  
 -- IF(@IsDocument=1)  
 -- BEGIN  
	--IF(@IsInventory=1)  
	--BEGIN  
	--	DELETE FROM COM_Files   
	--	WHERE FeatureID=@CostCenterID AND FeaturePK IN (SELECT DocID FROM  [INV_DocDetails] with(nolock)  
	--	WHERE CostCenterID=@CostCenterID AND convert(nvarchar,DocID) in (@NodeID))  
 --   END
 --   BEGIN 
	--	
	--	DELETE FROM COM_Files   
	--	WHERE FeatureID=@CostCenterID AND FeaturePK IN (SELECT  DISTINCT DocID FROM  [ACC_DocDetails] with(nolock)  
	--	WHERE CostCenterID=@CostCenterID AND convert(nvarchar,DocID) in ( @NodeID )) 
	 
 --   END  
 -- END
	INSERT INTO #TblCC(CC)   
	exec [SPSplitString] @NodeID,','  
	SELECT @i=1,@cnt=count(*) FROM #TblCC with(nolock)  
	WHILE(@i<=@cnt)  
	BEGIN  
		SELECT @value=cc FROM #TblCC with(nolock) WHERE id=@i  
		PRINT 'T'
		PRINT @value
		DELETE FROM COM_Files WHERE FeatureID=@CostCenterID AND FeaturePK IN (@value)  
	SET @i=@i+1  
	END  
 END  
 ELSE IF(@Type=4)  
 BEGIN  
  if(@IsDocument=1)  
  BEGIN  
   if(@IsInventory=1)  
   BEGIN  
    DELETE FROM COM_Notes   
    WHERE FeatureID=@CostCenterID AND FeaturePK IN (SELECT DocID FROM  [INV_DocDetails] with(nolock)  
    WHERE CostCenterID=@CostCenterID AND convert(nvarchar,DocID) in (@NodeID))  
   END  
   BEGIN  
    DELETE FROM COM_Notes   
    WHERE FeatureID=@CostCenterID AND FeaturePK IN (SELECT DocID FROM  [ACC_DocDetails] with(nolock)  
    WHERE CostCenterID=@CostCenterID AND convert(nvarchar,DocID) in (@NodeID))  
   END  
  END  
 END  
   
 drop TABLE #TblCC  
    
COMMIT TRANSACTION  
SET NOCOUNT OFF;    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=102 AND LanguageID=@LangID  
  
RETURN 1  
END TRY  
BEGIN CATCH    
 --Return exception info [Message,Number,ProcedureName,LineNumber]    
 IF ERROR_NUMBER()=50000  
 BEGIN  
  SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()=547  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine FROM COM_ErrorMessages WITH(nolock)  
  WHERE ErrorNumber=-110 AND LanguageID=@LangID  
 END  
 ELSE IF ERROR_NUMBER()<>266  
 BEGIN  
  SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine  
  FROM COM_ErrorMessages WITH(nolock) WHERE ErrorNumber=-999 AND LanguageID=@LangID  
 END  
 BEGIN TRY  
  ROLLBACK TRANSACTION  
 END TRY  
 BEGIN CATCH    
 END CATCH  
SET NOCOUNT OFF    
RETURN -999     
END CATCH  
GO
