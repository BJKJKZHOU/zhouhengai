#!/bin/bash

echo "Testing Smart BaseURL Plugin..."

# 测试本地开发环境
echo "=== Testing Development Environment ==="
JEKYLL_ENV=development bundle exec jekyll build --verbose 2>&1 | grep "SmartBaseURL"

# 测试生产环境（模拟GitHub Pages）
echo -e "\n=== Testing Production Environment ==="
JEKYLL_ENV=production bundle exec jekyll build --verbose 2>&1 | grep "SmartBaseURL"

# 测试GitHub Actions环境
echo -e "\n=== Testing GitHub Actions Environment ==="
GITHUB_ACTIONS=true bundle exec jekyll build --verbose 2>&1 | grep "SmartBaseURL"

echo -e "\nTesting completed."
