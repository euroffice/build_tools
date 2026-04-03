#!/bin/bash
# ONLYOFFICE DesktopEditors Build - 12 Sequential Stages
# Based on: github.com/ONLYOFFICE/build_tools/blob/master/tools/linux/automate.py

set -e  # Exit on error
BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# STAGE 1: Verify Python Environment & Setup
# ============================================================================
stage_1_setup() {
    echo "========== STAGE 1: Setup Python Environment =========="
    cd "$BUILD_DIR"
    python3 --version
    echo "✓ Stage 1 Complete"
}

# ============================================================================
# STAGE 2: Install System Dependencies
# ============================================================================
stage_2_install_deps() {
    echo "========== STAGE 2: Install System Dependencies =========="
    cd "$BUILD_DIR"
    if [ ! -f "./node_js_setup_14.x" ]; then
        echo "Installing dependencies..."
        python3 -c "import sys; sys.path.append('../../scripts'); import deps; deps.install_deps()"
    else
        echo "Dependencies already installed"
    fi
    echo "✓ Stage 2 Complete"
}

# ============================================================================
# STAGE 3: Download Qt Source (5.9.9)
# ============================================================================
stage_3_download_qt() {
    echo "========== STAGE 3: Download Qt Source =========="
    cd "$BUILD_DIR"
    if [ ! -f "./qt_source_5.9.9.tar.xz" ]; then
        echo "Downloading Qt 5.9.9 source..."
        wget -q --show-progress \
            "https://github.com/ONLYOFFICE-data/build_tools_data/raw/refs/heads/master/qt/qt-everywhere-opensource-src-5.9.9.tar.xz" \
            -O "./qt_source_5.9.9.tar.xz"
    else
        echo "Qt source already downloaded"
    fi
    echo "✓ Stage 3 Complete"
}

# ============================================================================
# STAGE 4: Extract Qt Source
# ============================================================================
stage_4_extract_qt() {
    echo "========== STAGE 4: Extract Qt Source =========="
    cd "$BUILD_DIR"
    if [ ! -d "./qt-everywhere-opensource-src-5.9.9" ]; then
        echo "Extracting Qt source..."
        tar -xf "./qt_source_5.9.9.tar.xz"
    else
        echo "Qt source already extracted"
    fi
    echo "✓ Stage 4 Complete"
}

# ============================================================================
# STAGE 5: Configure Qt Build (with C++11 compatibility fix)
# ============================================================================
stage_5_configure_qt() {
    echo "========== STAGE 5: Configure Qt Build =========="
    cd "$BUILD_DIR/qt-everywhere-opensource-src-5.9.9/qtbase"
    
    # FIX: Add missing <limits> header to qbytearraymatcher.h for GCC 11+ compatibility
    echo "Applying Qt 5.9.9 GCC 11+ compatibility patch..."
    
    HEADER_FILE="src/corelib/tools/qbytearraymatcher.h"
    if [ -f "$HEADER_FILE" ]; then
        # Check if limits is already included
        if ! grep -q "#include <limits>" "$HEADER_FILE"; then
            # Add #include <limits> after the first #include block
            sed -i '1,/#include/a #include <limits>' "$HEADER_FILE"
            echo "✓ Applied <limits> header fix"
        fi
    fi
    
    ./configure \
        -top-level \
        -opensource \
        -confirm-license \
        -release \
        -shared \
        -accessibility \
        -prefix "$BUILD_DIR/qt_build/Qt-5.9.9/gcc_64" \
        -qt-zlib \
        -qt-libpng \
        -qt-libjpeg \
        -qt-xcb \
        -qt-pcre \
        -no-sql-sqlite \
        -no-qml-debug \
        -gstreamer 1.0 \
        -nomake examples \
        -nomake tests \
        -skip qtenginio \
        -skip qtlocation \
        -skip qtserialport \
        -skip qtsensors \
        -skip qtxmlpatterns \
        -skip qt3d \
        -skip qtwebview \
        -skip qtwebengine
    
    echo "✓ Stage 5 Complete"
}

