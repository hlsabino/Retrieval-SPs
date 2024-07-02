USE PACT2C276
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[spADM_SetLog]
	@LogType [nvarchar](20),
	@CommandText [nvarchar](max) = NULL,
	@ErrorMsg [nvarchar](max) = NULL,
	@CallFrom [nvarchar](200) = NULL
WITH ENCRYPTION, EXECUTE AS CALLER
AS
BEGIN TRY  
SET NOCOUNT ON;

	if @LogType='GETLOGDATA'
	begin
		select top 10 * from ADM_Logs with(nolock) 
		where LogTime<getdate()
		order by CallFrom asc
	end
	else
	begin
		if(select COUNT(LogTime) from ADM_Logs with(nolock))>5000
			delete from ADM_Logs where LogTime<DATEADD(DAY,-30,getdate())
			
		INSERT INTO ADM_Logs(LogTime,LogType,CommandText,ErrorMsg,CallFrom)
		VALUES(GETDATE(),@LogType,@CommandText,@ErrorMsg,@CallFrom)
	end
  
SET NOCOUNT OFF;  
END TRY  
BEGIN CATCH  
	SET NOCOUNT OFF  
END CATCH 
GO
