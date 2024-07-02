USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_DeleteOpportunity]
	@OpportunityID [int] = 0,
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;  

		--Declaration Section
		DECLARE @HasAccess bit,@RowsDeleted INT,@lft INT,@rgt INT,@Width INT

		--SP Required Parameters Check
		if(@OpportunityID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END
			--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,89,4)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		
		IF((SELECT ParentID FROM CRM_Opportunities WITH(NOLOCK) WHERE OpportunityID=@OpportunityID)=0)
		BEGIN
			RAISERROR('-117',16,1)
		END
		
		--ondelete External function
		IF (@OpportunityID>0)
		BEGIN
			DECLARE @tablename NVARCHAR(200)
			set @tablename=''
			select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=89 and Mode=8
			if(@tablename<>'')
				exec @tablename 89,@OpportunityID,'',1,@LangID	
		END	 
		--Fetch left, right extent of Node along with width.
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
		FROM CRM_Opportunities WITH(NOLOCK) WHERE OpportunityID=@OpportunityID
		
		
	 	declare @Tbl as table(id int identity(1,1),OppID INT, ccoppid INT, ConvertFromLeadID INT)
		insert into @Tbl(OppID,ccoppid, ConvertFromLeadID)
		select OpportunityID, CCOpportunityID,ConvertFromLeadID from CRM_Opportunities with(nolock) WHERE lft >= @lft AND rgt <= @rgt and IsGroup=0
				
	 
		--IF ((SELECT ConvertFromLeadID FROM CRM_Opportunities WITH(NOLOCK) WHERE OpportunityID=@OpportunityID)>0)
		--BEGIN
			declare @a int, @cnt1 int,@LeadId INT
			set @a=1
			select @cnt1=count(*) from @Tbl  
			while @a<=@cnt1
			begin
				select @LeadId=ConvertFromLeadID from @Tbl where id=@a 
				if(@LeadId>0)
					update CRM_Leads set StatusID=415 where LeadID=@LeadId
				set @a=@a+1
			end   
		--END 
	 
		DELETE FROM COM_CCCCDATA WHERE CostCenterID=89 and NodeID in (select OpportunityID from CRM_Opportunities with(nolock)  WHERE lft >= @lft AND rgt <= @rgt)
		
		IF(EXISTS(SELECT VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID=89 AND NAME='LinkDimension'))
		BEGIN
			DECLARE @DIMID INT=0,@CCID INT
			SELECT @DIMID=VALUE FROM COM_COSTCENTERPREFERENCES with(nolock) WHERE COSTCENTERID=89 AND NAME='LinkDimension'
			IF(@DIMID>=50000)
			BEGIN 
				declare @d int, @cnt int
				set @d=1
				select @cnt=count(*) from @Tbl  
				while @d<=@cnt
				begin
					select @CCID=ccoppid from @Tbl where id=@d 
					IF 	@CCID>0	 
					BEGIN
					--SELECT @CCID,@DIMID 
			 		EXEC [spCOM_DeleteCostCenter] @DIMID,@CCID,1,1,1   
					END
					set @d=@d+1
				end
			END 
		END	
		
		
		--Delete from exteneded table
		DELETE FROM CRM_OpportunitiesExtended WHERE OpportunityID in
		(select OpportunityID from CRM_Opportunities with(nolock)  WHERE lft >= @lft AND rgt <= @rgt)
		 
		--Delete from main table
		DELETE FROM CRM_Opportunities WHERE lft >= @lft AND rgt <= @rgt

		SET @RowsDeleted=@@rowcount

		DELETE FROM crm_assignment WHERE CCID=89 AND CCNODEID IN
		(select OpportunityID from CRM_Opportunities with(nolock)  WHERE lft >= @lft AND rgt <= @rgt)
		
		DELETE FROM CRM_ACTIVITIES WHERE CostCenterID=89 AND NodeID IN 
		(select OpportunityID from CRM_Opportunities with(nolock)  WHERE lft >= @lft AND rgt <= @rgt)
		 
		--Delete from CostCenter Mapping
		DELETE FROM COM_CCCCDATA WHERE CostCenterID=89 and NodeID=@OpportunityID
		
		DELETE FROM  COM_ContactsExtended
		WHERE ContactID IN (SELECT CONTACTID FROM COM_CONTACTS WITH(NOLOCK) WHERE FeatureID=89 and  FeaturePK=@OpportunityID)
		DELETE FROM  COM_Contacts 
		WHERE FeatureID=89 and  FeaturePK=@OpportunityID
			
		--Update left and right extent to set the tree
		UPDATE CRM_Opportunities SET rgt = rgt - @Width WHERE rgt > @rgt;
		UPDATE CRM_Opportunities SET lft = lft - @Width WHERE lft > @rgt;
	

 
SET NOCOUNT OFF;  
SELECT ErrorMessage,ErrorNumber FROM COM_ErrorMessages WITH(nolock) 
WHERE ErrorNumber=102 AND LanguageID=@LangID

RETURN @RowsDeleted
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
