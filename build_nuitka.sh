#!/bin/bash
set -e

echo "===================================================="
echo "  FathTTS Nuitka Build Script (Linux)"
echo "  Build với VieNeu-TTS Compiled to C"
echo "===================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ===========================
# 1. Check prerequisites
# ===========================
echo "[1/6] Kiểm tra môi trường..."

# Check Python version
if ! python3.12 --version &> /dev/null; then
    echo -e "${RED}[ERROR] Python 3.12 is required!${NC}"
    echo "Install with: sudo apt install python3.12 python3.12-venv python3.12-dev"
    exit 1
fi
echo -e "      ${GREEN}✓${NC} Python 3.12 OK"

# Check/Install Nuitka
if ! python3.12 -m nuitka --version &> /dev/null; then
    echo -e "${YELLOW}[INFO] Installing Nuitka...${NC}"
    pip install nuitka ordered-set zstandard
fi
echo -e "      ${GREEN}✓${NC} Nuitka OK"

# Check GCC
if ! gcc --version &> /dev/null; then
    echo -e "${YELLOW}[INFO] Installing build-essential...${NC}"
    sudo apt install build-essential -y
fi
echo -e "      ${GREEN}✓${NC} GCC OK"

# Check eSpeak
if ! espeak-ng --version &> /dev/null; then
    echo -e "${YELLOW}[INFO] Installing eSpeak NG...${NC}"
    sudo apt install espeak-ng -y
fi
echo -e "      ${GREEN}✓${NC} eSpeak NG OK"

# Check VieNeu-TTS
if [ ! -d "VieNeu-TTS" ]; then
    echo -e "${RED}[ERROR] VieNeu-TTS directory not found!${NC}"
    echo "Clone with: git clone https://github.com/pnnbao97/VieNeu-TTS.git"
    exit 1
fi
echo -e "      ${GREEN}✓${NC} VieNeu-TTS OK"
echo ""

# ===========================
# 2. Install dependencies
# ===========================
echo "[2/6] Cài đặt dependencies..."

# Upgrade pip
python3.12 -m pip install --upgrade pip -q

# Nuitka dependencies
echo "      - Nuitka dependencies..."
pip install ordered-set zstandard -q

# llama-cpp-python (CPU)
echo "      - llama-cpp-python (CPU)..."
pip install llama-cpp-python --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cpu -q 2>/dev/null || \
    CMAKE_ARGS="-DLLAMA_BLAS=OFF -DLLAMA_CUBLAS=OFF" pip install llama-cpp-python --no-cache-dir --force-reinstall -q

# PyTorch CPU
echo "      - PyTorch (CPU)..."
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu -q

# VieNeu-TTS dependencies
echo "      - VieNeu-TTS dependencies..."
pip install phonemizer neucodec librosa soundfile onnxruntime -q

# GUI dependencies
echo "      - GUI dependencies..."
pip install customtkinter python-docx google-genai requests -q

# Linux audio libraries
echo "      - Audio libraries..."
sudo apt install portaudio19-dev python3-pyaudio -y 2>/dev/null || true
pip install pyaudio -q 2>/dev/null || true

echo -e "      ${GREEN}✓${NC} Dependencies OK"
echo ""

# ===========================
# 3. Check imports
# ===========================
echo "[3/6] Kiểm tra imports..."

python3.12 -c "from llama_cpp import Llama" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR] llama-cpp-python không hoạt động!${NC}"
    exit 1
fi
echo -e "      ${GREEN}✓${NC} llama-cpp-python OK"

python3.12 -c "import sys; sys.path.insert(0, 'VieNeu-TTS'); from vieneu_tts import VieNeuTTS" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR] VieNeu-TTS import thất bại!${NC}"
    exit 1
fi
echo -e "      ${GREEN}✓${NC} VieNeu-TTS OK"

python3.12 -c "import customtkinter" 2>/dev/null
if [ $? -ne 0 ]; then
    echo -e "${YELLOW}[WARNING] customtkinter chưa được cài${NC}"
    pip install customtkinter -q
