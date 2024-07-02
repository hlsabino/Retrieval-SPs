USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spCRM_DeleteLead]
	@LeadID [int] = 0,
	@RoleID [int] = 1,
	@LangID [int] = 1
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRANSACTION
BEGIN TRY  
SET NOCOUNT ON;  

		--Declaration Section
		DECLARE @HasAccess bit,@RowsDeleted INT,@lft INT,@rgt INT,@Width INT,@retVal int

		--SP Required Parameters Check
		if(@LeadID=0)
		BEGIN
			RAISERROR('-100',16,1)
		END
		
			--User acces check
		SET @HasAccess=dbo.fnCOM_HasAccess(@RoleID,86,4)

		IF @HasAccess=0
		BEGIN
			RAISERROR('-105',16,1)
		END
		

		IF(SELECT ParentID FROM CRM_Leads WITH(NOLOCK) WHERE LeadID=@LeadID)=0
		BEGIN
			RAISERROR('-117',16,1)
		END
		
		--ondelete External function
		IF (@LeadID>0)
		BEGIN
			DECLARE @tablename NVARCHAR(200)
			set @tablename=''
			select @tablename=SpName from ADM_DocFunctions a WITH(NOLOCK) where CostCenterID=86 and Mode=8
			if(@tablename<>'')
				exec @tablename 86,@LeadID,'',1,@LangID	
		END	
		
		declare @Tbl as table(id int identity(1,1),LeadID INT)
		
		--Fetch left, right extent of Node along with width.
		SELECT @lft = lft, @rgt = rgt, @Width = rgt - lft + 1
		FROM CRM_Leads WITH(NOLOCK) WHERE LeadID=@LeadID
		
		if exists(SELECT * FROM CRM_Leads WITH(NOLOCK) WHERE LeadID=@LeadID and IsGroup=1)
		BEGIN
			insert into @Tbl(LeadID)
			select LeadID  from CRM_Leads with(nolock) WHERE lft >= @lft AND rgt <= @rgt and IsGroup=0
		END
		else
			insert into @Tbl(LeadID)values(@LeadID)

		IF(EXISTS(SELECT * FROM [INV_DocDetails] a WITH(NOLOCK) 
		join @Tbl b on a.RefNodeid=b.leadid
		WHERE RefCCID=86))
		BEGIN
			RAISERROR('-110',16,1)
		END
		
		IF(EXISTS(SELECT * FROM [ACC_DocDetails] a WITH(NOLOCK) 
		join @Tbl b on a.RefNodeid=b.leadid
		WHERE RefCCID=86))
		BEGIN
			RAISERROR('-110',16,1)
		END
		 
		IF(EXISTS(SELECT * FROM CRM_Opportunities a WITH(NOLOCK)
		join @Tbl b on a.ConvertFromLeadID=b.leadid))
		BEGIN
			RAISERROR('-110',16,1)
		END 
		
		IF(EXISTS(SELECT * FROM CRM_Customer a WITH(NOLOCK)
		join @Tbl b on a.ConvertFromLeadID=b.leadid))
		BEGIN
			RAISERROR('-110',16,1)
		END
		
		IF(EXISTS(SELECT VALUE FROM COM_COSTCENTERPREFERENCES WITH(NOLOCK) WHERE COSTCENTERID=86 AND NAME='LinkDimension'))
		BEGIN
			DECLARE @DIMID INT=0,@CCID INT
			SELECT @DIMID=VALUE FROM COM_COSTCENTERPREFERENCES WITH(NOLOCK) WHERE COSTCENTERID=86 AND NAME='LinkDimension'
			IF(@DIMID>=50000)
			BEGIN
				
				SELECT @CCID=CCLEADID FROM CRM_LEADS WITH(NOLOCK) WHERE LEADID=@LeadID	
				IF @CCID>1	 
				BEGIN
						EXEC @retVal=[spCOM_DeleteCostCenter] @DIMID,@CCID,1,1,1,0
						
						if(@retVal=-999)
							return -999
				END		
			END
			
		END	
		 
		--Delete from exteneded table
		DELETE a FROM CRM_LeadsExtended a WITH(NOLOCK)
		join @Tbl b on a.LeadID=b.LeadID
		
			--Delete from CostCenter Mapping
		DELETE a FROM COM_CCCCDATA a WITH(NOLOCK)
		join @Tbl b on a.NodeID=b.LeadID
		WHERE CostCenterID=86 

		DELETE a FROM crm_assignment a WITH(NOLOCK)
		join @Tbl b on a.CCNODEID=b.LeadID
		 WHERE CCID=86  
		 
		DELETE a FROM CRM_ACTIVITIES a WITH(NOLOCK)
		join @Tbl b on a.NodeID=b.LeadID
		 WHERE CostCenterID=86  
		 
		--Delete from main table
		DELETE a FROM CRM_Leads a WITH(NOLOCK)
		join @Tbl b on a.LeadID=b.LeadID

		SET @RowsDeleted=@@rowcount
 
		--Update left and right extent to set the tree
		UPDATE CRM_Leads SET rgt = rgt - @Width WHERE rgt > @rgt;
		UPDATE CRM_Leads SET lft = lft - @Width WHERE lft > @rgt;
		
		DELETE a FROM  COM_ContactsExtended a WITH(NOLOCK)
		join COM_CONTACTS b WITH(NOLOCK) on a.CONTACTID=b.CONTACTID
		join @Tbl c on b.featurepk=c.LeadID
		where featureid=86
		
		Delete a from COM_Contacts a WITH(NOLOCK)
		join @Tbl b on a.featurepk=b.LeadID
		where featureid=86		
		
		Delete a from CRM_Contacts a WITH(NOLOCK)
		join @Tbl b on a.featurepk=b.LeadID
		where featureid=86
		
		
		Delete a From CRM_ProductMapping a WITH(NOLOCK)
		join @Tbl b on a.ccnodeid=b.LeadID 
		where costcenterid=86
		
		Delete a From CRM_LeadCVRDetails a WITH(NOLOCK)
		join @Tbl b on a.ccnodeid=b.LeadID 
		where CCID=86
		
		Delete a From CRM_Feedback a WITH(NOLOCK)
		join @Tbl b on a.ccnodeid=b.LeadID 
		where CCID=86
		 		 
		update a
		 set  ConvertedLeadID=0 
		 from CRM_CampaignResponse a WITH(NOLOCK)
		 join @Tbl b on a.ConvertedLeadID=b.LeadID
		  
		 update a
		 set  ConvertedLeadID=0 
		 from CRM_CampaignInvites a WITH(NOLOCK)
		 join @Tbl b on a.ConvertedLeadID=b.LeadID
		  
		   
		
		
COMMIT TRANSACTION
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
