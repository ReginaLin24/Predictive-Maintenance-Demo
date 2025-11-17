# Predictive Maintenance Demo

This demo showcases Snowflake's Intelligence Agent capabilities for predictive maintenance in a healthcare water pump monitoring scenario.

## Demo Structure

### 📊 Demo Data (`demo_data/`)

**Structured CSV Files:**
- `pump_telemetry.csv` - Time-series sensor data (vibration, flow rate, pressure, chlorine levels)
- `asset_master.csv` - Pump metadata (model, location, warranty, service age)
- `incident_log.csv` - Maintenance incidents with patient impact classification
- `fault_codes.csv` - Reference data for fault code descriptions
- `fault_history.csv` - Historical fault occurrences and reset methods

### 📝 Unstructured Documents (`unstructured_docs/maintenance_reports/`)

**12 Maintenance Service Reports** covering various scenarios:
- **MSR_2024_001** - PUMP_003 bearing failure (critical)
- **MSR_2024_002** - PUMP_009 seal leak
- **MSR_2024_003** - PUMP_001 vibration alarm
- **MSR_2024_004** - PUMP_005 motor overheat
- **MSR_2024_005** - PUMP_007 flow degradation
- **MSR_2024_006** - PUMP_003 pressure drop
- **MSR_2024_007** - PUMP_009 catastrophic bearing failure (critical)
- **MSR_2024_008** - PUMP_001 chlorine sensor malfunction
- **MSR_2024_009** - PUMP_007 motor replacement (emergency)
- **MSR_2024_010** - PUMP_003 critical seal failure (retirement recommended)
- **MSR_2024_011** - PUMP_005 preventive bearing replacement (predictive success)
- **MSR_2024_012** - PUMP_004 motor overheat (preventive intervention)

Each report includes:
- Diagnostic findings and root cause analysis
- Corrective actions and parts replaced
- Post-service verification
- Recommendations and compliance notes
- Embedded `pump_id` and `incident_id` metadata for RAG grounding

### 🗄️ SQL Setup Script (`sql_scripts/setup.sql`)

**Single comprehensive setup script that:**

1. **Infrastructure Setup**
   - Creates warehouse, database, and schema
   - Configures Git integration for your repository
   - Sets up file formats and internal staging

2. **Data Loading**
   - Loads all CSV files into structured tables
   - Loads maintenance reports with metadata extraction
   - Verifies data integrity

3. **Analytical Views**
   - `PUMP_HEALTH_SUMMARY` - Aggregated pump health metrics
   - `RECENT_TELEMETRY` - Latest sensor readings
   - `HIGH_RISK_PUMPS` - Pumps requiring attention
   - `FAILURE_RISK_PREDICTION` - ML-based risk scoring

4. **Semantic View**
   - `PREDICTIVE_MAINT_SEMANTIC_VIEW` - Enables natural language SQL queries
   - Defines relationships between pumps, telemetry, incidents, and faults
   - Includes metrics for vibration, flow rate, pressure, and incident counts

5. **Cortex Search Service**
   - `MAINTENANCE_REPORT_SEARCH` - Semantic search over maintenance reports
   - Supports filtering by pump_id and incident_id

6. **Intelligence Agent**
   - `PREDICTIVE_MAINT_AGENT` - Unified interface combining:
     - Semantic SQL for structured data queries
     - Cortex Search for unstructured maintenance reports
     - Actionable recommendations and risk identification

## Sample Questions for the Agent

**Structured Data Queries:**
- "Which pumps have the highest vibration levels and what is their service age?"
- "Show me all incidents for PUMP_003 and summarize the maintenance history."
- "What pumps are at high risk of failure based on recent telemetry trends?"
- "Which pumps have critical patient impact incidents and are out of warranty?"
- "Show monthly incident trends by pump model in a chart."

**Unstructured Data Search:**
- "Find maintenance reports mentioning bearing failures or seal leaks."
- "Search for reports discussing predictive maintenance successes."
- "What do technicians say about PUMP_003 reliability issues?"
- "Find reports with recommendations for unit retirement."

**Combined Queries:**
- "Show me PUMP_009's telemetry data and search for related maintenance reports."
- "Which high-vibration pumps have recent maintenance reports about bearing issues?"

## Key Demo Features

### 🎯 Predictive Maintenance Scenarios
- **Catastrophic Failures** - PUMP_003 and PUMP_009 with multiple critical incidents
- **Preventive Success** - PUMP_005 predictive intervention preventing failure
- **Component-Specific Issues** - Bearings, seals, motors, sensors
- **Warranty Considerations** - Mix of in-warranty and out-of-warranty equipment
- **Patient Impact** - Healthcare context with criticality classifications

### 📈 Analytics Capabilities
- Time-series telemetry analysis
- Failure risk prediction
- Component failure patterns
- Service age correlation
- Cost-benefit analysis for preventive maintenance

### 🔍 RAG (Retrieval Augmented Generation)
- Maintenance reports grounded with pump_id and incident_id
- Semantic search enables finding relevant historical context
- Combines structured metrics with unstructured technician insights

## Setup Instructions

1. **Update the Git Repository URL** in `setup.sql`:
   ```sql
   ORIGIN = 'https://github.com/YOUR_USERNAME/predictive_maintenance_demo.git';
   ```

2. **Execute the setup script** in Snowflake:
   ```sql
   -- Run as ACCOUNTADMIN
   !source sql_scripts/setup.sql
   ```

3. **Test the Agent**:
   ```sql
   -- Query the agent
   SELECT snowflake_intelligence.agents.PREDICTIVE_MAINT_AGENT(
     'Which pumps are at highest risk of failure?'
   );
   ```

## Demo Narrative

This demo tells the story of a healthcare facility managing critical water pumps:

1. **Monitoring** - Real-time telemetry tracks pump health
2. **Early Warning** - Predictive algorithms identify at-risk equipment
3. **Preventive Action** - PUMP_005 success story shows cost avoidance
4. **Failure Analysis** - PUMP_003 and PUMP_009 show consequences of delayed maintenance
5. **Decision Support** - Agent provides actionable recommendations for maintenance planning

## Technical Notes

- **Database**: `PREDICTIVE_MAINT_DB`
- **Schema**: `DEMO`
- **Warehouse**: `PREDICTIVE_MAINT_WH` (XSMALL, auto-suspend)
- **Agent**: `snowflake_intelligence.agents.PREDICTIVE_MAINT_AGENT`
- **Data Volume**: 50+ telemetry records, 10 pumps, 20 incidents, 12 detailed reports

## Requirements

- Snowflake account with:
  - Cortex Search enabled
  - Snowflake Intelligence Agent enabled
  - Git integration support
  - ACCOUNTADMIN privileges for setup

---

**Demo Owner**: Regina Lin  
**Last Updated**: November 2024  
**Version**: 1.0

