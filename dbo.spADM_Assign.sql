USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_Assign]
	@Type [int],
	@CostCenterID [int],
	@NodeID [int],
	@Groups [nvarchar](max),
	@Roles [nvarchar](max),
	@Users [nvarchar](max),
	@LocationWhere [nvarchar](max) = null,
	@DivisionWhere [nvarchar](max) = null,
	@UserName [nvarchar](50),
	@UserID [int],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION  
BEGIN TRY  
SET NOCOUNT ON;
	DECLARE @Dt FLOAT,@Sql nvarchar(max),@InvDocDetID int
	DECLARE @TblApp AS TABLE(G INT NOT NULL DEFAULT(0),R INT NOT NULL DEFAULT(0),U INT NOT NULL DEFAULT(0))
	SET @Dt=CONVERT(FLOAT,GETDATE())
	
	IF @Type=1--TO GET MAP INFORMATION
	BEGIN
		--Groups,Roles,Users
		EXEC spADM_AssignInfo @LocationWhere,@DivisionWhere,@UserID
		
		if(@CostCenterID>50000)
		BEGIN
			SET @Sql='select INVE.Type,INVE.RefID,INVE.InvdocdetailsID
			from inv_docdetails a WITH(NOLOCK)
			join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid
			JOIN Inv_docextradetails INVE WITH(NOLOCK) ON INVE.InvdocdetailsID=a.InvdocdetailsID
			where a.documenttype=45 and b.dcccnid'+convert(nvarchar,(@CostCenterID-50000))+'='+convert(nvarchar,@NodeID)
			EXEC (@Sql)
		END	
		else
			SELECT UserID,RoleID,GroupID FROM ADM_Assign WITH(NOLOCK) 
			WHERE CostCenterID=@CostCenterID AND NodeID=@NodeID

	END
	ELSE IF @Type=2--TO SET MAP INFORMATION
	BEGIN
		
	
		INSERT INTO @TblApp(G)
		EXEC [SPSplitString] @Groups,','

		INSERT INTO @TblApp(R)
		EXEC [SPSplitString] @Roles,','

		INSERT INTO @TblApp(U)
		EXEC [SPSplitString] @Users,','
		
		if(@CostCenterID>50000)
		BEGIN
			
			SET @Sql='select @InvDocDetID=a.InvdocdetailsID
			from inv_docdetails a WITH(NOLOCK)
			join com_docccdata b WITH(NOLOCK) on a.invdocdetailsid=b.invdocdetailsid			
			where a.documenttype=45 and b.dcccnid'+convert(nvarchar,(@CostCenterID-50000))+'='+convert(nvarchar,@NodeID)
			EXEC sp_executesql @Sql,N'@InvDocDetID int output',@InvDocDetID output
			
			delete from INV_DocExtraDetails
			where InvDocDetailsID=@InvDocDetID and [Type] in(6,7,8)
			
			insert into INV_DocExtraDetails(InvDocDetailsID,[Type],[RefID])
			select @InvDocDetID,6,G from @TblApp
			where g<>0
			
			insert into INV_DocExtraDetails(InvDocDetailsID,[Type],[RefID])
			select @InvDocDetID,7,R from @TblApp
			where R<>0
			
			insert into INV_DocExtraDetails(InvDocDetailsID,[Type],[RefID])
			select @InvDocDetID,8,U from @TblApp
			where U<>0
			
			set @Sql=''
			select @Sql=@Sql+','+UserName from ADM_Users u WITH(NOLOCK)
			join @TblApp b on u.UserID=b.u
			where U<>0
			
			select @Sql=@Sql+','+Name from ADM_PRoles u WITH(NOLOCK)
			join @TblApp b on u.RoleID=b.R
			where R<>0
			
			select @Sql=@Sql+','+GroupName from COM_Groups u WITH(NOLOCK)
			join @TblApp b on u.GID=b.R
			where g<>0
			
			if(len(@Sql)>1)
			BEGIN
				set @Sql=substring(@Sql,2,len(@Sql))
				update COM_DocTextData
				set dcAlpha13=@Sql
				where InvDocDetailsID=@InvDocDetID
			END

		   Declare @DocID BigInt,@RoleID INT,@CCID INT

		   select @RoleID = RoleID from Adm_UserRoleMap WITH(nolock) where UserID = @UserID

		   Select @DocID = DocID ,@CCID = CostCenterID From Inv_DocDetails  WITH(nolock) where InvDocDetailsID = @InvDocDetID

		   EXEC spCOM_SetNotifEvent 153,@CostCenterID,@DocID,null,@UserName,@UserID,@RoleID  		
			
		END
		ELSE
		BEGIN
			DELETE FROM ADM_Assign 
			WHERE CostCenterID=@CostCenterID AND NodeID=@NodeID
			
			INSERT INTO ADM_Assign(CostCenterID,NodeID,GroupID,RoleID,UserID,CreatedBy,CreatedDate)
			SELECT @CostCenterID,@NodeID,G,R,U,@UserName,@Dt
			FROM @TblApp
			ORDER BY U,R,G
		END
		
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=100 AND LanguageID=@LangID
	END
	
COMMIT TRANSACTION 
SET NOCOUNT OFF;   
RETURN 1
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine
	FROM COM_ErrorMessages WITH(NOLOCK) WHERE ErrorNumber=-999 AND LanguageID=@LangID
	END
ROLLBACK TRANSACTION
SET NOCOUNT OFF  
RETURN -999   
END CATCH
GO
