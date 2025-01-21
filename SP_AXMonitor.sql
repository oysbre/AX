/****** Object:  StoredProcedure [dbo].[AXMissingIndexesMonitor]    Script Date: 26.07.2021 17:52:41 ******/
DROP PROCEDURE IF EXISTS [dbo].[AXMissingIndexesMonitor]
GO
/****** Object:  StoredProcedure [dbo].[AXMissingIndexesMonitor]    Script Date: 26.07.2021 17:52:41 ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AXMissingIndexesMonitor]') AND type in (N'P', N'PC'))
BEGIN
EXEC dbo.sp_executesql @statement = N'CREATE PROCEDURE [dbo].[AXMissingIndexesMonitor] AS' 
END
GO
--SELECT * FROM AXTopMissingIndexesLog
ALTER PROCEDURE [dbo].[AXMissingIndexesMonitor]
@DBName nvarchar(60) = '<dbname>',
@SendEmailOperator nvarchar(60) = '',
@DisplayOnlyNewRecommendation int = 0,
@Debug int = 0
AS
BEGIN

	SET NOCOUNT ON;
	SET ANSI_NULLS OFF;

	DECLARE @DBID int = db_id(@DBName);

	DECLARE @NewMissingIndexesTbl TABLE 
	(	[tabname] [nvarchar](128) NULL,
		[DatabaseName] [nvarchar](128) NULL,
		[equality_columns] [nvarchar](4000) NULL,
		[inequality_columns] [nvarchar](4000) NULL,
		[avg_user_impact] numeric(18, 2) NULL,
		[included_columns] [nvarchar](4000) NULL,
		[user_seeks] [bigint] NOT NULL,
		[user_scans] [bigint] NOT NULL )

	INSERT INTO @NewMissingIndexesTbl

	SELECT TOP 50  object_name(d.object_id, d.database_id) as tabname, DB_NAME(database_id) AS DatabaseName, equality_columns, inequality_columns, avg_user_impact, included_columns,
	   user_seeks, user_scans
	FROM    sys.dm_db_missing_index_details d
	INNER JOIN sys.dm_db_missing_index_groups g
		ON    d.index_handle = g.index_handle
	INNER JOIN sys.dm_db_missing_index_group_stats s
		ON    g.index_group_handle = s.group_handle
	WHERE    database_id = @DBID
	ORDER BY  avg_total_user_cost * avg_user_impact *(user_seeks + user_scans) DESC 

	--Delete all less than 99
	DELETE @NewMissingIndexesTbl
		WHERE [avg_user_impact] < 99


	--Delete the previous recomendations
	IF (@DisplayOnlyNewRecommendation = 1)
	BEGIN
		DELETE FROM curLog
		from   @NewMissingIndexesTbl as curLog
		WHERE EXISTS (SELECT * FROM dbo.AXTopMissingIndexesLog prevLog
					  WHERE prevLog.[tabname]               = curLog.[tabname]
						AND prevLog.[DatabaseName]          = curLog.[DatabaseName]
						AND prevLog.[equality_columns]      = curLog.[equality_columns]
						AND COALESCE(prevLog.[inequality_columns], '')    = COALESCE(curLog.[inequality_columns], ''));
	END
	IF (@DisplayOnlyNewRecommendation = 0)
	BEGIN
		DELETE FROM curLog
		from   @NewMissingIndexesTbl as curLog
		WHERE EXISTS (SELECT * FROM dbo.AXTopMissingIndexesLog prevLog
					  WHERE prevLog.[tabname]               = curLog.[tabname]
						AND prevLog.[DatabaseName]          = curLog.[DatabaseName]
						AND prevLog.[equality_columns]      = curLog.[equality_columns]
						AND prevLog.IsApproved              = 1 
						AND COALESCE(prevLog.[inequality_columns], '')    = COALESCE(curLog.[inequality_columns], ''));
	END

	INSERT INTO [dbo].[AXTopMissingIndexesLog]
			   ([LogDateTime]
			   ,[tabname]
			   ,[DatabaseName]
			   ,[equality_columns]
			   ,[inequality_columns]
			   ,[avg_user_impact]
			   ,[included_columns]
			   ,[user_seeks]
			   ,[user_scans])
	   SELECT    GETDATE()
				,[tabname]
			   ,[DatabaseName]
			   ,[equality_columns]
			   ,[inequality_columns]
			   ,[avg_user_impact]
			   ,[included_columns]
			   ,[user_seeks]
			   ,[user_scans] FROM @NewMissingIndexesTbl

	SELECT * FROM @NewMissingIndexesTbl;


	--Send a notification

	DECLARE @NumOfRec INT
	SELECT @NumOfRec = count(*) FROM @NewMissingIndexesTbl

	IF @SendEmailOperator <> '' AND @NumOfRec > 0
	BEGIN
			DECLARE @Msg NVARCHAR(max)
			DECLARE @HTMLStr NVARCHAR(max)

			SET @Msg = N'AX Missing indexes alert';

			DECLARE @oper_email NVARCHAR(100)
			SET @oper_email = (SELECT email_address from msdb.dbo.sysoperators WHERE name = @SendEmailOperator)
			DECLARE @body NVARCHAR(MAX)
			SET     @body = N'<table>'
				+ N'<tr><th>TABLE</th><th>Database</th><th>Equality columns</th><th>Inequality_columns</th><th>Avg. impact</th><th>Included columns</th></tr>'
				+ CAST((
					SELECT [tabname]  AS td
						   ,[DatabaseName] AS td
						   ,[equality_columns] AS td
						   ,COALESCE([inequality_columns], '') AS td
						   ,[avg_user_impact] AS td
						   ,COALESCE([included_columns], '') AS td FROM @NewMissingIndexesTbl
						FOR XML RAW('tr'), ELEMENTS
				) AS NVARCHAR(MAX))
				+ N'</table>'

			SET @body = REPLACE(@body, '<tdc>', '<td class="center">');
			SET @body = REPLACE(@body, '</tdc>', '</td>');

			SET @HTMLStr = N'<html><body>' + @Msg + N'<br><br>' + @body + N'</body></html>';
			IF @Debug <> 0
				SELECT @HTMLStr  --DEBUG
			--SET @oper_email = 'trud81@gmail.com'  --DEBUG
			ELSE
				EXEC msdb.dbo.sp_send_dbmail  @profile_name = N'Main', @recipients = @oper_email, @subject = @Msg,  @body = @HTMLStr,  @body_format = 'HTML' ;
	END;
END

GO

/****** Object:  StoredProcedure [dbo].[AXTopQueryLogMonitor]    Script Date: 5/23/2021 7:09:06 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AXTopQueryLogMonitor]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[AXTopQueryLogMonitor]
GO
/****** Object:  StoredProcedure [dbo].[AXTopQueryLogMonitor]    Script Date: 5/23/2021 7:09:06 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
/*

--Create a SQL Agent job that calls the SP AXTopQueryLogMonitor and run it every 30 minutes during work hours preferably
EXEC msdb.dbo.[AXTopQueryLogMonitor] @MinPlanTimeMin = 30, @MaxRowToSave = 3, @SendEmailOperator = '', @DaysKeepHistory = 62
--Approve query
EXEC msdb.dbo.AXTopQueryMarkAsApproved @LogId = 30, @ApprovedText = 'That is good'
--Analyse queries
SELECT * FROM [msdb].[dbo].[AXTopQueryLog] order by LogDateTime desc, Id
SELECT * from [msdb].[dbo].[AXTopQueryLog] where id = 250

*/
-- =============================================
CREATE PROCEDURE [dbo].[AXTopQueryLogMonitor] 

