Here’s a short, practical **English mini-tutorial** (based on your logs) to run your ONNX + Hypothesis tests from the terminal on Windows.

---

## Run the Mul Hypothesis tests (Windows + PowerShell)

### 1) Open PowerShell and go to the project folder

```powershell
cd "C:\Users\hamza\Desktop\Stage EXUPERY\Opération Mul"
```

### 2) Activate your virtual environment

```powershell
.\.venv\Scripts\Activate.ps1
```

You should see `(.venv)` at the beginning of your prompt.

### 3) Quick sanity checks (optional but recommended)

Check ONNX import works:

```powershell
python -c "import onnx; print(onnx.__version__)"
```

Check ONNX Runtime works and see available providers:

```powershell
python -c "import onnxruntime as ort; print(ort.__version__); print(ort.get_available_providers())"
```

Typical output on CPU:
`['AzureExecutionProvider', 'CPUExecutionProvider']`

### 4) Install dependencies (if not done yet)

```powershell
pip install -r requirements.txt
```

### 5) Run the Mul test only (with prints enabled)

* `-q` = quiet output
* `-k test_mul` = select tests whose name matches “test_mul”
* `-s` = show print() output

```powershell
pytest -q -k test_mul -s
```

### 6) Understand the output you saw

* A single dot `.` means the selected test passed.
* `1 passed` means the test succeeded.
* `1 deselected` means other tests were ignored because of your `-k` filter.
* The warning:
  `RuntimeWarning: overflow encountered in multiply`
  is expected when generating integer test cases (values can overflow in fixed-width integer multiplication). It’s a warning, not a failure.

### 7) If you hit ONNX DLL import errors

If you get:
`ImportError: DLL load failed while importing onnx_cpp2py_export`
A reliable fix (as in your logs) is to reinstall a compatible ONNX wheel, then re-check:

```powershell
pip uninstall -y onnx
pip install "onnx==1.16.1"
python -c "import onnx; print('onnx ok', onnx.__version__)"
```

### 8) If a test fails with uint8 / int8 (InvalidGraph)

If you see:
`INVALID_GRAPH: Type 'tensor(uint8)' ... is invalid`
that means **ONNX Runtime CPU does not support Mul for that dtype** in your setup. In that case, remove `UINT8/INT8` from the CPU type list used by the test, or test with another provider that supports it.

---

If you want, paste your current `requirements.txt` and I’ll give you the cleanest “CPU-only” version (to avoid TensorFlow/ml_dtypes headaches).
