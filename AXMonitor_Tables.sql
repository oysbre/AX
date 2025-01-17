/* create tables for AX monitor logs */
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AXTopMissingIndexesLog]') AND type in (N'U'))
ALTER TABLE [dbo].[AXTopMissingIndexesLog] DROP CONSTRAINT IF EXISTS [DF_AXTopMissingIndexesLog_ApprovedText]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AXTopMissingIndexesLog]') AND type in (N'U'))
ALTER TABLE [dbo].[AXTopMissingIndexesLog] DROP CONSTRAINT IF EXISTS [DF_AXTopMissingIndexesLog_IsApproved]
GO

/****** Object:  Table [dbo].[AXTopMissingIndexesLog]    Script Date: 26.07.2021 17:52:41 ******/
DROP TABLE IF EXISTS [dbo].[AXTopMissingIndexesLog]
GO

/****** Object:  Table [dbo].[AXTopMissingIndexesLog]    Script Date: 26.07.2021 17:52:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AXTopMissingIndexesLog]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[AXTopMissingIndexesLog](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[LogDateTime] [datetime] NOT NULL,
	[tabname] [nvarchar](128) NULL,
	[DatabaseName] [nvarchar](128) NULL,
	[equality_columns] [nvarchar](4000) NULL,
	[inequality_columns] [nvarchar](4000) NULL,
	[avg_user_impact] [numeric](18, 2) NULL,
	[included_columns] [nvarchar](4000) NULL,
	[user_seeks] [bigint] NOT NULL,
	[user_scans] [bigint] NOT NULL,
	[IsApproved] [bit] NOT NULL,
	[ApprovedText] [nvarchar](50) NOT NULL
) ON [PRIMARY]
END
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_AXTopMissingIndexesLog_IsApproved]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[AXTopMissingIndexesLog] ADD  CONSTRAINT [DF_AXTopMissingIndexesLog_IsApproved]  DEFAULT ((0)) FOR [IsApproved]
END

GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_AXTopMissingIndexesLog_ApprovedText]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[AXTopMissingIndexesLog] ADD  CONSTRAINT [DF_AXTopMissingIndexesLog_ApprovedText]  DEFAULT ('') FOR [ApprovedText]
END

GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_AXTopQueryLog_IsApprovedQuery]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[AXTopQueryLog] DROP CONSTRAINT [DF_AXTopQueryLog_IsApprovedQuery]
END
GO

/****** Object:  Table [dbo].[AXTopQueryLog]    Script Date: 5/23/2021 7:09:06 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AXTopQueryLog]') AND type in (N'U'))
DROP TABLE [dbo].[AXTopQueryLog]
GO

/****** Object:  Table [dbo].[AXTopQueryLog]    Script Date: 5/23/2021 7:09:06 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AXTopQueryLog](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[LogDateTime] [datetime] NOT NULL,
	[DataBase] [nvarchar](128) NOT NULL,
	[TEXT] [nvarchar](max) NOT NULL,
	[execution_count] [bigint] NOT NULL,
	[last_elapsed_time_in_mS] [bigint] NOT NULL,
	[total_logical_reads] [bigint] NOT NULL,
	[last_logical_reads] [bigint] NOT NULL,
	[min_logical_reads] [bigint] NOT NULL,
	[max_logical_reads] [bigint] NOT NULL,
	[total_logical_writes] [bigint] NOT NULL,
	[last_logical_writes] [bigint] NOT NULL,
	[last_physical_reads] [bigint] NOT NULL,
	[total_physical_reads] [bigint] NOT NULL,
	[total_worker_time_in_S] [bigint] NOT NULL,
	[last_worker_time_in_mS] [bigint] NOT NULL,
	[min_worker_time_in_mS] [bigint] NOT NULL,
	[max_worker_time_in_mS] [bigint] NOT NULL,
	[total_elapsed_time_in_S] [bigint] NOT NULL,
	[last_execution_time] [datetime] NOT NULL,
	[Age of the Plan(Minutes)] [int] NOT NULL,
	[Has 99%] [varchar](7) NOT NULL,
	[query_plan] [xml] NOT NULL,
	[query_hash] [binary](8) NOT NULL,
	[query_plan_hash] [binary](8) NOT NULL,
	[IsApprovedQuery] [int] NOT NULL,
 CONSTRAINT [PK_AXTopQueryLog] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[AXTopQueryLog] ADD  CONSTRAINT [DF_AXTopQueryLog_IsApprovedQuery]  DEFAULT ((0)) FOR [IsApprovedQuery]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_AXTopQueryLogApproved_ApprovedText]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[AXTopQueryLogApproved] DROP CONSTRAINT [DF_AXTopQueryLogApproved_ApprovedText]
END
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DF_AXTopQueryLogApproved_IsApprovedQuery]') AND type = 'D')
BEGIN
ALTER TABLE [dbo].[AXTopQueryLogApproved] DROP CONSTRAINT [DF_AXTopQueryLogApproved_IsApprovedQuery]
END
GO

/****** Object:  Table [dbo].[AXTopQueryLogApproved]    Script Date: 5/23/2021 7:09:06 PM ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[AXTopQueryLogApproved]') AND type in (N'U'))
DROP TABLE [dbo].[AXTopQueryLogApproved]
GO

/****** Object:  Table [dbo].[AXTopQueryLogApproved]    Script Date: 5/23/2021 7:09:06 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AXTopQueryLogApproved](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[LogDateTime] [datetime] NOT NULL,
	[DataBase] [nvarchar](128) NOT NULL,
	[TEXT] [nvarchar](max) NOT NULL,
	[query_hash] [binary](8) NOT NULL,
	[query_plan_hash] [binary](8) NOT NULL,
	[IsApprovedQuery] [int] NOT NULL,
	[ApprovedText] [nvarchar](128) NOT NULL,
	[ApprovedDate] [datetime] NULL,
 CONSTRAINT [PK_AXTopQueryLogApproved] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[AXTopQueryLogApproved] ADD  CONSTRAINT [DF_AXTopQueryLogApproved_IsApprovedQuery]  DEFAULT ((0)) FOR [IsApprovedQuery]
GO
ALTER TABLE [dbo].[AXTopQueryLogApproved] ADD  CONSTRAINT [DF_AXTopQueryLogApproved_ApprovedText]  DEFAULT ('') FOR [ApprovedText]
GO