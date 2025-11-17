-- Snowflake Demo Setup Script for Predictive Maintenance Intelligence

-- Assumptions:
-- - A Snowflake Git repository object will be created pointing to your GitHub repo
-- - Branch 'main' contains `demo_data/` and `unstructured_docs/`
-- - Execute with a role that can create roles, warehouses, DBs, schemas, API integrations, and git repositories

-- 1) Role and Warehouse
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE WAREHOUSE PREDICTIVE_MAINT_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;

-- 2) Database and Schema
CREATE OR REPLACE DATABASE PREDICTIVE_MAINT_DB;
CREATE OR REPLACE SCHEMA PREDICTIVE_MAINT_DB.DEMO;

USE WAREHOUSE PREDICTIVE_MAINT_WH;
USE DATABASE PREDICTIVE_MAINT_DB;
USE SCHEMA DEMO;

-- 3) Git Integration (update ORIGIN to your GitHub URL)
-- Optionally create a secret for Git credentials if needed
-- CREATE OR REPLACE SECRET GIT_CRED TYPE = 'PASSWORD' USERNAME = '<GIT_USER>' PASSWORD = '<GIT_TOKEN>'; -- if using private repo

CREATE OR REPLACE API INTEGRATION PREDICTIVE_MAINT_GIT_API
  API_PROVIDER = git_https_api
  API_ALLOWED_PREFIXES = ('https://github.com/ReginaLin24')
  ENABLED = TRUE;

CREATE OR REPLACE GIT REPOSITORY PREDICTIVE_MAINT_REPO
  API_INTEGRATION = PREDICTIVE_MAINT_GIT_API
  ORIGIN = 'https://github.com/ReginaLin24/predictive_maintenance_demo.git';

ALTER GIT REPOSITORY PREDICTIVE_MAINT_REPO FETCH;

-- File format and internal stage for copying repo files
CREATE OR REPLACE FILE FORMAT CSV_FORMAT
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  RECORD_DELIMITER = '\n'
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  TRIM_SPACE = TRUE
  ERROR_ON_COLUMN_COUNT_MISMATCH = FALSE
  ESCAPE = 'NONE'
  ESCAPE_UNENCLOSED_FIELD = '\\134'
  DATE_FORMAT = 'YYYY-MM-DD'
  TIMESTAMP_FORMAT = 'YYYY-MM-DD HH24:MI:SS'
  NULL_IF = ('NULL','null','','N/A','n/a');

CREATE OR REPLACE STAGE INTERNAL_DATA_STAGE
  FILE_FORMAT = CSV_FORMAT
  COMMENT = 'Internal stage for copied demo data files'
  DIRECTORY = (ENABLE = TRUE)
  ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE');

-- Copy repo files into internal stage for consistent loading
COPY FILES
INTO @INTERNAL_DATA_STAGE/demo_data/
FROM @PREDICTIVE_MAINT_REPO/branches/main/demo_data/;

COPY FILES
INTO @INTERNAL_DATA_STAGE/unstructured_docs/
FROM @PREDICTIVE_MAINT_REPO/branches/main/unstructured_docs/;

-- Optional verification
LS @INTERNAL_DATA_STAGE;
ALTER STAGE INTERNAL_DATA_STAGE REFRESH;

-- 4) Create Tables

-- Pump telemetry data (time-series sensor readings)
CREATE OR REPLACE TABLE PUMP_TELEMETRY (
  PUMP_ID STRING,
  TIMESTAMP TIMESTAMP_NTZ,
  PUMP_VIBRATION_RMS FLOAT,
  FLOW_RATE_LPS FLOAT,
  PIPE_PRESSURE_PSI FLOAT,
  CHLORINE_LEVEL_PPM FLOAT
);

-- Asset master data (pump metadata and location)
CREATE OR REPLACE TABLE ASSET_MASTER (
  PUMP_ID STRING PRIMARY KEY,
  MODEL STRING,
  LATITUDE FLOAT,
  LONGITUDE FLOAT,
  WARRANTY_EXPIRY_DATE DATE,
  SERVICE_AGE_DAYS INT
);

