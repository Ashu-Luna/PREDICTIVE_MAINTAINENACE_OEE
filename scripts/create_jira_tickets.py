"""Create Jira tickets in MFG for DRAFTED work orders (automation step 6).

Reads the Jira API token from %USERPROFILE%\\.secrets\\jira_mfg_token.txt (never from this repo),
creates one Task per DRAFTED work order without a ticket, sets the real assignee from the
technician's DIM_TECHNICIAN.jira_email, then marks the work order TICKETED with the issue key.
Safe to re-run: work orders that already have external_ticket are never ticketed again.
"""
import base64
import os
import sys

import requests
import snowflake.connector

JIRA_SITE = "https://ashajyothiakula81.atlassian.net"
JIRA_USER = "knskings05@gmail.com"
PROJECT = "MFG"
TOKEN_FILE = os.path.join(os.environ["USERPROFILE"], ".secrets", "jira_mfg_token.txt")
SF_CONNECTION = "tyxqtrs-zu58314"


def para(text, bold=False):
    node = {"type": "text", "text": text}
    if bold:
        node["marks"] = [{"type": "strong"}]
    return {"type": "paragraph", "content": [node]}


def main():
    with open(TOKEN_FILE, encoding="utf-8-sig") as f:
        token = f.read().strip()
    auth = base64.b64encode(f"{JIRA_USER}:{token}".encode()).decode()
    headers = {"Authorization": f"Basic {auth}", "Accept": "application/json", "Content-Type": "application/json"}

    conn = snowflake.connector.connect(connection_name=SF_CONNECTION, warehouse="OEE_WH")
    cur = conn.cursor(snowflake.connector.DictCursor)
    cur.execute("""
        SELECT w.work_order_id, w.machine_id, m.machine_name, w.severity, COALESCE(w.failure_mode, 'NONE') AS failure_mode,
               TO_CHAR(w.anomaly_ts, 'YYYY-MM-DD HH24:MI') AS anomaly_ts, w.recommended_part, w.part_name,
               w.part_warehouse_loc, w.part_qty_on_hand, w.est_cost_usd, w.root_cause,
               t.technician_id, t.technician_name, t.skill_level, t.specialization, t.shift_assignment,
               t.contact_number, t.jira_email
        FROM OEE_CC.OPS.WORK_ORDER w
        JOIN OEE_CC.RAW.DIM_MACHINE m ON m.machine_id = w.machine_id
        LEFT JOIN OEE_CC.RAW.DIM_TECHNICIAN t ON t.technician_id = w.assigned_technician_id
        WHERE w.loop_status = 'DRAFTED' AND w.external_ticket IS NULL
        ORDER BY CASE w.severity WHEN 'HIGH' THEN 1 WHEN 'MEDIUM' THEN 2 ELSE 3 END, w.anomaly_ts""")
    rows = cur.fetchall()
    print(f"DRAFTED work orders without a ticket: {len(rows)}")

    created, failed = 0, 0
    for r in rows:
        wo = r["WORK_ORDER_ID"]
        try:
            account_id = None
            if r["JIRA_EMAIL"]:
                users = requests.get(f"{JIRA_SITE}/rest/api/3/user/search", params={"query": r["JIRA_EMAIL"]},
                                     headers=headers, timeout=30).json()
                account_id = users[0]["accountId"] if users else None

            if r["RECOMMENDED_PART"]:
                part_line = f"Recommended part: {r['RECOMMENDED_PART']} ({r['PART_NAME']}) - {r['PART_QTY_ON_HAND']} in stock at {r['PART_WAREHOUSE_LOC']}."
            else:
                part_line = "Recommended part: None - no replacement required. Monitor only."
            if r["TECHNICIAN_ID"]:
                tech_line = (f"Assigned to: {r['TECHNICIAN_NAME']} ({r['TECHNICIAN_ID']}, {str(r['SKILL_LEVEL']).title()}, "
                             f"{r['SPECIALIZATION']}, {r['SHIFT_ASSIGNMENT']} shift) - contact {r['CONTACT_NUMBER']}")
            else:
                tech_line = "Assigned to: UNASSIGNED - no available technician matched the dispatch rules."

            fields = {
                "project": {"key": PROJECT},
                "issuetype": {"name": "Task"},
                "summary": f"[{r['SEVERITY']}] Predicted failure on {r['MACHINE_ID']}",
                "labels": ["predictive-maintenance", wo, r["MACHINE_ID"]] + ([r["FAILURE_MODE"]] if r["FAILURE_MODE"] != "NONE" else []),
                "description": {"type": "doc", "version": 1, "content": [
                    para(f"Work order: {wo} | Machine: {r['MACHINE_ID']} ({r['MACHINE_NAME']}) | Anomaly: {r['ANOMALY_TS']} | "
                         f"Severity: {r['SEVERITY']} | Failure mode: {r['FAILURE_MODE']}"),
                    para(f"Root cause: {r['ROOT_CAUSE'] or 'not available'}"),
                    para(part_line),
                    para(f"Estimated downtime cost if unaddressed: ${float(r['EST_COST_USD'] or 0):,.2f}."),
                    para(tech_line, bold=True),
                    para("Source: Snowflake OEE_CC.OPS.WORK_ORDER (auto-drafted by predictive-maintenance anomaly detection)."),
                ]},
            }
            if account_id:
                fields["assignee"] = {"accountId": account_id}

            resp = requests.post(f"{JIRA_SITE}/rest/api/3/issue", json={"fields": fields}, headers=headers, timeout=60)
            resp.raise_for_status()
            key = resp.json()["key"]

            conn.cursor().execute(
                "UPDATE OEE_CC.OPS.WORK_ORDER SET external_ticket = %s, loop_status = 'TICKETED', updated_at = CURRENT_TIMESTAMP() "
                "WHERE work_order_id = %s AND loop_status = 'DRAFTED' AND external_ticket IS NULL",
                (key, wo))
            created += 1
            print(f"{wo} -> {key} | assignee: {r['TECHNICIAN_NAME'] if account_id else 'none (description only)'}")
        except Exception as e:
            failed += 1
            print(f"{wo} FAILED: {e}")

    conn.close()
    print(f"Tickets created: {created}, failed: {failed}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
