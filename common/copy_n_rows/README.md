# copy_n_rows

Copy **N rows** from a **CSV/Excel** file into a new file.

- `copy_n_rows` (bash) = wrapper you run
- `python_scripts/copy_rows.py` (python) = does the work with pandas

## Setup (once)

1) Put files in this layout:

```
your_folder/
├── copy_n_rows
└── python_scripts/
    └── copy_rows.py
```

2) Make the wrapper executable:

```bash
chmod +x copy_n_rows
```

3) Create a conda env (example):

```bash
conda create -n general-env -y python=3.10 pandas openpyxl
```

> Why `openpyxl`?  
> `copy_rows.py` calls `pandas.read_excel()` / `DataFrame.to_excel()`. For `.xlsx`, pandas uses **openpyxl** under the hood, even though it’s not imported directly in the script.

If you only use CSV files, you can skip `openpyxl`.

## Usage

```bash
./copy_n_rows INPUT OUTPUT N [head|tail|random] [SHEET_NAME or SEED] [SEED]
```

- Default mode is `head`.
- For Excel, if you don’t provide a sheet name, it uses the **first sheet**.
- In `random` mode, a seed makes results reproducible.

## Examples

First 200 rows:

```bash
./copy_n_rows in.xlsx out.xlsx 200
```

Last 200 rows:

```bash
./copy_n_rows in.xlsx out.xlsx 200 tail
```

200 random rows with a seed:

```bash
./copy_n_rows in.xlsx out.xlsx 200 random 42
```

## Run the Python script directly (optional)

```bash
python python_scripts/copy_rows.py INPUT OUTPUT N MODE [SHEET_NAME] [SEED]
```
