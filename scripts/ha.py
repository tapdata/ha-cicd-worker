#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import itertools
import sys
from contextlib import contextmanager

import psycopg2
from psycopg2 import sql
from psycopg2.extras import execute_batch


CASE_SCHEMA = "hpi"
CASE_TABLE = "cpi_case"

PATIENT_SCHEMA = "hpi"
PATIENT_TABLE = "cpi_patient"

PHD_SCHEMA = "hpi"
PHD_TABLE = "cpi_patient_hospital_data"

DISCHARGE_SCHEMA = "cms"
DISCHARGE_TABLE = "discharge_information"

MAX_CASE_ROWS = 10000


def qident(*parts):
    return sql.SQL(".").join(sql.Identifier(p) for p in parts)


def get_columns(cur, schema, table):
    cur.execute(
        """
        SELECT column_name
        FROM information_schema.columns
        WHERE table_schema = %s
          AND table_name = %s
        ORDER BY ordinal_position
        """,
        (schema, table),
    )
    return [r[0] for r in cur.fetchall()]


def get_pk_columns(cur, schema, table):
    cur.execute(
        """
        SELECT a.attname
        FROM pg_index i
                 JOIN pg_class c ON c.oid = i.indrelid
                 JOIN pg_namespace n ON n.oid = c.relnamespace
                 JOIN pg_attribute a ON a.attrelid = c.oid AND a.attnum = ANY(i.indkey)
        WHERE i.indisprimary
          AND n.nspname = %s
          AND c.relname = %s
        ORDER BY array_position(i.indkey, a.attnum)
        """,
        (schema, table),
    )
    return [r[0] for r in cur.fetchall()]


def build_order_expr(cur, schema, table, alias=None):
    pk_cols = get_pk_columns(cur, schema, table)
    if pk_cols:
        if alias:
            return sql.SQL(", ").join(
                sql.SQL("{}.{}").format(sql.Identifier(alias), sql.Identifier(c))
                for c in pk_cols
            )
        return sql.SQL(", ").join(sql.Identifier(c) for c in pk_cols)

    if alias:
        return sql.SQL("{}.ctid").format(sql.Identifier(alias))
    return sql.SQL("ctid")


def create_temp_like(cur, temp_name, schema, table):
    cur.execute(
        sql.SQL(
            """
            DROP TABLE IF EXISTS {tmp};
            CREATE TEMP TABLE {tmp}
            (LIKE {src} INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING INDEXES)
            ON COMMIT DROP
            """
        ).format(
            tmp=sql.Identifier(temp_name),
            src=qident(schema, table),
        )
    )


def alter_discharge_information_columns(cur):
    print("开始调整 cms.discharge_information 字段长度...")
    cur.execute(
        """
        ALTER TABLE cms.discharge_information
        ALTER COLUMN hospital_code TYPE char(6)
        """
    )
    cur.execute(
        """
        ALTER TABLE cms.discharge_information
        ALTER COLUMN case_no TYPE char(24)
        """
    )
    cur.execute(
        """
        ALTER TABLE cms.discharge_information
        ALTER COLUMN specialty TYPE char(8)
        """
    )
    print("cms.discharge_information 字段长度调整完成")


def insert_selected_cases_by_hospital(cur, hospital_code_upper):
    create_temp_like(cur, "tmp_cpi_case", CASE_SCHEMA, CASE_TABLE)

    order_expr = build_order_expr(cur, CASE_SCHEMA, CASE_TABLE)

    cur.execute(
        """
        SELECT COUNT(*)
        FROM hpi.cpi_case
        WHERE upper(hospital_code) = %s
        """,
        (hospital_code_upper,),
    )
    total_matched = cur.fetchone()[0]
    print(f"主表匹配到 hospital_code={hospital_code_upper} 的 cpi_case: {total_matched} 条")

    cur.execute(
        sql.SQL(
            """
            INSERT INTO tmp_cpi_case
            SELECT *
            FROM {src}
            WHERE upper(hospital_code) = %s
            ORDER BY {order_expr}
                LIMIT %s
            """
        ).format(
            src=qident(CASE_SCHEMA, CASE_TABLE),
            order_expr=order_expr,
        ),
        (hospital_code_upper, MAX_CASE_ROWS),
    )

    cur.execute("SELECT COUNT(*) FROM tmp_cpi_case")
    cnt = cur.fetchone()[0]
    if cnt == 0:
        raise RuntimeError(f"tmp_cpi_case has 0 rows for hospital_code={hospital_code_upper}")

    if total_matched > MAX_CASE_ROWS:
        print(f"主表匹配数据超过 {MAX_CASE_ROWS} 条，已按排序仅保留前 {MAX_CASE_ROWS} 条")
    else:
        print(f"主表匹配数据不超过 {MAX_CASE_ROWS} 条，全部保留")