-- Incident log (maintenance incidents and patient impact)
CREATE OR REPLACE TABLE INCIDENT_LOG (
  INCIDENT_ID STRING PRIMARY KEY,
  PUMP_ID STRING,
  DATE DATE,
  INCIDENT_TYPE STRING,
  PATIENT_IMPACT STRING
);

-- Fault codes reference table
CREATE OR REPLACE TABLE FAULT_CODES (
  FAULT_CODE STRING PRIMARY KEY,
  DESCRIPTION STRING,
  COMPONENT_IMPACT STRING
);

-- Fault history (historical fault occurrences)
CREATE OR REPLACE TABLE FAULT_HISTORY (
  FAULT_HISTORY_ID STRING PRIMARY KEY,
  PUMP_ID STRING,
  FAULT_CODE STRING,
  FAULT_DATE DATE,
  RESET_METHOD STRING
);

-- Table to store maintenance reports as rows for Cortex Search
CREATE OR REPLACE TABLE MAINTENANCE_REPORTS (
  FILE_NAME STRING,
  CONTENT VARCHAR,
  PUMP_ID STRING,
  INCIDENT_ID STRING
);

-- 5) Load data from internal stage

COPY INTO PUMP_TELEMETRY
  FROM @INTERNAL_DATA_STAGE/demo_data/pump_telemetry.csv
  FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO ASSET_MASTER
  FROM @INTERNAL_DATA_STAGE/demo_data/asset_master.csv
  FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO INCIDENT_LOG
  FROM @INTERNAL_DATA_STAGE/demo_data/incident_log.csv
  FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO FAULT_CODES
  FROM @INTERNAL_DATA_STAGE/demo_data/fault_codes.csv
  FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

COPY INTO FAULT_HISTORY
  FROM @INTERNAL_DATA_STAGE/demo_data/fault_history.csv
  FILE_FORMAT = (TYPE = CSV FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);

-- Load maintenance reports with metadata extraction
COPY INTO MAINTENANCE_REPORTS
FROM (
  SELECT
    METADATA$FILENAME,
    $1,
    REGEXP_SUBSTR(METADATA$FILENAME, 'PUMP_[0-9]+') AS PUMP_ID,
    REGEXP_SUBSTR(METADATA$FILENAME, 'INC_[0-9]+') AS INCIDENT_ID
  FROM @INTERNAL_DATA_STAGE/unstructured_docs/maintenance_reports/
)
FILE_FORMAT = (
  TYPE = 'CSV',
  FIELD_DELIMITER = NONE,
  RECORD_DELIMITER = NONE
);

-- Verify data loaded
SELECT 'PUMP_TELEMETRY' AS TABLE_NAME, COUNT(*) AS ROW_COUNT FROM PUMP_TELEMETRY
UNION ALL
SELECT 'ASSET_MASTER', COUNT(*) FROM ASSET_MASTER
UNION ALL
SELECT 'INCIDENT_LOG', COUNT(*) FROM INCIDENT_LOG
UNION ALL
SELECT 'FAULT_CODES', COUNT(*) FROM FAULT_CODES
UNION ALL
SELECT 'FAULT_HISTORY', COUNT(*) FROM FAULT_HISTORY
UNION ALL
SELECT 'MAINTENANCE_REPORTS', COUNT(*) FROM MAINTENANCE_REPORTS;

-- 6) Create analytical views

-- Pump health summary view
CREATE OR REPLACE VIEW PUMP_HEALTH_SUMMARY AS
SELECT 
  a.PUMP_ID,
  a.MODEL,
  a.SERVICE_AGE_DAYS,
  a.WARRANTY_EXPIRY_DATE,
  DATEDIFF('day', CURRENT_DATE(), a.WARRANTY_EXPIRY_DATE) AS WARRANTY_DAYS_REMAINING,
  COUNT(DISTINCT i.INCIDENT_ID) AS TOTAL_INCIDENTS,
  COUNT(DISTINCT fh.FAULT_HISTORY_ID) AS TOTAL_FAULTS,
  MAX(i.DATE) AS LAST_INCIDENT_DATE,
  MAX(fh.FAULT_DATE) AS LAST_FAULT_DATE,
  AVG(t.PUMP_VIBRATION_RMS) AS AVG_VIBRATION,
  AVG(t.FLOW_RATE_LPS) AS AVG_FLOW_RATE,
  AVG(t.PIPE_PRESSURE_PSI) AS AVG_PRESSURE,
  AVG(t.CHLORINE_LEVEL_PPM) AS AVG_CHLORINE
