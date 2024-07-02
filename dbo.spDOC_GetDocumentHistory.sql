USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spDOC_GetDocumentHistory]
	@CostCenterID [int],
	@DocID [int],
	@UserID [int] = 0,
	@RoleID [int] = 0,
	@UserName [nvarchar](50),
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY	
SET NOCOUNT ON

		--Declaration Section
		DECLARE @IsInventory bit
		declare @tblhist table(ModifiedBy nvarchar(max),ModifiedDate datetime,maxid bigint)

		--SP Required Parameters Check
		IF (@CostCenterID < 40000)
		BEGIN
			RAISERROR('-100',16,1)
		END
		
		select @IsInventory=IsInventory From adm_documentTypes WITH(NOLOCK)
		Where CostCenterID=@CostCenterID
		
		if(@IsInventory=1)
		BEGIN
			--SElect distinct ModifiedBy,convert(datetime,ModifiedDate) ModifiedDate,max(InvDocDetailsHistoryID) maxid from INV_DocDetails_History WITH(NOLOCK)
			insert into @tblhist
			Select distinct case when U.FirstName is not null and U.FirstName<>'' then U.FirstName else max(H.ModifiedBy) end ModifiedBy,convert(datetime,H.ModifiedDate) ModifiedDate,max(H.InvDocDetailsHistoryID) maxid 
			from INV_DocDetails_History H WITH(NOLOCK)
			JOIN ADM_Users U WITH(NOLOCK) on U.UserName=H.ModifiedBy
			where H.CostCenterID=@CostCenterID and H.DocID=@DocID
			group by U.FirstName,convert(datetime,H.ModifiedDate)
			order by ModifiedDate
			
			if not exists(select * from @tblhist)
			BEGIN
				insert into @tblhist
				Select distinct case when U.FirstName is not null and U.FirstName<>'' then U.FirstName else max(H.CreatedBy) end ModifiedBy,convert(datetime,H.CreatedDate) ModifiedDate,max(H.InvDocDetailsID) maxid
					 from INV_DocDetails H WITH(NOLOCK)
				JOIN ADM_Users U WITH(NOLOCK) on U.UserName=H.CreatedBy
				where H.CostCenterID=@CostCenterID and H.DocID=@DocID
				group by U.FirstName,convert(datetime,H.CreatedDate)
				order by convert(datetime,H.CreatedDate)
				
			END
			
		END
		ELSE
		BEGIN
			insert into @tblhist
			Select distinct case when U.FirstName is not null and U.FirstName<>'' then U.FirstName else max(H.ModifiedBy) end ModifiedBy,convert(datetime,H.ModifiedDate) ModifiedDate,max(H.AccDocDetailsHistoryID) maxid 
			 from ACC_DocDetails_History H WITH(NOLOCK)
			JOIN ADM_Users U WITH(NOLOCK) on U.UserName=H.ModifiedBy
			where H.CostCenterID=@CostCenterID and H.DocID=@DocID
			group by U.FirstName,convert(datetime,H.ModifiedDate)
			order by ModifiedDate
			
			if not exists(select * from @tblhist)
			BEGIN
				insert into @tblhist
				Select distinct case when U.FirstName is not null and U.FirstName<>'' then U.FirstName else max(H.CreatedBy) end ModifiedBy,convert(datetime,H.CreatedDate) ModifiedDate,max(H.AccDocDetailsID) maxid
					 from ACC_DocDetails H WITH(NOLOCK)
				JOIN ADM_Users U WITH(NOLOCK) on U.UserName=H.CreatedBy
				where H.CostCenterID=@CostCenterID and H.DocID=@DocID
				group by U.FirstName,convert(datetime,H.CreatedDate)
				order by convert(datetime,H.CreatedDate)
				
			END	
		END 
		
		select * from @tblhist
			
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
SET NOCOUNT OFF  
RETURN -999   
END CATCH

GO