def insert_existing_one_row_per_patient_key(cur, temp_name, src_schema, src_table):
    create_temp_like(cur, temp_name, src_schema, src_table)
    order_expr = build_order_expr(cur, src_schema, src_table, alias="s")
    cols = get_columns(cur, src_schema, src_table)

    cur.execute(
        sql.SQL(
            """
            INSERT INTO {tmp}
            SELECT {cols}
            FROM (
                SELECT s.*,
                ROW_NUMBER() OVER (
                PARTITION BY s.patient_key
                ORDER BY {order_expr}
                ) AS __rn
                FROM {src} s
                JOIN (
                SELECT DISTINCT patient_key
                FROM tmp_cpi_case
                WHERE patient_key IS NOT NULL
                ) k
                ON s.patient_key = k.patient_key
                ) t
            WHERE t.__rn = 1
            """
        ).format(
            tmp=sql.Identifier(temp_name),
            src=qident(src_schema, src_table),
            cols=sql.SQL(", ").join(sql.Identifier(c) for c in cols),
            order_expr=order_expr,
        )
    )


def insert_existing_one_row_per_discharge_key(cur):
    create_temp_like(cur, "tmp_discharge_information", DISCHARGE_SCHEMA, DISCHARGE_TABLE)
    order_expr = build_order_expr(cur, DISCHARGE_SCHEMA, DISCHARGE_TABLE, alias="s")
    cols = get_columns(cur, DISCHARGE_SCHEMA, DISCHARGE_TABLE)

    cur.execute(
        sql.SQL(
            """
            INSERT INTO tmp_discharge_information
            SELECT {cols}
            FROM (
                SELECT s.*,
                ROW_NUMBER() OVER (
                PARTITION BY s.hospital_code, s.case_no, s.specialty
                ORDER BY {order_expr}
                ) AS __rn
                FROM {src} s
                JOIN (
                SELECT DISTINCT hospital_code, case_no, last_specialty
                FROM tmp_cpi_case
                WHERE hospital_code IS NOT NULL
                AND case_no IS NOT NULL
                AND last_specialty IS NOT NULL
                ) k
                ON s.hospital_code = k.hospital_code
                AND s.case_no = k.case_no
                AND s.specialty = k.last_specialty
                ) t
            WHERE t.__rn = 1
            """
        ).format(
            tmp=sql.Identifier("tmp_discharge_information"),
            src=qident(DISCHARGE_SCHEMA, DISCHARGE_TABLE),
            cols=sql.SQL(", ").join(sql.Identifier(c) for c in cols),
            order_expr=order_expr,
        )
    )


def fetch_missing_patient_keys(cur, temp_name):
    cur.execute(
        sql.SQL(
            """
            SELECT k.patient_key
            FROM (
                     SELECT DISTINCT patient_key
                     FROM tmp_cpi_case
                     WHERE patient_key IS NOT NULL
                 ) k
                     LEFT JOIN (
                SELECT DISTINCT patient_key
                FROM {tmp}
            ) t
                               ON k.patient_key = t.patient_key
            WHERE t.patient_key IS NULL
            ORDER BY k.patient_key
            """
        ).format(tmp=sql.Identifier(temp_name))
    )
    return [r[0] for r in cur.fetchall()]


def fetch_missing_discharge_keys(cur):
    cur.execute(
        """
        SELECT k.hospital_code, k.case_no, k.last_specialty
        FROM (
                 SELECT DISTINCT hospital_code, case_no, last_specialty
                 FROM tmp_cpi_case
                 WHERE hospital_code IS NOT NULL
                   AND case_no IS NOT NULL
                   AND last_specialty IS NOT NULL
             ) k
                 LEFT JOIN (
            SELECT DISTINCT hospital_code, case_no, specialty
            FROM tmp_discharge_information
        ) t
                           ON k.hospital_code = t.hospital_code
                               AND k.case_no = t.case_no
                               AND k.last_specialty = t.specialty
        WHERE t.hospital_code IS NULL
        ORDER BY k.hospital_code, k.case_no, k.last_specialty
        """
    )
    return cur.fetchall()