@MinPlanTimeMin INT = 30,
@MaxRowToSave INT = 3,
@SendEmailOperator nvarchar(60) = '',
@DaysKeepHistory INT = 62
AS
BEGIN
	SET NOCOUNT ON;


DECLARE @NewInsertedTbl TABLE (Id INT, [query_plan_hash] binary(8), [query_hash] binary(8))

INSERT INTO dbo.AXTopQueryLog([LogDateTime]
	,[DataBase]
	,[TEXT]
	,[execution_count]
	,[last_elapsed_time_in_mS]
	,[total_logical_reads]
        ,[last_logical_reads]
	,[min_logical_reads] 
	,[max_logical_reads] 
        ,[total_logical_writes]
        ,[last_logical_writes]
        ,[last_physical_reads]
        ,[total_physical_reads]
        ,[total_worker_time_in_S]
        ,[last_worker_time_in_mS]
	,[min_worker_time_in_mS]
	,[max_worker_time_in_mS]
        ,[total_elapsed_time_in_S]
        ,[last_execution_time]
        ,[Age of the Plan(Minutes)]
        ,[Has 99%]
	,[query_plan]
        ,[query_hash]
        ,[query_plan_hash]
	,[IsApprovedQuery]) 
OUTPUT INSERTED.Id, INSERTED.query_plan_hash, INSERTED.query_hash INTO @NewInsertedTbl(Id, [query_plan_hash], [query_hash])
SELECT [LogDateTime]
	,[DataBase]
        ,[TEXT]
        ,[execution_count]
        ,[last_elapsed_time_in_mS]
        ,[total_logical_reads]
        ,[last_logical_reads]
	,[min_logical_reads] 
	,[max_logical_reads] 
        ,[total_logical_writes]
        ,[last_logical_writes]
        ,[last_physical_reads]
        ,[total_physical_reads]
        ,[total_worker_time_in_S]
        ,[last_worker_time_in_mS]
	,[min_worker_time_in_mS]
	,[max_worker_time_in_mS]
        ,[total_elapsed_time_in_S]
        ,[last_execution_time]
        ,[Age of the Plan(Minutes)]
        ,[Has 99%]
	,[query_plan]
        ,[query_hash]
        ,[query_plan_hash]
	,[IsApprovedQuery]) 
	FROM (
SELECT TOP (@MaxRowToSave)
 GETDATE() as LogDateTime,
DB_NAME(CONVERT(int, qpa.value)) as [DataBase],
SUBSTRING(qt.TEXT, (qs.statement_start_offset/2)+1,
((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.TEXT) ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1)
as [TEXT],
qs.execution_count,
qs.last_elapsed_time/1000 last_elapsed_time_in_mS,
qs.total_logical_reads, qs.last_logical_reads,
qs.min_logical_reads, qs.max_logical_reads,
qs.total_logical_writes, qs.last_logical_writes,
qs.last_physical_reads, qs.total_physical_reads,
qs.total_worker_time/1000000 total_worker_time_in_S,
qs.last_worker_time/1000 last_worker_time_in_mS,
qs.min_worker_time/1000 min_worker_time_in_mS,
qs.max_worker_time/1000 max_worker_time_in_mS,
qs.total_elapsed_time/1000000 total_elapsed_time_in_S,
qs.last_execution_time,
DATEDIFF(MI,creation_time,GETDATE()) AS [Age of the Plan(Minutes)],
CASE WHEN cast(qp.query_plan  as nvarchar(max)) LIKE N'%<MissingIndexGroup Impact="99%' THEN '!Has 99' ELSE '' END AS [Has 99%] ,
qp.query_plan,
qs.query_hash,
qs.query_plan_hash,
COALESCE((SELECT TOP 1 [IsApprovedQuery]
     FROM [AXTopQueryLogApproved] AS InnerLog
     WHERE InnerLog.query_plan_hash = qs.query_plan_hash AND
		 InnerLog.query_hash = qs.query_hash), 0) AS IsApprovedQuery

FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
CROSS APPLY sys.dm_exec_plan_attributes(qs.plan_handle) qpa
CROSS APPLY sys.dm_exec_text_query_plan(qs.plan_handle, qs.statement_start_offset, qs.statement_end_offset) etqp
where attribute = 'dbid'
and qt.text like '%SELECT%' COLLATE SQL_Latin1_General_CP1_CS_AS /* filter on SELECT queries */
and CAST(etqp.query_plan AS nvarchar(max)) NOT LIKE ('%PlanGuideName%')  /* exclude plans that alrady have a planguide */
AND (qs.min_worker_time / 1000000.) * 100. < (qs.max_worker_time / 1000000.) /* ratio CPU workertime indicate parametersniffing issue */
and qs.max_worker_time/ 1000.0 > 2000 /* collect queries that use more than 2 sec in CPU maxworkertime */
ORDER BY qs.max_worker_time DESC) A
WHERE A.[Age of the Plan(Minutes)] > @MinPlanTimeMin;

-- DBCC FREEPROCCACHE to reset the counter
--,[IsApprovedQuery]

--DELETE FETCH Cursor
DELETE @NewInsertedTbl
	where query_plan_hash = 0x0000000000000000;

--UPDATE prev records
UPDATE AXTopQueryLogApproved
	SET LogDateTime = GETDATE() 
FROM AXTopQueryLogApproved c
    INNER JOIN @NewInsertedTbl t
        ON c.query_plan_hash = t.query_plan_hash AND c.query_hash = t.query_hash; 

--DELETE prev records

DELETE FROM o1
from   @NewInsertedTbl as o1
WHERE EXISTS (SELECT * FROM AXTopQueryLogApproved la
              WHERE la.query_plan_hash = o1.query_plan_hash
                AND la.query_hash      = o1.query_hash);

DECLARE @NumOfRec INT
SELECT @NumOfRec = count(*) FROM @NewInsertedTbl

IF @SendEmailOperator <> '' AND @NumOfRec > 0
BEGIN
        DECLARE @Msg NVARCHAR(max)
        DECLARE @HTMLStr NVARCHAR(max)

        SET @Msg = N'AX new TOP query Alert';

        DECLARE @oper_email NVARCHAR(100)
        SET @oper_email = (SELECT email_address from msdb.dbo.sysoperators WHERE name = @SendEmailOperator)

        DECLARE @body NVARCHAR(MAX)
        SET     @body = N'<table>'
            + N'<tr><th>ID</th><th>Database</th><th>Execution count</th><th>TEXT</th></tr>'
            + CAST((
                SELECT l.Id AS td, 
					   l.[DataBase]  AS td,
					   l.execution_count AS td,
					   l.[TEXT]  AS td
				FROM AXTopQueryLog l
				INNER JOIN @NewInsertedTbl t  ON t.Id = l.Id
                    FOR XML RAW('tr'), ELEMENTS
            ) AS NVARCHAR(MAX))
            + N'</table>'

        SET @body = REPLACE(@body, '<tdc>', '<td class="center">');
        SET @body = REPLACE(@body, '</tdc>', '</td>');

		--get CPU usage history
		DECLARE @ts_now bigint = (SELECT cpu_ticks/(cpu_ticks/ms_ticks)FROM sys.dm_os_sys_info); 

        DECLARE @body2 NVARCHAR(MAX)
        SET     @body2 = N'<table>'
            + N'<tr><th>SQL Server CPU Utilization</th><th>System Idle</th><th>Other Process CPU</th><th>Event Time</th></tr>'
            + CAST((
			SELECT TOP(20) SQLProcessUtilization AS td, 
               SystemIdle AS td, 
               100 - SystemIdle - SQLProcessUtilization AS td, 
               DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS td
			FROM ( 
				  SELECT record.value('(./Record/@id)[1]', 'int') AS record_id, 
						record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') 
						AS [SystemIdle], 
						record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 
						'int') 
						AS [SQLProcessUtilization], [timestamp] 
				  FROM ( 
						SELECT [timestamp], CONVERT(xml, record) AS [record] 
						FROM sys.dm_os_ring_buffers 
						WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
						AND record LIKE '%<SystemHealth>%') AS x 
				  ) AS y 
			ORDER BY record_id DESC
                    FOR XML RAW('tr'), ELEMENTS
            ) AS NVARCHAR(MAX))
            + N'</table>'

        SET @body2 = REPLACE(@body2, '<tdc>', '<td class="center">');
        SET @body2 = REPLACE(@body2, '</tdc>', '</td>');


        SET @HTMLStr = N'<html><body>' + @Msg + N'<br><br>' + @body  + N'<br><b>CPU Usage</b><br>' + @body2 + N'</body></html>';


        --SELECT @HTMLStr  --DEBUG
        --SET @oper_email = 'trud81@gmail.com'  --DEBUG

        EXEC msdb.dbo.sp_send_dbmail  @recipients = @oper_email, @subject = @Msg,  @body = @HTMLStr,  @body_format = 'HTML' ;
