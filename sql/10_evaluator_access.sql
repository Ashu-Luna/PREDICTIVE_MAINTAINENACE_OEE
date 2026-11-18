-- ============================================================
-- 10_evaluator_access.sql — Grant Hackathon Evaluator Access
-- ============================================================
-- Shares the OEE Command Center (Streamlit app, data, ML, semantic
-- view) with the Hack2skill evaluation team.
--
-- Snowflake does NOT support sharing an object directly to an email
-- address the way Google Docs does. There are two supported paths:
--
--   PATH A (THIS SCRIPT): Create login users inside YOUR account for
--     the evaluators so they can open the Streamlit app and run queries.
--     This is the right choice when the deliverable is the running app.
--
--   PATH B: Secure Data Sharing / Private Listing — only works when the
--     evaluators have their OWN Snowflake account to share INTO, and it
--     shares data only (NOT the Streamlit app). See notes at the bottom.
--
-- Run this with a role that can create users and roles (ACCOUNTADMIN
-- or a role with CREATE USER / CREATE ROLE privileges).
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ------------------------------------------------------------
-- 1. Dedicated read-only role for evaluators
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS EVALUATOR_ROLE
    COMMENT = 'Read-only access for Hack2skill hackathon evaluators';

-- ------------------------------------------------------------
-- 2. Warehouse usage (so they can run queries + the app)
-- ------------------------------------------------------------
GRANT USAGE ON WAREHOUSE OEE_WH TO ROLE EVALUATOR_ROLE;

-- ------------------------------------------------------------
-- 3. Database + schema visibility
-- ------------------------------------------------------------
GRANT USAGE ON DATABASE OEE_CC TO ROLE EVALUATOR_ROLE;
GRANT USAGE ON ALL SCHEMAS IN DATABASE OEE_CC TO ROLE EVALUATOR_ROLE;
GRANT USAGE ON FUTURE SCHEMAS IN DATABASE OEE_CC TO ROLE EVALUATOR_ROLE;

-- ------------------------------------------------------------
-- 4. Read access to all data objects (tables, views, dynamic tables)
-- ------------------------------------------------------------
GRANT SELECT ON ALL TABLES IN DATABASE OEE_CC TO ROLE EVALUATOR_ROLE;
GRANT SELECT ON FUTURE TABLES IN DATABASE OEE_CC TO ROLE EVALUATOR_ROLE;

GRANT SELECT ON ALL VIEWS IN DATABASE OEE_CC TO ROLE EVALUATOR_ROLE;
GRANT SELECT ON FUTURE VIEWS IN DATABASE OEE_CC TO ROLE EVALUATOR_ROLE;

GRANT SELECT ON ALL DYNAMIC TABLES IN DATABASE OEE_CC TO ROLE EVALUATOR_ROLE;
GRANT SELECT ON FUTURE DYNAMIC TABLES IN DATABASE OEE_CC TO ROLE EVALUATOR_ROLE;

-- Semantic view (Cortex Analyst) + any future semantic views
GRANT SELECT ON ALL SEMANTIC VIEWS IN SCHEMA OEE_CC.APP TO ROLE EVALUATOR_ROLE;
GRANT SELECT ON FUTURE SEMANTIC VIEWS IN SCHEMA OEE_CC.APP TO ROLE EVALUATOR_ROLE;

-- ------------------------------------------------------------
-- 5. Streamlit app access (the OEE Command Center)
-- ------------------------------------------------------------
GRANT USAGE ON SCHEMA OEE_CC.APP TO ROLE EVALUATOR_ROLE;
GRANT USAGE ON STREAMLIT OEE_CC.APP.OEE_COMMAND_CENTER TO ROLE EVALUATOR_ROLE;