def fetch_donor_rows(cur, schema, table, count_needed):
    cols = get_columns(cur, schema, table)
    order_expr = build_order_expr(cur, schema, table)

    cur.execute(
        sql.SQL(
            "SELECT {cols} FROM {src} ORDER BY {order_expr} LIMIT %s"
        ).format(
            cols=sql.SQL(", ").join(sql.Identifier(c) for c in cols),
            src=qident(schema, table),
            order_expr=order_expr,
        ),
        (max(1, count_needed),),
    )
    rows = cur.fetchall()
    if not rows:
        raise RuntimeError(f"No donor rows available in {schema}.{table}")
    return cols, rows


def fill_missing_patient_like(cur, temp_name, schema, table):
    missing_keys = fetch_missing_patient_keys(cur, temp_name)
    if not missing_keys:
        return 0

    cols, donor_rows = fetch_donor_rows(cur, schema, table, len(missing_keys))
    donor_cycle = itertools.cycle(donor_rows)

    rows_to_insert = []
    for patient_key in missing_keys:
        donor = list(next(donor_cycle))
        row = dict(zip(cols, donor))
        row["patient_key"] = patient_key
        rows_to_insert.append([row[c] for c in cols])

    insert_sql = sql.SQL(
        "INSERT INTO {tmp} ({cols}) VALUES ({vals})"
    ).format(
        tmp=sql.Identifier(temp_name),
        cols=sql.SQL(", ").join(sql.Identifier(c) for c in cols),
        vals=sql.SQL(", ").join(sql.Placeholder() for _ in cols),
    )

    execute_batch(cur, insert_sql.as_string(cur.connection), rows_to_insert, page_size=1000)
    return len(rows_to_insert)


def fill_missing_discharge(cur):
    missing_keys = fetch_missing_discharge_keys(cur)
    if not missing_keys:
        return 0

    cols, donor_rows = fetch_donor_rows(cur, DISCHARGE_SCHEMA, DISCHARGE_TABLE, len(missing_keys))
    donor_cycle = itertools.cycle(donor_rows)

    rows_to_insert = []
    for hospital_code, case_no, last_specialty in missing_keys:
        donor = list(next(donor_cycle))
        row = dict(zip(cols, donor))
        row["hospital_code"] = hospital_code
        row["case_no"] = case_no
        row["specialty"] = last_specialty
        rows_to_insert.append([row[c] for c in cols])

    insert_sql = sql.SQL(
        "INSERT INTO tmp_discharge_information ({cols}) VALUES ({vals})"
    ).format(
        cols=sql.SQL(", ").join(sql.Identifier(c) for c in cols),
        vals=sql.SQL(", ").join(sql.Placeholder() for _ in cols),
    )

    execute_batch(cur, insert_sql.as_string(cur.connection), rows_to_insert, page_size=1000)
    return len(rows_to_insert)


def overwrite_table(cur, schema, table, temp_name):
    cols = get_columns(cur, schema, table)
    cur.execute(sql.SQL("DELETE FROM {dst}").format(dst=qident(schema, table)))
    cur.execute(
        sql.SQL(
            "INSERT INTO {dst} ({cols}) SELECT {cols} FROM {tmp}"
        ).format(
            dst=qident(schema, table),
            cols=sql.SQL(", ").join(sql.Identifier(c) for c in cols),
            tmp=sql.Identifier(temp_name),
        )
    )