FROM ASSET_MASTER a
LEFT JOIN INCIDENT_LOG i ON a.PUMP_ID = i.PUMP_ID
LEFT JOIN FAULT_HISTORY fh ON a.PUMP_ID = fh.PUMP_ID
LEFT JOIN PUMP_TELEMETRY t ON a.PUMP_ID = t.PUMP_ID
GROUP BY a.PUMP_ID, a.MODEL, a.SERVICE_AGE_DAYS, a.WARRANTY_EXPIRY_DATE;

-- Recent telemetry view (last 24 hours equivalent)
CREATE OR REPLACE VIEW RECENT_TELEMETRY AS
SELECT 
  t.*,
  a.MODEL,
  a.SERVICE_AGE_DAYS
FROM PUMP_TELEMETRY t
JOIN ASSET_MASTER a ON t.PUMP_ID = a.PUMP_ID
WHERE t.TIMESTAMP >= (SELECT MAX(TIMESTAMP) - INTERVAL '1 day' FROM PUMP_TELEMETRY);

-- High risk pumps view
CREATE OR REPLACE VIEW HIGH_RISK_PUMPS AS
SELECT 
  phs.*,
  CASE 
    WHEN phs.AVG_VIBRATION > 5.0 THEN 'CRITICAL_VIBRATION'
    WHEN phs.AVG_FLOW_RATE < 40.0 THEN 'LOW_FLOW'
    WHEN phs.SERVICE_AGE_DAYS > 1400 THEN 'HIGH_SERVICE_AGE'
    WHEN phs.TOTAL_INCIDENTS >= 3 THEN 'REPEAT_FAILURES'
    ELSE 'ELEVATED_RISK'
  END AS RISK_FACTOR
FROM PUMP_HEALTH_SUMMARY phs
WHERE phs.AVG_VIBRATION > 4.0 
   OR phs.AVG_FLOW_RATE < 42.0
   OR phs.SERVICE_AGE_DAYS > 1200
   OR phs.TOTAL_INCIDENTS >= 2;

-- 7) Semantic View for structured NL queries (relationships, facts, dimensions, metrics)
-- Requires accounts with SEMANTIC VIEW support

