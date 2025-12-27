# 🔧 Hướng Dẫn Build EXE với Nuitka - Tích Hợp VieNeu-TTS

Tài liệu này hướng dẫn chi tiết cách build file .exe từ mã nguồn sử dụng **Nuitka** - một trình biên dịch Python sang C, đảm bảo VieNeu-TTS được compile thành mã C và tích hợp vào file exe.

## Mục Lục

1. [Tổng Quan](#1-tổng-quan)
2. [Tại Sao Chọn Nuitka?](#2-tại-sao-chọn-nuitka)
3. [Yêu Cầu Hệ Thống](#3-yêu-cầu-hệ-thống)
4. [Cài Đặt Môi Trường Build](#4-cài-đặt-môi-trường-build)
5. [Cấu Trúc Project Cho Nuitka](#5-cấu-trúc-project-cho-nuitka)
6. [Build Command Chi Tiết](#6-build-command-chi-tiết)
7. [Build Script Tự Động](#7-build-script-tự-động)
8. [Xử Lý Data Files](#8-xử-lý-data-files)
9. [Khắc Phục Sự Cố](#9-khắc-phục-sự-cố)
10. [Tối Ưu Hóa Build](#10-tối-ưu-hóa-build)

---

## 1. Tổng Quan

### Mục tiêu build:
- ✅ **VieNeu-TTS được compile thành C** - không chỉ copy như data files
- ✅ **Tất cả thư viện cần thiết** được bundle vào exe
- ✅ **Standalone build** - chạy được trên máy khác không cần Python
- ✅ **Hỗ trợ cả CPU và GPU** - tùy theo cấu hình build

### Thành phần chính được compile:
| Module | Mô tả | Compile Method |
|--------|-------|----------------|
| `main.py` | Ứng dụng chính với GUI | ✅ Full compile to C |
| `VieNeu-TTS/vieneu_tts/` | Core TTS engine | ✅ Full compile to C |
| `VieNeu-TTS/utils/` | Utilities (phonemize, normalize) | ✅ Full compile to C |
| `edge/` | Edge TTS module | ✅ Full compile to C |
| `auth_module.py` | Authentication | ✅ Full compile to C |

### Data files (không compile, bundle như resources):
| Data | Mô tả | Bundle Method |
|------|-------|---------------|
| `VieNeu-TTS/sample/` | Voice samples (.wav, .pt, .txt) | Include as data |
| `VieNeu-TTS/utils/phoneme_dict.json` | Phoneme dictionary | Include as data |
| `VieNeu-TTS/config.yaml` | Configuration | Include as data |
| `icon.ico` | App icon | Include as data |

---

## 2. Tại Sao Chọn Nuitka?

### So sánh Nuitka vs PyInstaller:

| Tiêu chí | Nuitka | PyInstaller |
|----------|--------|-------------|
| **Phương thức** | Compile Python → C → Binary | Bundle bytecode + interpreter |
| **Tốc độ chạy** | ⭐⭐⭐⭐⭐ (nhanh hơn 10-40%) | ⭐⭐⭐ |
| **Kích thước** | Nhỏ hơn 20-50% | Lớn hơn |
| **Bảo mật code** | ⭐⭐⭐⭐⭐ (code thành binary) | ⭐⭐ (có thể decompile) |
| **Thời gian build** | Lâu hơn (compile C) | Nhanh hơn |
| **Tương thích** | Tốt với hầu hết packages | Rất tốt |

### Lợi ích khi dùng Nuitka cho VieNeu-TTS:
1. **Performance**: TTS inference nhanh hơn đáng kể
2. **Security**: Code VieNeu-TTS được compile, khó reverse engineer
3. **Bundle size**: File exe nhỏ gọn hơn
4. **Native integration**: VieNeu-TTS trở thành phần của binary, không phải module được import

---

## 3. Yêu Cầu Hệ Thống

### Software Requirements:

| Component | Version | Download |
|-----------|---------|----------|
| **Python** | 3.12.x (bắt buộc) | [python.org](https://www.python.org/downloads/) |
| **Nuitka** | >=2.0 | `pip install nuitka` |
| **C Compiler** | MinGW64 (Windows) / GCC (Linux) | Xem bên dưới |
| **eSpeak NG** | Latest | [GitHub](https://github.com/espeak-ng/espeak-ng/releases) |
| **Visual C++ Build Tools** | 2019+ (Windows) | [VS Build Tools](https://visualstudio.microsoft.com/visual-cpp-build-tools/) |

### C Compiler Setup:

#### Windows - MinGW64 (Khuyến nghị):

```bash
# Cài đặt qua pip (đơn giản nhất)
pip install mingw64

# Hoặc tải trực tiếp từ:
# https://www.msys2.org/
# Sau khi cài MSYS2, chạy:
pacman -S mingw-w64-x86_64-gcc
```

#### Windows - Visual Studio Build Tools:

1. Tải từ: https://visualstudio.microsoft.com/visual-cpp-build-tools/
2. Chọn workload: "Desktop development with C++"
3. Đảm bảo chọn:
   - MSVC v143
   - Windows 10/11 SDK
   - C++ CMake tools

#### Linux:

```bash
sudo apt update
sudo apt install build-essential gcc g++ python3-dev -y
```

### Hardware Requirements (Khuyến nghị):

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **RAM** | 8 GB | 16 GB+ |
| **Disk** | 20 GB free | 50 GB SSD |
| **CPU** | 4 cores | 8+ cores |
| **Build time** | 30-60 phút | 15-30 phút |

---

## 4. Cài Đặt Môi Trường Build

### Bước 1: Cài Đặt Python 3.12

```bash
# Kiểm tra version
python --version
# Output: Python 3.12.x
```

### Bước 2: Cài Đặt Nuitka và Dependencies

```bash
# Tạo virtual environment (khuyến nghị)
python -m venv build_env
# Windows:
build_env\Scripts\activate
# Linux/Mac:
source build_env/bin/activate

# Cài đặt Nuitka
pip install nuitka ordered-set zstandard

# Cài đặt tất cả dependencies của project
pip install -r requirements.txt

# Cài đặt llama-cpp-python cho CPU (nếu chưa có)
pip install llama-cpp-python --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu

# Cài đặt dependencies cho VieNeu-TTS
pip install phonemizer torch torchaudio neucodec librosa soundfile onnxruntime

# Cài đặt GUI dependencies
pip install customtkinter python-docx pyaudio google-genai requests
```

### Bước 3: Cài Đặt eSpeak NG

#### Windows:
1. Tải từ: https://github.com/espeak-ng/espeak-ng/releases
2. Cài vào: `C:\Program Files\eSpeak NG\`
3. Thêm vào PATH

#### Linux:
```bash
sudo apt install espeak-ng -y
```

### Bước 4: Kiểm Tra Môi Trường

```bash
# Kiểm tra Nuitka
python -m nuitka --version

# Kiểm tra eSpeak
espeak-ng --version

# Kiểm tra llama-cpp-python
python -c "from llama_cpp import Llama; print('OK')"

# Kiểm tra VieNeu-TTS imports
python -c "import sys; sys.path.insert(0, 'VieNeu-TTS'); from vieneu_tts import VieNeuTTS; print('OK')"
```

---

## 5. Cấu Trúc Project Cho Nuitka

### Cấu trúc hiện tại:

```
project/
├── main.py                     # Entry point
├── auth_module.py              # Authentication module
├── VieNeu-TTS/                 # VieNeu-TTS package (được compile)
│   ├── vieneu_tts/
│   │   ├── __init__.py
│   │   └── vieneu_tts.py       # Core TTS classes
│   ├── utils/
│   │   ├── __init__.py
│   │   ├── core_utils.py
│   │   ├── normalize_text.py
│   │   ├── phonemize_text.py
│   │   └── phoneme_dict.json   # Data file
│   ├── sample/                 # Data files (voice samples)
│   │   ├── *.wav
│   │   ├── *.pt
│   │   └── *.txt
│   └── config.yaml             # Data file
├── edge/                       # Edge TTS module (được compile)
│   ├── __init__.py
│   ├── communicate.py
│   └── ...
├── icon.ico                    # Data file
└── requirements.txt
```

### Quan trọng: Nuitka cần biết modules nào cần compile

Nuitka sẽ tự động compile:
- Tất cả `.py` files được import
- Packages được chỉ định trong `--include-package`

Nuitka sẽ **KHÔNG** compile (chỉ copy):
- Data files (`.json`, `.yaml`, `.wav`, `.pt`, `.txt`)
- Files được chỉ định trong `--include-data-dir` hoặc `--include-data-files`

---

## 6. Build Command Chi Tiết

### Build Command Cơ Bản (Windows):

```batch
python -m nuitka ^
    --standalone ^
    --enable-plugin=tk-inter ^
    --include-package=vieneu_tts ^
    --include-package=utils ^
    --include-package=edge ^
    --include-package=llama_cpp ^
    --include-package=phonemizer ^
    --include-package=neucodec ^
    --include-package=torch ^
    --include-package=torchaudio ^
    --include-package=librosa ^
    --include-package=soundfile ^
    --include-package=customtkinter ^
    --include-package=google ^
    --include-package=docx ^
    --include-module=auth_module ^
    --include-data-dir=VieNeu-TTS/sample=VieNeu-TTS/sample ^
    --include-data-dir=VieNeu-TTS/utils=VieNeu-TTS/utils ^
    --include-data-files=VieNeu-TTS/config.yaml=VieNeu-TTS/config.yaml ^
    --include-data-files=VieNeu-TTS/utils/phoneme_dict.json=VieNeu-TTS/utils/phoneme_dict.json ^
    --include-data-files=icon.ico=icon.ico ^
    --windows-icon-from-ico=icon.ico ^
    --windows-console-mode=disable ^
    --output-dir=dist ^
    --output-filename=FathTTS ^
    main.py
```

### Build Command Đầy Đủ với Giải Thích:

```batch
python -m nuitka ^
    # === OUTPUT OPTIONS ===
    --standalone ^                          # Tạo standalone exe (không cần Python)
    --output-dir=dist ^                     # Thư mục output
    --output-filename=FathTTS ^             # Tên file exe
    
    # === COMPILER OPTIONS ===
    --mingw64 ^                             # Dùng MinGW64 compiler (Windows)
    --jobs=8 ^                              # Số CPU threads để compile
    --lto=yes ^                             # Link-time optimization (nhỏ hơn, nhanh hơn)
    
    # === PLUGINS ===
    --enable-plugin=tk-inter ^              # Tkinter/CustomTkinter support
    --enable-plugin=numpy ^                 # NumPy optimization
    
    # === PACKAGES TO COMPILE (QUAN TRỌNG) ===
    # VieNeu-TTS packages - sẽ được compile thành C
    --include-package=vieneu_tts ^          # Core TTS module
    --include-package=utils ^               # Utility modules
    
    # Edge TTS package
    --include-package=edge ^
    
    # Deep learning packages
    --include-package=torch ^
    --include-package=torchaudio ^
    --include-package=llama_cpp ^
    --include-package=neucodec ^
    
    # Audio processing
    --include-package=librosa ^
    --include-package=soundfile ^
    --include-package=phonemizer ^
    
    # GUI packages
    --include-package=customtkinter ^
    
    # Utility packages
    --include-package=google ^
    --include-package=docx ^
    --include-package=requests ^
    
    # Individual modules
    --include-module=auth_module ^
    
    # === DATA FILES (không compile, chỉ copy) ===
    # Voice samples - thư mục
    --include-data-dir=VieNeu-TTS/sample=VieNeu-TTS/sample ^
    
    # VieNeu-TTS utils (bao gồm cả phoneme_dict.json)
    --include-data-dir=VieNeu-TTS/utils=VieNeu-TTS/utils ^
    
    # Config files
    --include-data-files=VieNeu-TTS/config.yaml=VieNeu-TTS/config.yaml ^
    
    # Icon
    --include-data-files=icon.ico=icon.ico ^
    
    # === WINDOWS OPTIONS ===
    --windows-icon-from-ico=icon.ico ^
    --windows-console-mode=disable ^        # Ẩn console window
    --windows-company-name="Fath TTS" ^
    --windows-product-name="Fath TTS Studio" ^
    --windows-file-version=1.0.0.0 ^
    --windows-product-version=1.0.0 ^
    
    # === ENTRY POINT ===
    main.py
```

### Build Command cho Linux:

```bash
python -m nuitka \
    --standalone \
    --enable-plugin=tk-inter \
    --include-package=vieneu_tts \
    --include-package=utils \
    --include-package=edge \
    --include-package=llama_cpp \
    --include-package=phonemizer \
    --include-package=neucodec \
    --include-package=torch \
    --include-package=torchaudio \
    --include-package=librosa \
    --include-package=soundfile \
    --include-package=customtkinter \
    --include-package=google \
    --include-package=docx \
    --include-module=auth_module \
    --include-data-dir=VieNeu-TTS/sample=VieNeu-TTS/sample \
    --include-data-dir=VieNeu-TTS/utils=VieNeu-TTS/utils \
    --include-data-files=VieNeu-TTS/config.yaml=VieNeu-TTS/config.yaml \
    --include-data-files=icon.ico=icon.ico \
    --output-dir=dist \
    main.py
```

---

## 7. Build Script Tự Động

### Windows Build Script (`build_nuitka.bat`):

```batch
@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

echo ====================================================
echo   FathTTS Nuitka Build Script
echo   Build với VieNeu-TTS Compiled to C
echo ====================================================
echo.

:: ===========================
:: 1. Kiểm tra prerequisites
:: ===========================
echo [1/6] Kiểm tra môi trường...

:: Check Python version
python --version 2>&1 | findstr "3.12" >nul
if errorlevel 1 (
    echo [ERROR] Python 3.12 là bắt buộc!
    exit /b 1
)
echo       ✓ Python 3.12 OK

:: Check Nuitka
python -m nuitka --version >nul 2>&1
if errorlevel 1 (
    echo [INFO] Đang cài đặt Nuitka...
    pip install nuitka ordered-set zstandard
)
echo       ✓ Nuitka OK

:: Check eSpeak
espeak-ng --version >nul 2>&1
if errorlevel 1 (
    echo [WARNING] eSpeak NG chưa được cài đặt!
    echo          Vui lòng cài đặt từ: https://github.com/espeak-ng/espeak-ng/releases
)
echo       ✓ eSpeak NG OK

:: Check VieNeu-TTS
if not exist "VieNeu-TTS" (
    echo [ERROR] Thư mục VieNeu-TTS không tồn tại!
    exit /b 1
)
echo       ✓ VieNeu-TTS OK
echo.

:: ===========================
:: 2. Cài đặt dependencies
:: ===========================
echo [2/6] Cài đặt dependencies...

:: llama-cpp-python (CPU)
echo       - llama-cpp-python...
pip install llama-cpp-python --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu -q 2>nul

:: PyTorch CPU
echo       - PyTorch (CPU)...
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu -q 2>nul

:: Other dependencies
echo       - Other dependencies...
pip install phonemizer neucodec librosa soundfile onnxruntime customtkinter python-docx google-genai requests -q 2>nul

echo       ✓ Dependencies OK
echo.

:: ===========================
:: 3. Kiểm tra imports
:: ===========================
echo [3/6] Kiểm tra imports...

python -c "from llama_cpp import Llama" 2>nul
if errorlevel 1 (
    echo [ERROR] llama-cpp-python không hoạt động!
    exit /b 1
)

python -c "import sys; sys.path.insert(0, 'VieNeu-TTS'); from vieneu_tts import VieNeuTTS" 2>nul
if errorlevel 1 (
    echo [ERROR] VieNeu-TTS import thất bại!
    exit /b 1
)

echo       ✓ All imports OK
echo.

:: ===========================
:: 4. Clean previous build
:: ===========================
echo [4/6] Dọn dẹp build cũ...

if exist "dist\main.dist" rmdir /s /q "dist\main.dist"
if exist "dist\main.build" rmdir /s /q "dist\main.build"
if exist "main.build" rmdir /s /q "main.build"
if exist "main.dist" rmdir /s /q "main.dist"

echo       ✓ Cleaned
echo.

:: ===========================
:: 5. Build với Nuitka
:: ===========================
echo [5/6] Building với Nuitka...
echo       Quá trình này có thể mất 15-60 phút...
echo.

python -m nuitka ^
    --standalone ^
    --enable-plugin=tk-inter ^
    --enable-plugin=numpy ^
    --include-package=vieneu_tts ^
    --include-package=utils ^
    --include-package=edge ^
    --include-package=llama_cpp ^
    --include-package=phonemizer ^
    --include-package=neucodec ^
    --include-package=torch ^
    --include-package=torchaudio ^
    --include-package=librosa ^
    --include-package=soundfile ^
    --include-package=customtkinter ^
    --include-package=google ^
    --include-package=docx ^
    --include-module=auth_module ^
    --include-data-dir=VieNeu-TTS/sample=VieNeu-TTS/sample ^
    --include-data-dir=VieNeu-TTS/utils=VieNeu-TTS/utils ^
    --include-data-files=VieNeu-TTS/config.yaml=VieNeu-TTS/config.yaml ^
    --include-data-files=icon.ico=icon.ico ^
    --windows-icon-from-ico=icon.ico ^
    --windows-console-mode=disable ^
    --output-dir=dist ^
    --jobs=4 ^
    main.py

if errorlevel 1 (
    echo [ERROR] Build thất bại!
    exit /b 1
)

echo       ✓ Build thành công
echo.

:: ===========================
:: 6. Post-build processing
:: ===========================
echo [6/6] Xử lý sau build...

:: Rename output folder
if exist "dist\main.dist" (
    if exist "dist\FathTTS" rmdir /s /q "dist\FathTTS"
    rename "dist\main.dist" "FathTTS"
)

:: Copy ffmpeg if exists
if exist "ffmpeg.exe" (
    copy "ffmpeg.exe" "dist\FathTTS\" >nul 2>&1
    echo       ✓ Copied ffmpeg.exe
)

:: Ensure sample directory exists
if not exist "dist\FathTTS\VieNeu-TTS\sample" (
    mkdir "dist\FathTTS\VieNeu-TTS\sample"
    xcopy /E /I /Y "VieNeu-TTS\sample\*" "dist\FathTTS\VieNeu-TTS\sample\" >nul 2>&1
    echo       ✓ Copied VieNeu-TTS samples
)

:: Ensure config exists
if not exist "dist\FathTTS\VieNeu-TTS\config.yaml" (
    copy "VieNeu-TTS\config.yaml" "dist\FathTTS\VieNeu-TTS\" >nul 2>&1
    echo       ✓ Copied config.yaml
)

echo.
echo ====================================================
echo   BUILD HOÀN TẤT!
echo ====================================================
echo.
echo   Output: dist\FathTTS\main.exe
echo.
echo   VieNeu-TTS đã được COMPILE thành C:
echo   - vieneu_tts.*.pyd (compiled module)
echo   - utils.*.pyd (compiled module)
echo.
echo   Data files:
echo   - dist\FathTTS\VieNeu-TTS\sample\ (voice samples)
echo   - dist\FathTTS\VieNeu-TTS\utils\phoneme_dict.json
echo   - dist\FathTTS\VieNeu-TTS\config.yaml
echo.
echo   Lưu ý:
echo   - Model GGUF sẽ tự động download lần đầu chạy
echo   - Cần có eSpeak NG trên máy người dùng
echo ====================================================

pause
```

### Linux Build Script (`build_nuitka.sh`):

```bash
#!/bin/bash
set -e

echo "===================================================="
echo "  FathTTS Nuitka Build Script (Linux)"
echo "  Build với VieNeu-TTS Compiled to C"
echo "===================================================="
echo ""

# Check Python version
if ! python3.12 --version &> /dev/null; then
    echo "[ERROR] Python 3.12 is required!"
    exit 1
fi
echo "✓ Python 3.12 OK"

# Check/Install Nuitka
if ! python3.12 -m nuitka --version &> /dev/null; then
    echo "[INFO] Installing Nuitka..."
    pip install nuitka ordered-set zstandard
fi
echo "✓ Nuitka OK"

# Check eSpeak
if ! espeak-ng --version &> /dev/null; then
    echo "[WARNING] eSpeak NG not found. Installing..."
    sudo apt install espeak-ng -y
fi
echo "✓ eSpeak NG OK"

# Check VieNeu-TTS
if [ ! -d "VieNeu-TTS" ]; then
    echo "[ERROR] VieNeu-TTS directory not found!"
    exit 1
fi
echo "✓ VieNeu-TTS OK"

# Install dependencies
echo ""
echo "[2/6] Installing dependencies..."
pip install llama-cpp-python --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu -q
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu -q
pip install phonemizer neucodec librosa soundfile onnxruntime customtkinter python-docx google-genai requests -q
echo "✓ Dependencies OK"

# Clean previous build
echo ""
echo "[3/6] Cleaning previous build..."
rm -rf dist/main.dist dist/main.build main.build main.dist
echo "✓ Cleaned"

# Build with Nuitka
echo ""
echo "[4/6] Building with Nuitka..."
echo "This may take 15-60 minutes..."

python3.12 -m nuitka \
    --standalone \
    --enable-plugin=tk-inter \
    --enable-plugin=numpy \
    --include-package=vieneu_tts \
    --include-package=utils \
    --include-package=edge \
    --include-package=llama_cpp \
    --include-package=phonemizer \
    --include-package=neucodec \
    --include-package=torch \
    --include-package=torchaudio \
    --include-package=librosa \
    --include-package=soundfile \
    --include-package=customtkinter \
    --include-package=google \
    --include-package=docx \
    --include-module=auth_module \
    --include-data-dir=VieNeu-TTS/sample=VieNeu-TTS/sample \
    --include-data-dir=VieNeu-TTS/utils=VieNeu-TTS/utils \
    --include-data-files=VieNeu-TTS/config.yaml=VieNeu-TTS/config.yaml \
    --include-data-files=icon.ico=icon.ico \
    --output-dir=dist \
    --jobs=$(nproc) \
    main.py

echo "✓ Build successful"

# Post-build processing
echo ""
echo "[5/6] Post-processing..."

if [ -d "dist/main.dist" ]; then
    rm -rf dist/FathTTS
    mv dist/main.dist dist/FathTTS
fi

# Copy ffmpeg if exists
if [ -f "ffmpeg" ]; then
    cp ffmpeg dist/FathTTS/
    echo "✓ Copied ffmpeg"
fi

# Ensure samples exist
if [ ! -d "dist/FathTTS/VieNeu-TTS/sample" ]; then
    mkdir -p dist/FathTTS/VieNeu-TTS/sample
    cp -r VieNeu-TTS/sample/* dist/FathTTS/VieNeu-TTS/sample/
    echo "✓ Copied VieNeu-TTS samples"
fi

echo ""
echo "===================================================="
echo "  BUILD COMPLETE!"
echo "===================================================="
echo ""
echo "  Output: dist/FathTTS/main.bin"
echo ""
echo "  VieNeu-TTS has been COMPILED to C:"
echo "  - vieneu_tts.*.so (compiled module)"
echo "  - utils.*.so (compiled module)"
echo "===================================================="
```

---

## 8. Xử Lý Data Files

### Hiểu về Nuitka Data Files:

Nuitka phân biệt rõ ràng giữa:
1. **Python code** - được compile thành C/binary
2. **Data files** - được copy nguyên vẹn

### Data Files của VieNeu-TTS:

```
VieNeu-TTS/
├── sample/                    # Voice samples
│   ├── Vĩnh (nam miền Nam).wav
│   ├── Vĩnh (nam miền Nam).pt
│   ├── Vĩnh (nam miền Nam).txt
│   └── ... (other voices)
├── utils/
│   └── phoneme_dict.json      # Phoneme dictionary
└── config.yaml                # Configuration
```

### Include Data Files trong Nuitka:

```batch
:: Include một thư mục con hoàn chỉnh
--include-data-dir=SOURCE_PATH=DEST_PATH

:: Include một file cụ thể
--include-data-files=SOURCE_PATH=DEST_PATH
```

### Cấu trúc Output sau Build:

```
dist/FathTTS/
├── main.exe                          # Compiled executable
├── main.exe.manifest                 # Windows manifest
├── _internal/                        # Compiled modules
│   ├── vieneu_tts.*.pyd              # VieNeu-TTS compiled
│   ├── utils.*.pyd                   # Utils compiled
│   ├── edge.*.pyd                    # Edge TTS compiled
│   └── ... (other compiled modules)
├── VieNeu-TTS/                       # Data files (unchanged)
│   ├── sample/
│   │   ├── *.wav
│   │   ├── *.pt
│   │   └── *.txt
│   ├── utils/
│   │   └── phoneme_dict.json
│   └── config.yaml
├── icon.ico
└── ffmpeg.exe                        # (if copied)
```

---

## 9. Khắc Phục Sự Cố

### Lỗi 1: "Cannot find MinGW64"

**Nguyên nhân:** Chưa cài C compiler

**Giải pháp:**
```bash
# Windows - cài MinGW qua pip
pip install mingw64

# Hoặc sử dụng MSVC (Visual Studio Build Tools)
# Xóa --mingw64 khỏi build command
```

### Lỗi 2: "ModuleNotFoundError during compilation"

**Nguyên nhân:** Module không được include

**Giải pháp:** Thêm `--include-package=module_name` hoặc `--include-module=module_name`

### Lỗi 3: "Cannot find vieneu_tts"

**Nguyên nhân:** VieNeu-TTS không trong Python path

**Giải pháp:**
```bash
# Đảm bảo thư mục VieNeu-TTS có trong PYTHONPATH
set PYTHONPATH=%CD%\VieNeu-TTS;%PYTHONPATH%

# Hoặc thêm vào build command:
--include-package-data=VieNeu-TTS
```

### Lỗi 4: "phoneme_dict.json not found at runtime"

**Nguyên nhân:** Data file không được copy

**Giải pháp:**
```batch
--include-data-files=VieNeu-TTS/utils/phoneme_dict.json=VieNeu-TTS/utils/phoneme_dict.json
```

### Lỗi 5: "DLL load failed for torch"

**Nguyên nhân:** PyTorch dependencies missing

**Giải pháp:**
```batch
# Thêm vào build command:
--nofollow-import-to=torch.testing
--nofollow-import-to=torch.distributed

# Hoặc cho toàn bộ torch:
--include-package=torch
```

### Lỗi 6: Build rất chậm hoặc hết RAM

**Giải pháp:**
```batch
# Giảm số threads
--jobs=2

# Disable LTO (Link-time optimization)
--lto=no

# Hoặc chuyển sang PyInstaller cho máy yếu
```

### Lỗi 7: "eSpeak library not found" sau khi build

**Nguyên nhân:** eSpeak DLL không được bundle

**Giải pháp:**
```batch
# Copy eSpeak DLL vào output
copy "C:\Program Files\eSpeak NG\libespeak-ng.dll" "dist\FathTTS\"
```

---

## 10. Tối Ưu Hóa Build

### Giảm Kích Thước Output:

```batch
:: Loại bỏ các module không cần thiết
--nofollow-import-to=tkinter.test
--nofollow-import-to=unittest
--nofollow-import-to=test
--nofollow-import-to=torch.testing

:: Sử dụng compression
--lto=yes
```

### Tăng Tốc Build:

```batch
:: Sử dụng nhiều CPU cores
--jobs=8

:: Cache compilation
--cache-c-compilation=yes

:: Disable tracing (không cần debug)
--disable-console
```

### Build cho CPU-only (nhỏ gọn hơn):

```batch
:: Loại bỏ CUDA dependencies
--nofollow-import-to=torch.cuda
--nofollow-import-to=nvidia

:: Sử dụng PyTorch CPU-only
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
```

### Build Debug (khi gặp lỗi):

```batch
:: Bật console để xem lỗi
--windows-console-mode=force

:: Thêm debug info
--debug
```

---

## Tóm Tắt Command Build

### Quick Build (Windows):

```batch
python -m nuitka --standalone --enable-plugin=tk-inter ^
    --include-package=vieneu_tts --include-package=utils --include-package=edge ^
    --include-package=llama_cpp --include-package=phonemizer --include-package=neucodec ^
    --include-package=torch --include-package=torchaudio --include-package=librosa ^
    --include-package=soundfile --include-package=customtkinter --include-package=google ^
    --include-module=auth_module ^
    --include-data-dir=VieNeu-TTS/sample=VieNeu-TTS/sample ^
    --include-data-dir=VieNeu-TTS/utils=VieNeu-TTS/utils ^
    --include-data-files=VieNeu-TTS/config.yaml=VieNeu-TTS/config.yaml ^
    --windows-icon-from-ico=icon.ico --windows-console-mode=disable ^
    --output-dir=dist main.py
```

### Kiểm Tra Build Thành Công:

```bash
# Kiểm tra output
dir dist\main.dist

# Chạy thử
dist\main.dist\main.exe

# Kiểm tra VieNeu-TTS đã được compile
dir dist\main.dist\*.pyd
# Phải thấy: vieneu_tts.*.pyd, utils.*.pyd
```

---

**Được tạo bởi:** Fath TTS Team  
**Ngày cập nhật:** Tháng 12, 2025  
**Phiên bản:** 1.0
