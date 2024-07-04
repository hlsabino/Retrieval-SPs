USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spACC_GetAssetNodeID]
	@TypeID [bigint],
	@Name [nvarchar](500),
	@IsCode [bit] = 0,
	@UserID [bigint],
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS

BEGIN TRY  
SET NOCOUNT ON; 
		
		declare @ID int
		set @ID=0 
		
		if(@TypeID=1)
		begin
			if(@IsCode=1)
			begin
				if exists(select * from Acc_Assets WITH(nolock) where AssetCode=@Name)
				begin
					set @ID=(select Top(1) AssetID from Acc_Assets WITH(nolock) where AssetCode=@Name and IsGroup=1)
				end
			end
			else
			begin
				if exists(select * from Acc_Assets WITH(nolock) where AssetName=@Name)
				begin
					set @ID=(select Top(1) AssetID from Acc_Assets WITH(nolock) where AssetName=@Name and IsGroup=1)
				end
			end
		end
		else if(@TypeID=2)
		begin
		if(@IsCode=1)
			begin
				if exists(select * from ACC_AssetClass WITH(nolock) where AssetClassCode=@Name)
				begin
					set @ID=(select Top(1) AssetClassID from ACC_AssetClass WITH(nolock) where AssetClassCode=@Name)
				end
			end
			else
			begin
				if exists(select * from ACC_AssetClass WITH(nolock) where AssetClassName=@Name)
				begin
					set @ID=(select Top(1) AssetClassID from ACC_AssetClass WITH(nolock) where AssetClassName=@Name)
				end
			end
		end
		else if(@TypeID=3)
		begin
			if(@IsCode=1)
			begin
				if exists(select * from ACC_PostingGroup WITH(nolock) where PostGroupCode=@Name)
				begin
					set @ID=(select Top(1) PostingGroupID from ACC_PostingGroup WITH(nolock) where PostGroupCode=@Name)
				end
			end
			else
			begin
				if exists(select * from ACC_PostingGroup WITH(nolock) where PostGroupName=@Name)
				begin
					set @ID=(select Top(1) PostingGroupID from ACC_PostingGroup WITH(nolock) where PostGroupName=@Name)
				end
			end
		end
		else if(@TypeID=4)
		begin
			if(@IsCode=1)
			begin
				if exists(select * from ACC_DeprBook WITH(nolock) where DeprBookCode=@Name)
				begin
					set @ID=(select Top(1) DeprBookID from ACC_DeprBook WITH(nolock) where DeprBookCode=@Name)
				end
			end
			else
			begin
				if exists(select * from ACC_DeprBook WITH(nolock) where DeprBookName=@Name)
				begin
					set @ID=(select Top(1) DeprBookID from ACC_DeprBook WITH(nolock) where DeprBookName=@Name)
				end
			end
		end
		
		
SET NOCOUNT OFF;  
RETURN @ID
END TRY
BEGIN CATCH  
	--Return exception info [Message,Number,ProcedureName,LineNumber]  
	IF ERROR_NUMBER()=50000
	BEGIN
		SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
		WHERE ErrorNumber=ERROR_MESSAGE() AND LanguageID=@LangID
	END
	ELSE IF ERROR_NUMBER()=547
	BEGIN
		SELECT ErrorMessage, ERROR_MESSAGE() AS ServerMessage,ERROR_NUMBER() as ErrorNumber, ERROR_PROCEDURE()as ProcedureName, ERROR_LINE() AS ErrorLine 
		FROM COM_ErrorMessages WITH(nolock)
		WHERE ErrorNumber=-110 AND LanguageID=@LangID
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
