# Quick Start Guide - Predictive Maintenance Demo

## Prerequisites
- Snowflake account with Cortex Search and Intelligence Agent enabled
- ACCOUNTADMIN role access
- Git repository created and pushed to GitHub

## Step 1: Push to GitHub

```bash
cd /Users/reginalin/predictive_maintenance_demo
git init
git add .
git commit -m "Initial commit - Predictive Maintenance Demo"
git remote add origin https://github.com/ReginaLin24/predictive_maintenance_demo.git
git push -u origin main
```

## Step 2: Update SQL Script

Edit `sql_scripts/setup.sql` and verify the Git repository URL (line 32):

```sql
ORIGIN = 'https://github.com/ReginaLin24/predictive_maintenance_demo.git';
```

## Step 3: Run Setup in Snowflake

1. Open Snowflake Worksheets
2. Copy and paste the entire contents of `sql_scripts/setup.sql`
3. Execute the script (this will take 2-3 minutes)

The script will:
- ✅ Create warehouse `PREDICTIVE_MAINT_WH`
- ✅ Create database `PREDICTIVE_MAINT_DB` and schema `DEMO`
- ✅ Set up Git integration
- ✅ Load all CSV data (5 tables)
- ✅ Load maintenance reports (12 documents)
- ✅ Create analytical views
- ✅ Create semantic view
- ✅ Create Cortex Search service
- ✅ Create Intelligence Agent

## Step 4: Verify Setup

Run these verification queries:

```sql
-- Check data loaded
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

-- Expected results:
-- PUMP_TELEMETRY: 50 rows
-- ASSET_MASTER: 10 rows
-- INCIDENT_LOG: 20 rows
-- FAULT_CODES: 15 rows
-- FAULT_HISTORY: 25 rows
-- MAINTENANCE_REPORTS: 12 rows

-- Check views
SELECT * FROM HIGH_RISK_PUMPS;
SELECT * FROM FAILURE_RISK_PREDICTION ORDER BY FAILURE_RISK_SCORE DESC;
```

## Step 5: Test the Intelligence Agent

### Option A: Using Snowflake UI (Recommended)

1. Navigate to **AI & ML** → **Agents** in Snowflake UI
2. Find `PREDICTIVE_MAINT_AGENT`
3. Click to open the chat interface
4. Try sample questions (see below)

### Option B: Using SQL

```sql
-- Query the agent directly
SELECT snowflake_intelligence.agents.PREDICTIVE_MAINT_AGENT(
  'Which pumps are at highest risk of failure?'
) AS agent_response;
```

## Sample Questions to Try

### 🔍 Structured Data Queries

**Risk Assessment:**
```
Which pumps have the highest vibration levels and what is their service age?
```

**Incident Analysis:**
```
Show me all incidents for PUMP_003 and summarize the maintenance history.
```

**Warranty Status:**
```
Which pumps have critical patient impact incidents and are out of warranty?
```

**Trend Analysis:**
```
Show monthly incident trends by pump model in a chart.
```

**Performance Metrics:**
```
What is the average flow rate and vibration for each pump model?
```

### 📄 Unstructured Data Search

**Component Failures:**
```
Find maintenance reports mentioning bearing failures or seal leaks.
```

**Success Stories:**
```
Search for reports discussing predictive maintenance successes.
```

**Specific Pump History:**
```
What do technicians say about PUMP_003 reliability issues?
```

**Recommendations:**
```
Find reports with recommendations for unit retirement.
```

### 🎯 Combined Queries

**Comprehensive Analysis:**
```
Show me PUMP_009's telemetry data and search for related maintenance reports.
```

**Pattern Recognition:**
```
Which high-vibration pumps have recent maintenance reports about bearing issues?
```

**Decision Support:**
```
What pumps should I prioritize for maintenance this month based on risk scores and technician reports?
```

## Key Demo Points to Highlight

### 1. **Predictive Maintenance Success** (PUMP_005)
- Report MSR_2024_011 shows proactive bearing replacement
- Prevented critical failure with 85% probability
- Cost avoidance: $11,800
- Demonstrates value of predictive analytics

### 2. **Failure Cascade** (PUMP_003)
- Three major incidents: INC_001, INC_006, INC_014
- Reports show progressive deterioration
- Retirement recommended
- Illustrates cost of reactive maintenance

### 3. **Critical Failure** (PUMP_009)
- Catastrophic bearing failure (INC_007)
- 1,567 service days - beyond recommended life
- Regulatory reporting required
- Shows importance of service age monitoring

### 4. **Preventive Intervention** (PUMP_004, PUMP_007)
- Early warning systems caught issues
- Motor overheating addressed before failure
- Medium impact vs. potential critical impact

## Troubleshooting

### Git Integration Issues
```sql
-- Check Git repository status
SHOW GIT REPOSITORIES;

-- Manually fetch if needed
ALTER GIT REPOSITORY PREDICTIVE_MAINT_REPO FETCH;
```

### Data Loading Issues
```sql
-- Check stage contents
LS @INTERNAL_DATA_STAGE;

-- Refresh stage
ALTER STAGE INTERNAL_DATA_STAGE REFRESH;

-- Re-copy files if needed
COPY FILES
INTO @INTERNAL_DATA_STAGE/demo_data/
FROM @PREDICTIVE_MAINT_REPO/branches/main/demo_data/;
```

### Agent Not Responding
```sql
-- Check agent status
SHOW AGENTS IN SCHEMA snowflake_intelligence.agents;

-- Verify Cortex Search service
SHOW CORTEX SEARCH SERVICES;
```

## Demo Flow Suggestion

1. **Introduction** (2 min)
   - Explain healthcare water pump monitoring scenario
   - Show data structure (CSV files + maintenance reports)

2. **Structured Data Analysis** (5 min)
   - Query high-risk pumps
   - Show failure risk predictions
   - Demonstrate semantic SQL with natural language

3. **Unstructured Data Search** (5 min)
   - Search maintenance reports for bearing failures
   - Show how metadata enables filtered search
   - Highlight technician insights

4. **Combined Intelligence** (5 min)
   - Ask complex questions combining both data types
   - Show PUMP_003 complete history (structured + reports)
   - Demonstrate decision support capabilities

5. **Business Value** (3 min)
   - PUMP_005 success story: $11,800 cost avoidance
   - PUMP_003 failure cascade: importance of early action
   - ROI of predictive maintenance

## Next Steps

- **Customize**: Modify data to match your industry/use case
- **Extend**: Add more maintenance reports or telemetry data
- **Enhance**: Integrate actual ML models for predictions
- **Deploy**: Connect to real-time data sources

## Support

For issues or questions:
- Check Snowflake documentation for Cortex Search and Intelligence Agents
- Review error messages in Snowflake Query History
- Verify all prerequisites are met

---

**Ready to Demo!** 🚀

Start with: *"Which pumps are at highest risk of failure?"*

