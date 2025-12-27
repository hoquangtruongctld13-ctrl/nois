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
    echo        Vui lòng cài Python 3.12.x từ https://www.python.org/downloads/
    pause
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
    echo          Sau đó thêm "C:\Program Files\eSpeak NG" vào PATH
    echo.
    pause
)
echo       ✓ eSpeak NG check complete

:: Check VieNeu-TTS
if not exist "VieNeu-TTS" (
    echo [ERROR] Thư mục VieNeu-TTS không tồn tại!
    echo        Vui lòng clone VieNeu-TTS vào thư mục project:
    echo        git clone https://github.com/pnnbao97/VieNeu-TTS.git
    pause
    exit /b 1
)
echo       ✓ VieNeu-TTS OK
echo.

:: ===========================
:: 2. Cài đặt dependencies
:: ===========================
echo [2/6] Cài đặt dependencies...

:: Upgrade pip
python -m pip install --upgrade pip >nul 2>&1

:: Nuitka dependencies
echo       - Nuitka dependencies...
pip install ordered-set zstandard >nul 2>&1

:: llama-cpp-python (CPU)
echo       - llama-cpp-python (CPU)...
pip install llama-cpp-python --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Không thể cài llama-cpp-python từ wheel.
    echo          Thử build từ source...
    :: Set CMAKE_ARGS in current environment then run pip
    set "CMAKE_ARGS=-DLLAMA_BLAS=OFF -DLLAMA_CUBLAS=OFF"
    pip install llama-cpp-python --no-cache-dir --force-reinstall >nul 2>&1
)

:: PyTorch CPU
echo       - PyTorch (CPU)...
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu >nul 2>&1

:: VieNeu-TTS dependencies
echo       - VieNeu-TTS dependencies...
pip install phonemizer neucodec librosa soundfile onnxruntime >nul 2>&1

:: GUI dependencies
echo       - GUI dependencies...
pip install customtkinter python-docx google-genai requests pyaudio >nul 2>&1

echo       ✓ Dependencies OK
echo.

:: ===========================
:: 3. Kiểm tra imports
:: ===========================
echo [3/6] Kiểm tra imports...

python -c "from llama_cpp import Llama" 2>nul
if errorlevel 1 (
    echo [ERROR] llama-cpp-python không hoạt động!
    echo        Xem hướng dẫn tại BUILD_GUIDE.md
    pause
    exit /b 1
)
echo       ✓ llama-cpp-python OK

python -c "import sys; sys.path.insert(0, 'VieNeu-TTS'); from vieneu_tts import VieNeuTTS" 2>nul
if errorlevel 1 (
    echo [ERROR] VieNeu-TTS import thất bại!
    echo        Kiểm tra thư mục VieNeu-TTS
    pause
    exit /b 1
)
echo       ✓ VieNeu-TTS OK

python -c "import customtkinter" 2>nul
if errorlevel 1 (
    echo [WARNING] customtkinter chưa được cài
    pip install customtkinter >nul 2>&1
)
echo       ✓ customtkinter OK
echo.

:: ===========================
:: 4. Clean previous build
:: ===========================
echo [4/6] Dọn dẹp build cũ...

if exist "dist\main.dist" rmdir /s /q "dist\main.dist"
if exist "dist\main.build" rmdir /s /q "dist\main.build"
if exist "dist\FathTTS" rmdir /s /q "dist\FathTTS"
if exist "main.build" rmdir /s /q "main.build"
if exist "main.dist" rmdir /s /q "main.dist"

echo       ✓ Cleaned
echo.

:: ===========================
:: 5. Build với Nuitka
:: ===========================
echo [5/6] Building với Nuitka...
echo       Quá trình này có thể mất 15-60 phút...
echo       VieNeu-TTS sẽ được COMPILE thành C (không chỉ import)
echo.

:: Set PYTHONPATH to include VieNeu-TTS
set PYTHONPATH=%CD%\VieNeu-TTS;%PYTHONPATH%

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
    --include-package=requests ^
    --include-module=auth_module ^
    --include-data-dir=VieNeu-TTS/sample=VieNeu-TTS/sample ^
    --include-data-dir=VieNeu-TTS/utils=VieNeu-TTS/utils ^
    --include-data-files=VieNeu-TTS/config.yaml=VieNeu-TTS/config.yaml ^
    --include-data-files=icon.ico=icon.ico ^
    --windows-icon-from-ico=icon.ico ^
    --windows-console-mode=disable ^
    --windows-company-name="Fath TTS" ^
    --windows-product-name="Fath TTS Studio" ^
    --windows-file-version=1.0.0.0 ^
    --windows-product-version=1.0.0 ^
    --output-dir=dist ^
    --jobs=4 ^
    main.py

if errorlevel 1 (
    echo [ERROR] Build thất bại!
    echo        Xem log ở trên để biết chi tiết.
    pause
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
    echo       ✓ Renamed to FathTTS
)

:: Copy ffmpeg if exists
if exist "ffmpeg.exe" (
    copy "ffmpeg.exe" "dist\FathTTS\" >nul 2>&1
    echo       ✓ Copied ffmpeg.exe
)

:: Ensure VieNeu-TTS directory structure exists
if not exist "dist\FathTTS\VieNeu-TTS" mkdir "dist\FathTTS\VieNeu-TTS"

:: Ensure sample directory exists with all files
if not exist "dist\FathTTS\VieNeu-TTS\sample" (
    mkdir "dist\FathTTS\VieNeu-TTS\sample"
)
xcopy /E /I /Y "VieNeu-TTS\sample\*" "dist\FathTTS\VieNeu-TTS\sample\" >nul 2>&1
echo       ✓ Copied VieNeu-TTS samples

:: Ensure utils directory exists with phoneme_dict.json
if not exist "dist\FathTTS\VieNeu-TTS\utils" (
    mkdir "dist\FathTTS\VieNeu-TTS\utils"
)
copy "VieNeu-TTS\utils\phoneme_dict.json" "dist\FathTTS\VieNeu-TTS\utils\" >nul 2>&1
echo       ✓ Copied phoneme_dict.json

:: Ensure config.yaml exists
copy "VieNeu-TTS\config.yaml" "dist\FathTTS\VieNeu-TTS\" >nul 2>&1
echo       ✓ Copied config.yaml

:: Copy eSpeak DLL if available
if exist "C:\Program Files\eSpeak NG\libespeak-ng.dll" (
    copy "C:\Program Files\eSpeak NG\libespeak-ng.dll" "dist\FathTTS\" >nul 2>&1
    echo       ✓ Copied libespeak-ng.dll
)

echo.
echo ====================================================
echo   BUILD HOÀN TẤT!
echo ====================================================
echo.
echo   Output: dist\FathTTS\main.exe
echo.
echo   VieNeu-TTS đã được COMPILE thành C:
echo   - vieneu_tts module (compiled)
echo   - utils module (compiled)
echo   - Các module khác cũng đã được compile
echo.
echo   Data files đã được copy:
echo   - dist\FathTTS\VieNeu-TTS\sample\ (voice samples)
echo   - dist\FathTTS\VieNeu-TTS\utils\phoneme_dict.json
echo   - dist\FathTTS\VieNeu-TTS\config.yaml
echo.
echo   Lưu ý quan trọng:
echo   - Model GGUF sẽ tự động download lần đầu chạy
echo   - Cần có eSpeak NG trên máy người dùng
echo   - Copy ffmpeg.exe vào thư mục FathTTS nếu cần ghép audio
echo.
echo   Để chạy: dist\FathTTS\main.exe
echo ====================================================

pause