fi
echo -e "      ${GREEN}✓${NC} customtkinter OK"
echo ""

# ===========================
# 4. Clean previous build
# ===========================
echo "[4/6] Dọn dẹp build cũ..."

rm -rf dist/main.dist dist/main.build dist/FathTTS main.build main.dist

echo -e "      ${GREEN}✓${NC} Cleaned"
echo ""

# ===========================
# 5. Build with Nuitka
# ===========================
echo "[5/6] Building với Nuitka..."
echo "      Quá trình này có thể mất 15-60 phút..."
echo "      VieNeu-TTS sẽ được COMPILE thành C (không chỉ import)"
echo ""

# Set PYTHONPATH to include VieNeu-TTS
export PYTHONPATH="$(pwd)/VieNeu-TTS:$PYTHONPATH"

# Get number of CPU cores
JOBS=$(nproc)

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
    --include-package=requests \
    --include-module=auth_module \
    --include-data-dir=VieNeu-TTS/sample=VieNeu-TTS/sample \
    --include-data-dir=VieNeu-TTS/utils=VieNeu-TTS/utils \
    --include-data-files=VieNeu-TTS/config.yaml=VieNeu-TTS/config.yaml \
    --include-data-files=icon.ico=icon.ico \
    --output-dir=dist \
    --jobs=$JOBS \
    main.py

if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR] Build thất bại!${NC}"
    exit 1
fi

echo -e "      ${GREEN}✓${NC} Build thành công"
echo ""

# ===========================
# 6. Post-build processing
# ===========================
echo "[6/6] Xử lý sau build..."

# Rename output folder
if [ -d "dist/main.dist" ]; then
    rm -rf dist/FathTTS
    mv dist/main.dist dist/FathTTS
    echo -e "      ${GREEN}✓${NC} Renamed to FathTTS"
fi

# Copy ffmpeg if exists
if [ -f "ffmpeg" ]; then
    cp ffmpeg dist/FathTTS/
    echo -e "      ${GREEN}✓${NC} Copied ffmpeg"
fi

# Ensure VieNeu-TTS directory structure exists
mkdir -p dist/FathTTS/VieNeu-TTS/sample
mkdir -p dist/FathTTS/VieNeu-TTS/utils

# Copy sample files
cp -r VieNeu-TTS/sample/* dist/FathTTS/VieNeu-TTS/sample/ 2>/dev/null || true
echo -e "      ${GREEN}✓${NC} Copied VieNeu-TTS samples"

# Copy phoneme_dict.json
cp VieNeu-TTS/utils/phoneme_dict.json dist/FathTTS/VieNeu-TTS/utils/ 2>/dev/null || true
echo -e "      ${GREEN}✓${NC} Copied phoneme_dict.json"

# Copy config.yaml
cp VieNeu-TTS/config.yaml dist/FathTTS/VieNeu-TTS/ 2>/dev/null || true
echo -e "      ${GREEN}✓${NC} Copied config.yaml"

# Make executable
chmod +x dist/FathTTS/main.bin 2>/dev/null || true

echo ""
echo "===================================================="
echo "  BUILD HOÀN TẤT!"
echo "===================================================="
echo ""
echo "  Output: dist/FathTTS/main.bin"
echo ""
echo "  VieNeu-TTS đã được COMPILE thành C:"
echo "  - vieneu_tts module (compiled .so)"
echo "  - utils module (compiled .so)"
echo "  - Các module khác cũng đã được compile"
echo ""
echo "  Data files đã được copy:"
echo "  - dist/FathTTS/VieNeu-TTS/sample/ (voice samples)"
echo "  - dist/FathTTS/VieNeu-TTS/utils/phoneme_dict.json"
echo "  - dist/FathTTS/VieNeu-TTS/config.yaml"
echo ""
echo "  Lưu ý quan trọng:"
echo "  - Model GGUF sẽ tự động download lần đầu chạy"
echo "  - Cần có eSpeak NG trên máy người dùng"
echo ""
echo "  Để chạy: ./dist/FathTTS/main.bin"
echo "===================================================="