def validate(cur, hospital_code_upper):
    cur.execute("SELECT COUNT(*) FROM hpi.cpi_case")
    case_cnt = cur.fetchone()[0]

    cur.execute("SELECT COUNT(*) FROM hpi.cpi_patient")
    patient_cnt = cur.fetchone()[0]

    cur.execute("SELECT COUNT(*) FROM hpi.cpi_patient_hospital_data")
    phd_cnt = cur.fetchone()[0]

    cur.execute("SELECT COUNT(*) FROM cms.discharge_information")
    discharge_cnt = cur.fetchone()[0]

    cur.execute(
        """
        SELECT COUNT(*)
        FROM hpi.cpi_case a
                 LEFT JOIN hpi.cpi_patient b
                           ON a.patient_key = b.patient_key
                 LEFT JOIN hpi.cpi_patient_hospital_data c
                           ON a.patient_key = c.patient_key
                 LEFT JOIN cms.discharge_information d
                           ON a.hospital_code = d.hospital_code
                               AND a.case_no = d.case_no
                               AND a.last_specialty = d.specialty
        """
    )
    join_cnt = cur.fetchone()[0]

    cur.execute(
        """
        SELECT COUNT(*)
        FROM hpi.cpi_case a
                 LEFT JOIN hpi.cpi_patient b
                           ON a.patient_key = b.patient_key
        WHERE b.patient_key IS NULL
        """
    )
    miss_patient = cur.fetchone()[0]

    cur.execute(
        """
        SELECT COUNT(*)
        FROM hpi.cpi_case a
                 LEFT JOIN hpi.cpi_patient_hospital_data c
                           ON a.patient_key = c.patient_key
        WHERE c.patient_key IS NULL
        """
    )
    miss_phd = cur.fetchone()[0]

    cur.execute(
        """
        SELECT COUNT(*)
        FROM hpi.cpi_case a
                 LEFT JOIN cms.discharge_information d
                           ON a.hospital_code = d.hospital_code
                               AND a.case_no = d.case_no
                               AND a.last_specialty = d.specialty
        WHERE d.hospital_code IS NULL
        """
    )
    miss_discharge = cur.fetchone()[0]

    cur.execute(
        "SELECT COUNT(*) FROM hpi.cpi_case WHERE upper(hospital_code) = %s",
        (hospital_code_upper,),
    )
    case_hospital_cnt = cur.fetchone()[0]

    return {
        "cpi_case": case_cnt,
        "cpi_patient": patient_cnt,
        "cpi_patient_hospital_data": phd_cnt,
        "discharge_information": discharge_cnt,
        "join_result_rows": join_cnt,
        "missing_patient": miss_patient,
        "missing_patient_hospital_data": miss_phd,
        "missing_discharge": miss_discharge,
        "case_with_hospital_code": case_hospital_cnt,
    }