CREATE OR REPLACE SEMANTIC VIEW PREDICTIVE_MAINT_SEMANTIC_VIEW
  TABLES (
    PUMPS AS ASSET_MASTER PRIMARY KEY (PUMP_ID) WITH SYNONYMS=('pumps','assets','equipment') COMMENT='Pump asset master data with location and warranty info',
    TELEMETRY AS PUMP_TELEMETRY PRIMARY KEY (PUMP_ID, TIMESTAMP) WITH SYNONYMS=('sensors','readings','measurements') COMMENT='Real-time pump telemetry and sensor data',
    INCIDENTS AS INCIDENT_LOG PRIMARY KEY (INCIDENT_ID) WITH SYNONYMS=('failures','events','problems') COMMENT='Maintenance incidents and patient impact',
    FAULTS AS FAULT_HISTORY PRIMARY KEY (FAULT_HISTORY_ID) WITH SYNONYMS=('faults','errors','alarms') COMMENT='Historical fault occurrences',
    FAULT_REFS AS FAULT_CODES PRIMARY KEY (FAULT_CODE) WITH SYNONYMS=('fault codes','error codes') COMMENT='Fault code reference data'
  )
  RELATIONSHIPS (
    TELEMETRY_TO_PUMP AS TELEMETRY(PUMP_ID) REFERENCES PUMPS(PUMP_ID),
    INCIDENT_TO_PUMP AS INCIDENTS(PUMP_ID) REFERENCES PUMPS(PUMP_ID),
    FAULT_TO_PUMP AS FAULTS(PUMP_ID) REFERENCES PUMPS(PUMP_ID),
    FAULT_TO_CODE AS FAULTS(FAULT_CODE) REFERENCES FAULT_REFS(FAULT_CODE)
  )
  FACTS (
    TELEMETRY.PUMP_VIBRATION_RMS AS vibration COMMENT='Pump vibration RMS in mm/s',
    TELEMETRY.FLOW_RATE_LPS AS flow_rate COMMENT='Flow rate in liters per second',
    TELEMETRY.PIPE_PRESSURE_PSI AS pressure COMMENT='Pipe pressure in PSI',
    TELEMETRY.CHLORINE_LEVEL_PPM AS chlorine COMMENT='Chlorine level in PPM',
    PUMPS.SERVICE_AGE_DAYS AS service_age COMMENT='Days in service',
    INCIDENTS.INCIDENT_COUNT AS 1 COMMENT='Incident count',
    FAULTS.FAULT_COUNT AS 1 COMMENT='Fault count'
  )
  DIMENSIONS (
    PUMPS.PUMP_ID AS pump_id WITH SYNONYMS=('pump','pump number','asset id'),
    PUMPS.MODEL AS model WITH SYNONYMS=('pump model','equipment type'),
    PUMPS.LATITUDE AS latitude,
    PUMPS.LONGITUDE AS longitude,
    PUMPS.WARRANTY_EXPIRY_DATE AS warranty_expiry WITH SYNONYMS=('warranty date','warranty expires'),
    TELEMETRY.TIMESTAMP AS timestamp WITH SYNONYMS=('time','date','when'),
    INCIDENTS.DATE AS incident_date WITH SYNONYMS=('incident date','failure date'),
    INCIDENTS.INCIDENT_TYPE AS incident_type WITH SYNONYMS=('failure type','problem type'),
    INCIDENTS.PATIENT_IMPACT AS patient_impact WITH SYNONYMS=('impact','severity','criticality'),
    FAULTS.FAULT_DATE AS fault_date,
    FAULTS.RESET_METHOD AS reset_method WITH SYNONYMS=('repair method','fix'),
    FAULT_REFS.DESCRIPTION AS fault_description,
    FAULT_REFS.COMPONENT_IMPACT AS component WITH SYNONYMS=('component','part','affected component')
  )
  METRICS (
    TELEMETRY.AVG_VIBRATION AS AVG(vibration) COMMENT='Average vibration level',
    TELEMETRY.MAX_VIBRATION AS MAX(vibration) COMMENT='Maximum vibration level',
    TELEMETRY.AVG_FLOW_RATE AS AVG(flow_rate) COMMENT='Average flow rate',
    TELEMETRY.MIN_FLOW_RATE AS MIN(flow_rate) COMMENT='Minimum flow rate',
    TELEMETRY.AVG_PRESSURE AS AVG(pressure) COMMENT='Average pressure',
    TELEMETRY.AVG_CHLORINE AS AVG(chlorine) COMMENT='Average chlorine level',
    INCIDENTS.TOTAL_INCIDENTS AS COUNT(incident_count) COMMENT='Total number of incidents',
    FAULTS.TOTAL_FAULTS AS COUNT(fault_count) COMMENT='Total number of faults',
    PUMPS.AVG_SERVICE_AGE AS AVG(service_age) COMMENT='Average service age in days'
  )
  COMMENT='Semantic model for predictive maintenance analytics across pumps, telemetry, incidents and faults';

-- 8) Cortex Search over maintenance reports
-- Creates a semantic search index over maintenance report documents

CREATE OR REPLACE CORTEX SEARCH SERVICE MAINTENANCE_REPORT_SEARCH
  ON CONTENT
  ATTRIBUTES PUMP_ID, INCIDENT_ID
  WAREHOUSE = PREDICTIVE_MAINT_WH
  TARGET_LAG = "7 day"
  AS SELECT CONTENT, PUMP_ID, INCIDENT_ID FROM MAINTENANCE_REPORTS;

-- 9) Snowflake Intelligence Agent orchestrating semantic SQL and search
-- Ensure the Snowflake Intelligence config database exists

CREATE DATABASE IF NOT EXISTS snowflake_intelligence;
CREATE SCHEMA IF NOT EXISTS snowflake_intelligence.agents;
GRANT USAGE ON DATABASE snowflake_intelligence TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA snowflake_intelligence.agents TO ROLE PUBLIC;

