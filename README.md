````md
# Mul Operator — Hypothesis Tests (ONNX / ONNX Runtime)

This folder contains a **property-based** test (Hypothesis) for the ONNX **Mul** operator, executed with **onnxruntime**.

## 1) Requirements

- Windows + PowerShell
- Python **3.12** (recommended if you’re already on it)
- A virtual environment `.venv`

## 2) Setup / Install

From the project folder:

```yaml
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
````

### ONNX “DLL load failed” issue

If `import onnx` fails with:
`ImportError: DLL load failed while importing onnx_cpp2py_export`

Fix used:

```yaml
pip uninstall -y onnx
pip install "onnx==1.16.1"
python -c "import onnx; print(onnx.__version__)"
```

## 3) Run the tests

Run only Mul tests:

```yaml
pytest -q -k test_mul -s
```

* `-q`: quiet output
* `-k test_mul`: filter tests containing “test_mul”
* `-s`: show printed output (`print()`)

## 4) Expected output

### Passing case

You should see a dot `.` and:

* `1 passed` (or more)
* possibly warnings

Example:

```
.
1 passed, 1 warning in XXs
```

### “overflow encountered in multiply” warning

This warning comes from NumPy when integer multiplication overflows (wrap-around behavior).
It is **not** a test failure.

```
RuntimeWarning: overflow encountered in multiply
```

## 5) Supported dtypes and uint8 / int8

With **CPUExecutionProvider**, ONNX Runtime may reject some `Mul` input types, typically `uint8` / `int8`:

```
InvalidGraph: Type Error: Type 'tensor(uint8)' ... is invalid.
```

If this happens, remove those types from `mul_types["CPUExecutionProvider"]` (or test using another provider / a Cast-based graph).

## 6) Check available providers

```yaml
python -c "import onnxruntime as ort; print(ort.__version__); print(ort.get_available_providers())"
```

Expected example:

```
1.24.2
['AzureExecutionProvider', 'CPUExecutionProvider']
```

## 7) NaN / +/-Inf (float tests)

To allow NaN and +/-Inf in Hypothesis float generation, use:

* `st.floats(allow_nan=True, allow_infinity=True, width=...)`
* and compare using `np.testing.assert_allclose(..., equal_nan=True)`

Important: Hypothesis **forbids** `allow_nan=True` when `min_value` or `max_value` is set.

## 8) Generated file

After running the tests, the following file is written:

* `generated_data.json`

It contains generated shapes and tensors for debugging/inspection.

```
```

