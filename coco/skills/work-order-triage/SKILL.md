---
name: work-order-triage
description: Rules for turning anomalies into work orders and Jira tickets in the Predictive Maintenance Command Center. Use when drafting work orders, setting severity, choosing parts, or creating tickets via the mfg-ticketing MCP tool.
---

# Work-Order Triage Rules

Apply these when converting detected anomalies into work orders and external tickets.

## Severity (from anomaly deviation)

Deviation = observed minus expected vibration in mm/s (vibration_deviation_mm_s).

- deviation > 2.5  -> HIGH
- deviation > 1.0  -> MEDIUM
- otherwise        -> LOW

HIGH-severity work orders should be ticketed first.

## Recommended part (from failure mode / machine history)

Map by the predicted failure mode AND machine type. Do not reuse a part from an earlier
failure of a different mode on the same machine (e.g. a SPINDLE failure after a BEARING repair
still needs the spindle cartridge, not another bearing).

| Failure mode | Machine type        | Part     | Part name                |
|--------------|---------------------|----------|--------------------------|
| OVERHEAT     | any                 | COOL-PLG | Coolant Pump Gasket      |
| BEARING      | HYDRAULIC_PRESS     | BRG-308  | 6308 Main Bearing        |
| BEARING      | CNC_LATHE, CNC_MILL, other | BRG-204 | 6204 Spindle Bearing |
| SPINDLE      | any                 | SPND-110 | Spindle Cartridge Assy   |

If the machine has a past UNPLANNED failure in OEE_CC.RAW.IT_MAINTENANCE_RECORD with the SAME
failure mode, prefer the part used then. Every recommended part must exist in
OEE_CC.RAW.IT_PARTS_INVENTORY; if not, fall back to the table above.

Confirm stock and location from OEE_CC.RAW.IT_PARTS_INVENTORY and include it in the ticket.

## Cost impact

Estimate est_cost_usd from the machine's recent DOWNTIME_COST_USD in
OEE_CC.CONVERGED.DT_OEE_DAILY. State it in dollars in the ticket so the business impact is clear.

## Loop status lifecycle (never skip states)

DRAFTED -> TICKETED -> ACKNOWLEDGED -> CLOSED

- DRAFTED: work order created in OEE_CC.OPS.WORK_ORDER from an anomaly.
- TICKETED: external Jira ticket created; store its key in WORK_ORDER.external_ticket.
- ACKNOWLEDGED: technician acknowledged (Jira transition applied).
- CLOSED: repair complete.

Keep the work order idempotent — never create a duplicate ticket for an anomaly that already
has an external_ticket.

## Jira ticket content (via mfg-ticketing-jira create_work_order)

Pass: machine_id, severity, root_cause, recommended_part, est_cost_usd.
The summary should read "[SEVERITY] Predicted failure on <machine_id>".
The description should include the root-cause narrative, recommended part + stock location,
and the estimated dollar cost impact — so a technician can act without opening any other tool.

## Good ticket example

Summary: "[HIGH] Predicted failure on CNC-01"
Body: "Spindle bearing degradation predicted ~40 min out. Vibration and temperature rose
together, matching prior BEARING failures. Replace BRG-204 (12 in stock, WH-EAST).
Estimated downtime cost if unaddressed: $1,240."
