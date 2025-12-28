#!/usr/bin/env python3
import sys
import os
import pandas as pd

def main():
    if len(sys.argv) < 5:
        print(
            "Usage: copy_rows.py INPUT_FILE OUTPUT_FILE N MODE [SHEET_NAME] [SEED]",
            file=sys.stderr,
        )
        sys.exit(1)

    input_path = sys.argv[1]
    output_path = sys.argv[2]
    n_str = sys.argv[3]
    mode = sys.argv[4].lower()  # head | tail | random
    sheet_name = sys.argv[5] if len(sys.argv) >= 6 and sys.argv[5] != "" else None
    seed_str = sys.argv[6] if len(sys.argv) >= 7 and sys.argv[6] != "" else None

    # Validate N
    if not n_str.isdigit():
        print(f"Error: N must be a non-negative integer (got: {n_str})", file=sys.stderr)
        sys.exit(1)
    n = int(n_str)

    if mode not in ("head", "tail", "random"):
        print("Error: MODE must be one of: head, tail, random", file=sys.stderr)
        sys.exit(1)

    seed = None
    if seed_str is not None:
        if not seed_str.lstrip("-").isdigit():
            print(f"Error: SEED must be an integer (got: {seed_str})", file=sys.stderr)
            sys.exit(1)
        seed = int(seed_str)

    if not os.path.isfile(input_path):
        print(f"Error: Input file '{input_path}' not found.", file=sys.stderr)
        sys.exit(1)

    # Detect input type by extension
    ext_in = os.path.splitext(input_path)[1].lower()
    if ext_in == ".csv":
        df = pd.read_csv(input_path)
    elif ext_in in (".xls", ".xlsx"):
        # Default: first sheet, unless a sheet name is provided
        df = pd.read_excel(input_path, sheet_name=(sheet_name or 0))
    else:
        print(
            f"Error: Unsupported input extension '{ext_in}'. Only .csv, .xls, .xlsx are supported.",
            file=sys.stderr,
        )
        sys.exit(1)

    if n <= 0 or df.empty:
        # Just write header with no rows
        out_df = df.head(0)
    else:
        n = min(n, len(df))
        if mode == "head":
            out_df = df.head(n)
        elif mode == "tail":
            out_df = df.tail(n)
        else:  # random
            out_df = df.sample(n=n, random_state=seed)

    # Detect output type by extension
    ext_out = os.path.splitext(output_path)[1].lower()
    if ext_out == ".csv":
        out_df.to_csv(output_path, index=False)
    elif ext_out in (".xls", ".xlsx"):
        out_df.to_excel(output_path, index=False)
    else:
        print(
            f"Error: Unsupported output extension '{ext_out}'. Only .csv, .xls, .xlsx are supported.",
            file=sys.stderr,
        )
        sys.exit(1)

if __name__ == "__main__":
    main()
