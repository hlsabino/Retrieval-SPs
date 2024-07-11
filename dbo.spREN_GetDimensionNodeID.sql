USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spREN_GetDimensionNodeID]
	@NodeID [bigint] = 0,
	@CostcenterID [bigint] = 0,
	@UserID [bigint],
	@LangID [int] = 1,
	@Dimesion [bigint] = 1 OUTPUT
WITH ENCRYPTION, EXECUTE AS CALLER
AS
      
BEGIN TRY       
SET NOCOUNT ON     
      
  DECLARE @TabName nvarchar(max)  , @Code nvarchar(max) , @Name nvarchar(max)  
  DECLARE @Qry nvarchar(max) ,@ReturnValue bigint  ,@PrefValue NVARCHAR(500),@TEMPxml NVARCHAR(500)
    
  IF(@CostcenterID  = 92)  
  BEGIN  
 select @Code = Code,@Name = Name from REN_Property with(nolock) where NodeID = @NodeID  
   
  END   
  ELSE IF(@CostcenterID  = 93)  
  BEGIN  
 select @Code = Code,@Name = Name from REN_Units with(nolock) where UnitID = @NodeID  
   
  END   
   ELSE IF(@CostcenterID  = 94)  
  BEGIN  
  
 select @Code = TenantCode,@Name = FirstName from REN_Tenant with(nolock) where TenantID = @NodeID  
   
  END   
  
  select   @Dimesion = Value from COM_CostCenterPreferences with(nolock)
  where CostCenterID= @CostcenterID  and  Name = 'LinkDocument'
		
  select @TabName = TableName  from adm_features with(nolock) 
  where FeatureID =@Dimesion
   
  --select '1' , @TabName ,@Name  
    Declare @tempSearchValue nvarchar(max),@tempSql nvarchar(max)      
    set @tempSearchValue='@ReturnValue BIGINT OUTPUT,@Name nvarchar(max),@Code nvarchar(max)'      
    set @tempSql=' SELECT @ReturnValue = NODEID FROM ' + @TabName +' with(nolock) where   Name = @Name and Code=@Code'  
     
       print @tempSql
         
    EXEC sp_executesql @tempSql, @tempSearchValue, @ReturnValue OUTPUT,@Name,@Code  
    
 
	if( @ReturnValue is null or @ReturnValue =0 or @ReturnValue = '' ) 
	begin
	   
		select   @PrefValue = Value from COM_CostCenterPreferences with(nolock)
		where CostCenterID= @CostcenterID  and  Name = 'LinkDocument'

		if(@PrefValue is not null and @PrefValue<>'')
		begin

			set @Dimesion=0
			begin try
				set @Dimesion=convert(BIGINT,@PrefValue)
			end try
			begin catch
				set @Dimesion=0
			end catch
			if(@Dimesion>0)
			begin
				SET @TEMPxml='<XML><Row AccountName ="'+replace(@Name,'&','&amp;')+'" AccountCode ="'+replace(@Code,'&','&amp;')+'"  ></Row></XML>'  
			 
				EXEC @ReturnValue = [dbo].[spADM_SetImportData]  
				   @XML = @TEMPxml,  
				   @COSTCENTERID = @Dimesion,  
				   @IsDuplicateNameAllowed = 1,  
				   @IsCodeAutoGen = 0,  
				   @IsOnlyName = 1,  
				   @CompanyGUID = 'CompanyGUID',  
				   @UserName = 'admin' ,  
				   @UserID = 1,
				   @RoleID=1,
				   @LangID = 1   
				   
				set @tempSearchValue='@ReturnValue BIGINT OUTPUT,@Name nvarchar(max)'      
				set @tempSql=' SELECT @ReturnValue = NODEID FROM ' + @TabName +' with(nolock) where  Name = @Name'  
			     
			       
				EXEC sp_executesql @tempSql, @tempSearchValue, @ReturnValue OUTPUT, @Name  
			end
		end    
	end
 
 
      
SET NOCOUNT OFF;      
RETURN ISNULL(@ReturnValue,1)  
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