@contextmanager
def get_conn(host, port, user, password, dbname):
    conn = psycopg2.connect(
        host=host,
        port=port,
        user=user,
        password=password,
        dbname=dbname,
    )
    conn.autocommit = False
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def process_database(host, port, user, password, dbname_lower, hospital_code_upper):
    print(f"\n{'=' * 70}")
    print(f"开始处理数据库: {dbname_lower}, hospital_code={hospital_code_upper}")
    print(f"{'=' * 70}")
    print(f"参数标准化结果: dbname={dbname_lower}, hospital_code={hospital_code_upper}")

    with get_conn(host, port, user, password, dbname_lower) as conn:
        with conn.cursor() as cur:
            alter_discharge_information_columns(cur)

            insert_selected_cases_by_hospital(cur, hospital_code_upper)
            cur.execute("SELECT COUNT(*) FROM tmp_cpi_case")
            tmp_case_cnt = cur.fetchone()[0]
            print(f"tmp_cpi_case 已生成: {tmp_case_cnt} 条")

            insert_existing_one_row_per_patient_key(cur, "tmp_cpi_patient", PATIENT_SCHEMA, PATIENT_TABLE)
            print("tmp_cpi_patient 已从原表抽取可关联数据")

            insert_existing_one_row_per_patient_key(cur, "tmp_cpi_patient_hospital_data", PHD_SCHEMA, PHD_TABLE)
            print("tmp_cpi_patient_hospital_data 已从原表抽取可关联数据")

            insert_existing_one_row_per_discharge_key(cur)
            print("tmp_discharge_information 已从原表抽取可关联数据")

            filled_patient = fill_missing_patient_like(cur, "tmp_cpi_patient", PATIENT_SCHEMA, PATIENT_TABLE)
            print(f"tmp_cpi_patient 缺失补齐: {filled_patient} 条")

            filled_phd = fill_missing_patient_like(cur, "tmp_cpi_patient_hospital_data", PHD_SCHEMA, PHD_TABLE)
            print(f"tmp_cpi_patient_hospital_data 缺失补齐: {filled_phd} 条")

            filled_discharge = fill_missing_discharge(cur)
            print(f"tmp_discharge_information 缺失补齐: {filled_discharge} 条")

            overwrite_table(cur, CASE_SCHEMA, CASE_TABLE, "tmp_cpi_case")
            overwrite_table(cur, DISCHARGE_SCHEMA, DISCHARGE_TABLE, "tmp_discharge_information")
            overwrite_table(cur, PHD_SCHEMA, PHD_TABLE, "tmp_cpi_patient_hospital_data")
            overwrite_table(cur, PATIENT_SCHEMA, PATIENT_TABLE, "tmp_cpi_patient")
            print("原表覆盖完成")

            stats = validate(cur, hospital_code_upper)
            print("校验结果:")
            for k, v in stats.items():
                print(f"  - {k}: {v}")

            if stats["cpi_case"] == 0:
                raise RuntimeError(f"{dbname_lower}: cpi_case 最终为空")
            if stats["cpi_case"] > MAX_CASE_ROWS:
                raise RuntimeError(f"{dbname_lower}: cpi_case 最终超过 {MAX_CASE_ROWS} 条")
            if stats["case_with_hospital_code"] != stats["cpi_case"]:
                raise RuntimeError(
                    f"{dbname_lower}: 存在不属于 hospital_code={hospital_code_upper} 的 cpi_case 数据"
                )
            if stats["missing_patient"] != 0:
                raise RuntimeError(f"{dbname_lower}: 仍有 cpi_case 无法关联 cpi_patient")
            if stats["missing_patient_hospital_data"] != 0:
                raise RuntimeError(f"{dbname_lower}: 仍有 cpi_case 无法关联 cpi_patient_hospital_data")
            if stats["missing_discharge"] != 0:
                raise RuntimeError(f"{dbname_lower}: 仍有 cpi_case 无法关联 discharge_information")

            print(f"数据库 {dbname_lower} 处理完成。")


def parse_hospital_codes(raw_value):
    if not raw_value or not raw_value.strip():
        raise RuntimeError("hospital codes 不能为空")

    items = [x.strip() for x in raw_value.split(",")]
    items = [x for x in items if x]

    if not items:
        raise RuntimeError("hospital codes 不能为空")

    deduped = []
    seen = set()
    for item in items:
        key = item.lower()
        if key not in seen:
            seen.add(key)
            deduped.append(item)
    return deduped


def normalize_inputs(hospital_code_input, dbname_prefix=None):
    hospital_code_upper = hospital_code_input.upper()
    dbname_lower = hospital_code_input.lower()
    if dbname_prefix:
        dbname_lower = f"{dbname_prefix}{dbname_lower}"
    return dbname_lower, hospital_code_upper


def main():
    parser = argparse.ArgumentParser(
        description="Shrink multiple hospital datasets in target databases, based on hpi.cpi_case.hospital_code."
    )
    parser.add_argument("--host", required=True)
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--user", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument(
        "--hospital-codes",
        required=True,
        help="多个医院编号，逗号分隔，例如 qeh,qmh 或 QEH,QMH",
    )
    parser.add_argument(
        "--dbname-prefix",
        default="",
        help="可选，数据库名前缀，例如传 test_ 后，qeh -> test_qeh",
    )
    args = parser.parse_args()

    hospital_codes = parse_hospital_codes(args.hospital_codes)

    failed = []

    for hospital_code_input in hospital_codes:
        dbname_lower, hospital_code_upper = normalize_inputs(
            hospital_code_input,
            args.dbname_prefix,
        )

        try:
            process_database(
                args.host,
                args.port,
                args.user,
                args.password,
                dbname_lower,
                hospital_code_upper,
            )
        except Exception as e:
            failed.append((hospital_code_input, str(e)))
            print(f"\n处理失败: hospital_code={hospital_code_input}, error={e}", file=sys.stderr)

    if failed:
        print("\n以下医院处理失败：", file=sys.stderr)
        for code, err in failed:
            print(f"  - {code}: {err}", file=sys.stderr)
        sys.exit(1)

    print("\n全部处理完成。")


if __name__ == "__main__":
    main()