CREATE OR REPLACE AGENT snowflake_intelligence.agents.PREDICTIVE_MAINT_AGENT
WITH PROFILE='{ "display_name": "Predictive Maintenance Intelligence Agent" }'
COMMENT='Primary interface for unified predictive maintenance intelligence across structured telemetry and unstructured maintenance reports.'
FROM SPECIFICATION $$
{
  "instructions": {
    "response": "You assist maintenance engineers and facility managers with predictive maintenance insights. Use semantic SQL for structured questions about pump telemetry, incidents, and faults. Use search for maintenance report questions. Provide actionable recommendations and identify high-risk equipment.",
    "sample_questions": [
      { "question": "Which pumps have the highest vibration levels and what is their service age?" },
      { "question": "Show me all incidents for PUMP_003 and summarize the maintenance history." },
      { "question": "Find maintenance reports mentioning bearing failures or seal leaks." },
      { "question": "What pumps are at high risk of failure based on recent telemetry trends?" },
      { "question": "Show monthly incident trends by pump model in a chart." },
      { "question": "Which pumps have critical patient impact incidents and are out of warranty?" },
      { "question": "Search for reports discussing predictive maintenance successes." }
    ]
  },
  "tools": [
    { "tool_spec": { "type": "cortex_analyst_text_to_sql", "name": "Query Pump Data", "description": "Natural language to SQL over the predictive maintenance semantic model for telemetry, incidents, and faults." } },
    { "tool_spec": { "type": "cortex_search", "name": "Search Maintenance Reports", "description": "Semantic search over maintenance service reports and technician notes." } }
  ],
  "tool_resources": {
    "Query Pump Data": { "semantic_view": "PREDICTIVE_MAINT_DB.DEMO.PREDICTIVE_MAINT_SEMANTIC_VIEW" },
    "Search Maintenance Reports": { "name": "PREDICTIVE_MAINT_DB.DEMO.MAINTENANCE_REPORT_SEARCH", "max_results": 10 }
  }
}
$$;

-- 10) Optional: Create a simple ML prediction view using Snowflake ML functions
-- This is a placeholder - actual ML model would be trained on historical data

CREATE OR REPLACE VIEW FAILURE_RISK_PREDICTION AS
SELECT 
  phs.PUMP_ID,
  phs.MODEL,
  phs.SERVICE_AGE_DAYS,
  phs.AVG_VIBRATION,
  phs.AVG_FLOW_RATE,
  phs.TOTAL_INCIDENTS,
  -- Simple risk scoring algorithm (replace with actual ML model)
  CASE 
    WHEN phs.AVG_VIBRATION > 5.5 AND phs.SERVICE_AGE_DAYS > 1400 THEN 95
    WHEN phs.AVG_VIBRATION > 5.0 AND phs.SERVICE_AGE_DAYS > 1200 THEN 85
    WHEN phs.AVG_VIBRATION > 4.5 OR phs.SERVICE_AGE_DAYS > 1300 THEN 70
    WHEN phs.AVG_VIBRATION > 4.0 OR phs.SERVICE_AGE_DAYS > 1100 THEN 55
    WHEN phs.AVG_VIBRATION > 3.5 OR phs.SERVICE_AGE_DAYS > 900 THEN 40
    WHEN phs.TOTAL_INCIDENTS >= 3 THEN 75
    WHEN phs.TOTAL_INCIDENTS >= 2 THEN 60
    ELSE 25
  END AS FAILURE_RISK_SCORE,
  CASE 
    WHEN phs.AVG_VIBRATION > 5.0 OR phs.SERVICE_AGE_DAYS > 1400 OR phs.TOTAL_INCIDENTS >= 3 THEN 'HIGH'
    WHEN phs.AVG_VIBRATION > 4.0 OR phs.SERVICE_AGE_DAYS > 1100 OR phs.TOTAL_INCIDENTS >= 2 THEN 'MEDIUM'
    ELSE 'LOW'
  END AS RISK_CATEGORY,
  CASE 
    WHEN phs.AVG_VIBRATION > 5.5 THEN 'Schedule immediate bearing inspection'
    WHEN phs.AVG_VIBRATION > 5.0 THEN 'Plan bearing replacement within 30 days'
    WHEN phs.SERVICE_AGE_DAYS > 1400 THEN 'Consider unit replacement or major overhaul'
    WHEN phs.TOTAL_INCIDENTS >= 3 THEN 'Evaluate for retirement - high failure rate'
    WHEN phs.AVG_FLOW_RATE < 40.0 THEN 'Inspect impeller and seals'
    ELSE 'Continue normal monitoring'
  END AS RECOMMENDED_ACTION
