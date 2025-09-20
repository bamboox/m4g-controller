#!/bin/bash

# 检查gradle wrapper jar是否存在，如果不存在则下载
if [ ! -f "gradle/wrapper/gradle-wrapper.jar" ]; then
    echo "Downloading gradle-wrapper.jar..."
    mkdir -p gradle/wrapper
    curl -L -o gradle/wrapper/gradle-wrapper.jar https://raw.githubusercontent.com/gradle/gradle/v8.7/gradle/wrapper/gradle-wrapper.jar
    echo "gradle-wrapper.jar downloaded successfully"
else
    echo "gradle-wrapper.jar already exists"
fi

# 给gradlew添加执行权限
chmod +x gradlew

# 验证gradle.properties配置
if [ ! -f "gradle.properties" ]; then
    echo "Error: gradle.properties file not found!"
    exit 1
fi

if ! grep -q "android.useAndroidX=true" gradle.properties; then
    echo "Error: android.useAndroidX=true not found in gradle.properties!"
    exit 1
fi

echo "Gradle wrapper setup completed"