-- ------------------------------------------------------------
-- 6. Create the evaluator users
--    MUST_CHANGE_PASSWORD = TRUE forces a reset on first login.
--    Replace the placeholder passwords before running.
-- ------------------------------------------------------------
CREATE USER IF NOT EXISTS EVALUATOR_HACK2SKILL
    LOGIN_NAME   = 'evaluator@hack2skill.com'
    EMAIL        = 'evaluator@hack2skill.com'
    DISPLAY_NAME = 'Hack2skill Evaluator'
    PASSWORD     = 'ChangeMe_Eval_2026!'   -- <-- change this
    MUST_CHANGE_PASSWORD = TRUE
    DEFAULT_ROLE      = EVALUATOR_ROLE
    DEFAULT_WAREHOUSE = OEE_WH
    DEFAULT_NAMESPACE = OEE_CC.APP
    COMMENT = 'Hack2skill hackathon evaluator';

CREATE USER IF NOT EXISTS EVALUATOR_HACK2SKILL_GMAIL
    LOGIN_NAME   = 'hack2skillevaluator@gmail.com'
    EMAIL        = 'hack2skillevaluator@gmail.com'
    DISPLAY_NAME = 'Hack2skill Evaluator (Gmail)'
    PASSWORD     = 'ChangeMe_Eval_2026!'   -- <-- change this
    MUST_CHANGE_PASSWORD = TRUE
    DEFAULT_ROLE      = EVALUATOR_ROLE
    DEFAULT_WAREHOUSE = OEE_WH
    DEFAULT_NAMESPACE = OEE_CC.APP
    COMMENT = 'Hack2skill hackathon evaluator (gmail)';

-- ------------------------------------------------------------
-- 7. Assign the role to both users
-- ------------------------------------------------------------
GRANT ROLE EVALUATOR_ROLE TO USER EVALUATOR_HACK2SKILL;
GRANT ROLE EVALUATOR_ROLE TO USER EVALUATOR_HACK2SKILL_GMAIL;

-- ------------------------------------------------------------
-- 8. Verify
-- ------------------------------------------------------------
SHOW GRANTS TO ROLE EVALUATOR_ROLE;
SHOW GRANTS TO USER EVALUATOR_HACK2SKILL;
SHOW GRANTS TO USER EVALUATOR_HACK2SKILL_GMAIL;

-- ============================================================
-- WHAT TO SEND THE EVALUATORS
-- ============================================================
-- They need THREE things to log in:
--   1. Account URL / locator:  https://<your_org>-<your_account>.snowflakecomputing.com
--      Find it with:  SELECT CURRENT_ORGANIZATION_NAME(), CURRENT_ACCOUNT_NAME();
--   2. Login name:  evaluator@hack2skill.com  (and the gmail one)
--   3. The temporary password you set above.
-- Then: Snowsight > Projects > Streamlit > OEE_COMMAND_CENTER
--
-- ============================================================
-- PATH B — Secure Data Sharing (ONLY if evaluators have a Snowflake acct)
-- ============================================================
-- This shares DATA ONLY (tables/views), not the Streamlit app, and the
-- consumer must give you their Snowflake ACCOUNT identifier (not an email).
--
--   CREATE SHARE IF NOT EXISTS OEE_EVAL_SHARE;
--   GRANT USAGE ON DATABASE OEE_CC TO SHARE OEE_EVAL_SHARE;
--   GRANT USAGE ON SCHEMA OEE_CC.CONVERGED TO SHARE OEE_EVAL_SHARE;
--   GRANT SELECT ON ALL DYNAMIC TABLES IN SCHEMA OEE_CC.CONVERGED TO SHARE OEE_EVAL_SHARE;
--   -- repeat GRANTs for OPS / RAW / APP as needed, then:
--   ALTER SHARE OEE_EVAL_SHARE ADD ACCOUNTS = (<EVALUATOR_ACCOUNT_LOCATOR>);
--
-- A Marketplace Private Listing CAN be targeted by email, but it also
-- shares data only (not the app) and requires the Provider Studio UI.
-- ============================================================
