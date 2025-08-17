#!/bin/bash
set -e

# ==== НАСТРОЙКИ ====
PROJECT_NAME="GitServer"
PLATFORM="win"
VERSION_FILE="VERSION"
BUILD_FILE="build_number.txt"
HISTORY_FILE="build_history.log"

# ==== ПОЛУЧАЕМ ДАННЫЕ ====
# Версия проекта
if [[ -f "$VERSION_FILE" ]]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "0.1.0" > "$VERSION_FILE"
    VERSION="0.1.0"
fi

# Номер билда
if [[ -f "$BUILD_FILE" ]]; then
    BUILD=$(cat "$BUILD_FILE")
else
    BUILD=0
fi
BUILD=$((BUILD + 1))
echo $BUILD > "$BUILD_FILE"

# Git данные
BRANCH=$(git rev-parse --abbrev-ref HEAD)
COMMIT_HASH=$(git rev-parse --short HEAD)

# ==== ФОРМИРУЕМ ИМЯ БИЛДА ====
BUILD_NAME="${PROJECT_NAME}_${PLATFORM}_v${VERSION}+${BUILD}-g${COMMIT_HASH}"
TAG_NAME="v${VERSION}+${BUILD}"

# ==== ЛОГИ ====
DATE=$(date +"%Y-%m-%d %H:%M:%S")
echo "[$DATE] $BUILD_NAME (branch: $BRANCH, commit: $COMMIT_HASH)" >> "$HISTORY_FILE"

# ==== СБОРКА (пример Unreal Engine, можно адаптировать) ====
echo ">>> Собираем проект: $BUILD_NAME"
# Пример: вызов UnrealBuildTool
# /path/to/UnrealBuildTool "$PROJECT_NAME" $PLATFORM Development
pkg -t node18-"$PLATFORM"-x64 index.js

# ==== СОЗДАНИЕ GIT-ТЕГА ====
if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
    echo "⚠️  Тег $TAG_NAME уже существует, пропускаем."
else
    git tag -a "$TAG_NAME" -m "Build $BUILD_NAME on branch $BRANCH at $DATE"
    echo "✅ Создан git-тег: $TAG_NAME"
    
    # Если хочешь сразу пушить в удалённый репозиторий — раскомментируй:
    # git push origin "$TAG_NAME"
fi

# ==== РЕЗУЛЬТАТ ====
echo "Билд успешно завершён!"
echo "Имя билда: $BUILD_NAME"
echo "Git-тег:   $TAG_NAME"
