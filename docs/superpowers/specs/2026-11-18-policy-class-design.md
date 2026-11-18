# Policy class on charge lines — design (short)

Date: 2026-11-18. Follows the charge-line relationships work (`2026-11-16-charge-line-relationships-design.md`).

## Intent

Census, CPV and CPE by product category must also split by the patient's insurance class (VIP, A, B, C), as on the
old server. The old server derived the class with:

```sql
coalesce(nullIf(IF(rp.POLICY_CODE!=0,'REF',''),''),
         nullIf(cm.CLASSIFICATION,''),
         nullIf(extract(upperUTF8(ifNull(mpc.DESCRIPTION,'')),'\\^\\s*(VIP|A|B|C)'),''),
         nullIf(extract(upperUTF8(ifNull(mpc.DESCRIPTION,'')),'(?:^|\\s)(VIP|A|B|C)(?:\\s|$)'),'')) AS CLASS_DESCRIPTION
```

`cm` is the old server's `default.patient_contract_mapping` (branch + contract number → class id, VIP/A/B/C;
168,295 rows), a hand mapping for old contracts whose class description carries no class.

## Decisions

- **Order (the user's choice, 2026-11-18): referral → description → mapping.** The class in Oasis wins; the mapping is
  a fallback only. This differs from the old server, which put the mapping before the description: on 2023+ charge
  rows where both give a class they disagree on 1.75M rows (10.8M agree), e.g. `GOSI^C` is C by description, B in the
  mapping. Reports will not match the old server on those rows.
- **Path:** `delivery_charge.contract_no` → `oasis.contracts.class_id` → `oasis.policy_classes.description`. The
  mapping has the same key (branch, contract number). The `^` in the first pattern is a literal caret
  (`NTW^C`, `NW2+^B`), kept as written.
- **Referral:** the line's policy is a referral in `int_policy_client` (`is_referral = 1`, the BI manager's rules) →
  `REF`.
- **No class** → `Not classified` (contracts without a class, `MOH`, `WAVE-1`, cash lines without a contract).
  Values: `REF`, `VIP`, `A`, `B`, `C`, `Not classified`. Repo labels, not title-cased.

## Approaches

1. **A text column `policy_class` on `fact_charge_line`** (chosen). Six values; costs a few MB in SSAS.
2. A small `dim_policy_class` (six rows) with a key on the fact: the same in a report, one more table and
   relationship for no gain.
3. A contract dimension (693K contracts: class, network, contract description): richer, but about 700K rows and a
   high-cardinality key on Charge Lines (the model is at 8.17 of 10 GB). Not needed for the ask.

The class cannot go on `dim_policy`: one policy has many classes.

## Build

- **Reference table** `default.map_contract_class` (BRANCH_ID UInt8, CONTRACT_NO Int64, CLASS_ID Int64,
  CLASSIFICATION LowCardinality(String)), from `static_mappings/contract_class_mapping.csv` exported read-only from
  the old server (DSN `chDWH`), loaded by `scripts/load_reference_data.py --only map_contract_class`. The user runs
  the load (a ClickHouse write). Staged by `stg_ref__contract_class`.
- **Oasis sources** `contracts` and `policy_classes`; staging `stg_oasis__contracts` (branch, contract_no, class_id)
  and `stg_oasis__policy_classes` (branch, class_id, description). `stg_oasis__charges` gains `contract_no`.
- **`int_contract_class`:** one row per branch + contract number with `policy_class` (description patterns, else
  the mapping, else null) and `class_source` (`Description` / `Mapping`).
- **`fact_charge_line.policy_class`:** `REF` if the line's policy is a referral, else the contract's class, else
  `Not classified`. accepted_values test on the six values.
- **SSAS:** Charge Lines gains a visible `Policy Class` column (contract `ssas_fact_charge_line`, generator,
  perspectives). No new measures: Census (Charged), CPV, CPE and Revenue slice by it.
- **Tests:** a unit test for `int_contract_class` (caret form, token form, mapping fallback, description beats
  mapping, nothing found); the `fact_charge_line` unit tests gain the column (referral, classed, not classified).

## Not in scope

Episodes, invoices, claims and order lines (not asked; each would need its own contract link). A UI for editing the
mapping: it is a frozen copy of the old table.

## Rollout

The user loads the reference table, copies the files and builds dbt; the test slot is deployed with a go-ahead.
Promote together with GATE G3 of the charge-line relationships work, so Charge Lines is fully reloaded once.