FROM PUMP_HEALTH_SUMMARY phs;

-- 11) Create sample queries view for easy testing

CREATE OR REPLACE VIEW SAMPLE_QUERIES AS
SELECT * FROM (
  VALUES
    ('High Risk Pumps', 'SELECT * FROM HIGH_RISK_PUMPS ORDER BY AVG_VIBRATION DESC'),
    ('Failure Risk Predictions', 'SELECT * FROM FAILURE_RISK_PREDICTION WHERE RISK_CATEGORY IN (''HIGH'', ''MEDIUM'') ORDER BY FAILURE_RISK_SCORE DESC'),
    ('Recent Critical Incidents', 'SELECT i.*, a.MODEL, a.SERVICE_AGE_DAYS FROM INCIDENT_LOG i JOIN ASSET_MASTER a ON i.PUMP_ID = a.PUMP_ID WHERE i.PATIENT_IMPACT IN (''HIGH'', ''CRITICAL'') ORDER BY i.DATE DESC'),
    ('Pumps Needing Attention', 'SELECT PUMP_ID, MODEL, SERVICE_AGE_DAYS, WARRANTY_DAYS_REMAINING, TOTAL_INCIDENTS FROM PUMP_HEALTH_SUMMARY WHERE SERVICE_AGE_DAYS > 1200 OR TOTAL_INCIDENTS >= 2 OR WARRANTY_DAYS_REMAINING < 0'),
    ('Vibration Trends', 'SELECT PUMP_ID, DATE_TRUNC(''hour'', TIMESTAMP) AS HOUR, AVG(PUMP_VIBRATION_RMS) AS AVG_VIBRATION FROM PUMP_TELEMETRY GROUP BY PUMP_ID, HOUR ORDER BY PUMP_ID, HOUR'),
    ('Fault Analysis by Component', 'SELECT fc.COMPONENT_IMPACT, COUNT(*) AS FAULT_COUNT FROM FAULT_HISTORY fh JOIN FAULT_CODES fc ON fh.FAULT_CODE = fc.FAULT_CODE GROUP BY fc.COMPONENT_IMPACT ORDER BY FAULT_COUNT DESC')
) AS t(QUERY_NAME, QUERY_SQL);

-- Display sample queries
SELECT * FROM SAMPLE_QUERIES;

-- 12) Grant permissions (adjust as needed for your organization)

GRANT USAGE ON DATABASE PREDICTIVE_MAINT_DB TO ROLE PUBLIC;
GRANT USAGE ON SCHEMA PREDICTIVE_MAINT_DB.DEMO TO ROLE PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA PREDICTIVE_MAINT_DB.DEMO TO ROLE PUBLIC;
GRANT SELECT ON ALL VIEWS IN SCHEMA PREDICTIVE_MAINT_DB.DEMO TO ROLE PUBLIC;

-- Final verification
SELECT 'Setup Complete!' AS STATUS,
       'Database: PREDICTIVE_MAINT_DB' AS DATABASE_INFO,
       'Agent: snowflake_intelligence.agents.PREDICTIVE_MAINT_AGENT' AS AGENT_INFO,
       'Try asking: "Which pumps are at highest risk of failure?"' AS SAMPLE_QUESTION;

-- Notes:
-- - The exact DDL for Cortex objects may differ based on Snowflake release. If CREATE ... statements fail, consult Snowflake docs for your account's current syntax and adjust.
-- - The ML prediction view uses a simple rule-based scoring system. For production, replace with actual ML models trained on historical failure data.
-- - Adjust the Git repository ORIGIN URL to point to your actual GitHub repository.
-- - The maintenance reports are loaded with metadata extraction to enable filtered search by pump_id and incident_id.
-- - Consider adding time-series forecasting models for predictive maintenance using Snowflake ML functions.