END;

--INSERT new records
INSERT INTO [dbo].[AXTopQueryLogApproved]
           ([LogDateTime]
           ,[DataBase]
           ,[TEXT]
           ,[query_hash]
           ,[query_plan_hash]
           )
SELECT GETDATE(), 
	   l.[DataBase],
	   l.[TEXT],
	   l.query_hash,
	   l.query_plan_hash
FROM AXTopQueryLog l
INNER JOIN @NewInsertedTbl t  ON t.Id = l.Id;

IF @DaysKeepHistory > 0
BEGIN
	DECLARE @TruncDate datetime
	SET @TruncDate = DATEADD(day, -1 * @DaysKeepHistory, GETDATE())

	DELETE AXTopQueryLog
		WHERE LogDateTime < @TruncDate;
	
	DELETE AXTopQueryLogApproved
		WHERE LogDateTime < @TruncDate AND IsApprovedQuery = 0;
END;



END
GO

/****** Object:  StoredProcedure [dbo].[AXTopQueryMarkAsApproved]    Script Date: 5/23/2021 7:09:06 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AXTopQueryMarkAsApproved]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[AXTopQueryMarkAsApproved]
GO
/****** Object:  StoredProcedure [dbo].[AXTopQueryMarkAsApproved]    Script Date: 5/23/2021 7:09:06 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[AXTopQueryMarkAsApproved]
	@LogId INT,
	@ApprovedText nvarchar(128) = ''
AS
BEGIN
	SET NOCOUNT ON;

	declare @query_hash binary(8),  @query_plan_hash binary(8);

select 
    @query_hash = query_hash,
    @query_plan_hash = query_plan_hash
from dbo.AXTopQueryLog
where Id = @LogId;

IF @query_hash IS NOT NULL
BEGIN
	UPDATE dbo.AXTopQueryLogApproved
		SET IsApprovedQuery = 1, ApprovedText = @ApprovedText, ApprovedDate = GETDATE()
	WHERE query_hash = @query_hash AND query_plan_hash = @query_plan_hash;

	UPDATE dbo.AXTopQueryLog
		SET IsApprovedQuery = 1
	WHERE query_hash = @query_hash AND query_plan_hash = @query_plan_hash;
END
ELSE 
	BEGIN
	DECLARE @ErrorText nvarchar(30)
	SET @ErrorText = 'Log id ' + CAST(@LogId as nvarchar(10)) + ' doesnt exist';

	RAISERROR(@ErrorText, 16, 1);
	END
END
GO