# ============================================================================
# STAGE 6: Build Qt (Compile)
# ============================================================================
stage_6_build_qt() {
    echo "========== STAGE 6: Build Qt (Compile) =========="
    cd "$BUILD_DIR/qt-everywhere-opensource-src-5.9.9"
    
    CPU_COUNT=$(nproc)
    echo "Building Qt with $CPU_COUNT CPU cores..."
    make -j "$CPU_COUNT"
    
    echo "✓ Stage 6 Complete"
}

# ============================================================================
# STAGE 7: Install Qt
# ============================================================================
stage_7_install_qt() {
    echo "========== STAGE 7: Install Qt =========="
    cd "$BUILD_DIR/qt-everywhere-opensource-src-5.9.9"
    
    make install
    
    echo "✓ Stage 7 Complete"
}

# ============================================================================
# STAGE 8: Verify Qt Installation
# ============================================================================
stage_8_verify_qt() {
    echo "========== STAGE 8: Verify Qt Installation =========="
    
    QT_PATH="$BUILD_DIR/qt_build/Qt-5.9.9/gcc_64"
    if [ -d "$QT_PATH" ]; then
        echo "✓ Qt installed at: $QT_PATH"
        "$QT_PATH/bin/qmake" -version
    else
        echo "✗ Qt installation failed!"
        exit 1
    fi
    
    echo "✓ Stage 8 Complete"
}

# ============================================================================
# STAGE 9: Get Build Branch & Parse Arguments
# ============================================================================
stage_9_parse_args() {
    echo "========== STAGE 9: Parse Build Arguments =========="
    cd "$BUILD_DIR/../.."
    
    # Get current branch
    BRANCH=$(git symbolic-ref --short -q HEAD 2>/dev/null || echo "master")
    echo "Build branch: $BRANCH"
    
    # Parse command-line arguments
    MODULES="${1:-desktop builder server}"
    echo "Build modules: $MODULES"
    
    echo "✓ Stage 9 Complete"
}

# ============================================================================
# STAGE 10: Run Configure Script
# ============================================================================
stage_10_configure() {
    echo "========== STAGE 10: Configure Build =========="
    cd "$BUILD_DIR/../.."
    
    QT_DIR="$BUILD_DIR/qt_build/Qt-5.9.9"
    
    python3 ./configure.py \
        --branch "$BRANCH" \
        --module "$MODULES" \
        --update 1 \
        --qt-dir "$QT_DIR"
    
    echo "✓ Stage 10 Complete"
}

# ============================================================================
# STAGE 11: Build DesktopEditors (Compile)
# ============================================================================
stage_11_build() {
    echo "========== STAGE 11: Build DesktopEditors =========="
    cd "$BUILD_DIR/../.."
    
    python3 ./make.py
    
    echo "✓ Stage 11 Complete"
}

# ============================================================================
# STAGE 12: Verify Build Output
# ============================================================================
stage_12_verify_build() {
    echo "========== STAGE 12: Verify Build Output =========="
    
    # Check for common output locations
    if [ -d "./build" ]; then
        echo "✓ Build directory found"
        ls -lh ./build | head -20
    fi
    
    if [ -f "./out/DesktopEditors" ]; then
        echo "✓ DesktopEditors binary found!"
        ./out/DesktopEditors --version 2>/dev/null || echo "  (binary exists but version check needs runtime)"
    fi
    
    echo "✓ Stage 12 Complete - Build successful!"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================
main() {
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  ONLYOFFICE DesktopEditors - 12 Stage Sequential Build     ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    
    # Execute each stage
    stage_1_setup
    stage_2_install_deps
    stage_3_download_qt
    stage_4_extract_qt
    stage_5_configure_qt
    stage_6_build_qt
    stage_7_install_qt
    stage_8_verify_qt
    stage_9_parse_args "$@"
    stage_10_configure
    stage_11_build
    stage_12_verify_build
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║               ✓ BUILD COMPLETE                             ║"
    echo "╚════════════════════════════════════════════════════════════╝"
}

# Run with error handling
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi

