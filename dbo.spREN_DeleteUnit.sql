USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_DeleteUnit]
	@UnitID [int] = 0,
	@UserID [int] = 1,
	@RoleID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY    
SET NOCOUNT ON;    
  
	DECLARE @HasAccess bit,@lft INT,@rgt INT,@Width INT,@UserName NVARCHAR(64)  

	--SP Required Parameters Check  
	if(@UnitID=0)  
	BEGIN  
		RAISERROR('-100',16,1)  
	END  

	--User acces check  
	SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,93,4)  

	IF @HasAccess=0  
	BEGIN  
		RAISERROR('-105',16,1)  
	END  

	IF((SELECT ParentID FROM REN_UNITS WITH(NOLOCK) WHERE UNITID=@UnitID)=0)  
	BEGIN  
		RAISERROR('-117',16,1)  
	END  
  
     
	--Fetch left, right extent of Node along with width.  
	SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1  
	FROM REN_UNITS WITH(NOLOCK) WHERE UNITID=@UnitID    

	declare @tempUnit table(id int identity(1,1), UNITID INT)  

	insert into @tempUnit  
	select UNITID from REN_UNITS WITH(NOLOCK) WHERE lft >= @lft AND rgt <= @rgt  


	--ondelete External function
	IF (@UnitID>0)
	BEGIN
		DECLARE @tablename NVARCHAR(200)
		set @tablename=''
		select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=93 and Mode=8
		if(@tablename<>'')
			exec @tablename 93,@UnitID,'',@UserID,@LangID	
	END	
		
	declare @i int, @cnt int  
	DECLARE @CCNodeID INT, @CCDimesion INT   
	select @i=1,@cnt=count(*) from @tempUnit  
	 
	while @i<=@cnt  
	begin  
		set @CCNodeID=0  
		set @CCDimesion=0  
		select @CCNodeID = CCNodeID, @CCDimesion=LinkCCID from REN_UNITS WITH(NOLOCK) 
		where UNITID IN (select UNITID from @tempUnit where id=@i)  

		if (@CCNodeID is not null and @CCNodeID>0)  
		begin
		  
			Update REN_UNITS set LinkCCID=0, CCNodeID=0 where UNITID in (select UNITID from @tempUnit where id=@i)
			  
			select @CCNodeID,@CCDimesion
			-- select @NodeID, @Dimesion  
			declare @return_value INT  
			EXEC @return_value = [dbo].[spCOM_DeleteCostCenter]  
			@CostCenterID = @CCDimesion,  
			@NodeID = @CCNodeID,  
			@RoleID=1,
			@UserID = @UserID,  
			@LangID = @LangID,  
			@CheckLink = 0  
	      
			--Deleting from Mapping Table  
			Delete from com_docbridge WHERE CostCenterID = 93 AND RefDimensionNodeID = @CCNodeID AND RefDimensionID =  @CCDimesion       
		end  
		set @i=@i+1  
	end  
	
	SELECT @UserName=USERNAME FROM ADM_USERS WITH(NOLOCK) WHERE UserID=@UserID
	
    select @i=1,@cnt=count(*) from @tempUnit
	while @i<=@cnt
	begin
		select @CCNodeID=UNITID from @tempUnit where id=@i
		
		--INSERT INTO HISTROY   
		EXEC [spCOM_SaveHistory]  
			@CostCenterID =93,    
			@NodeID =@CCNodeID,
			@HistoryStatus ='Deleted',
			@UserName=@UserName
		
		set @i=@i+1
	end


	delete from REN_UnitsExtended where UNITID IN (select UNITID from @tempUnit) 
	delete from com_ccccdata where costcenterid=93 and NodeID IN (select UNITID from @tempUnit)  
	
	delete from REN_Particulars where PropertyID in   
	(SELECT PropertyID FROM REN_UNITS WITH(NOLOCK) WHERE UNITID IN (select UNITID from @tempUnit)) and UnitID IN (select UNITID from @tempUnit)
	
	delete FROM COM_Notes  
	WHERE FeatureID = 93 AND FeaturePK IN (select UNITID from @tempUnit) 
	
	delete FROM COM_Files 
	WHERE FeatureID = 93 AND FeaturePK IN (select UNITID from @tempUnit) 
	
	DELETE FROM Ren_UnitRate 
	WHERE UnitID IN (select UNITID from @tempUnit) 
	
	--Delete From CRM_Cases where CASEID=@CASEID  
	Delete from com_docbridge WHERE CostCenterID = 93 AND NodeID IN (select UNITID from @tempUnit)
   
   	Delete from COM_HistoryDetails WHERE CostCenterID = 93 AND NodeID IN (select UNITID from @tempUnit) 
	
	--Delete from main table  
	DELETE FROM REN_UNITS WHERE lft >= @lft AND rgt <= @rgt  

	--Update left and right extent to set the tree  
	UPDATE REN_UNITS SET rgt = rgt - @Width WHERE rgt > @rgt;  
	UPDATE REN_UNITS SET lft = lft - @Width WHERE lft > @rgt;  
	
COMMIT TRANSACTION  
SET NOCOUNT OFF;    
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock)   
WHERE ErrorNumber=102 AND LanguageID=@LangID  
  
RETURN 1  
END TRY  
BEGIN CATCH    
if(@return_value=-999)
	return -999
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
