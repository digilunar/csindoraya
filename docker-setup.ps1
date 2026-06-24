#!/usr/bin/env pwsh
# Chatwoot Docker Setup Script
# Run this from PowerShell in Windows

$ErrorActionPreference = "Stop"

Write-Host "=== Chatwoot Docker Setup ===" -ForegroundColor Cyan
Write-Host ""

# Check Docker
Write-Host "Checking Docker..." -ForegroundColor Yellow
try {
    docker --version
    Write-Host "OK Docker found" -ForegroundColor Green
} catch {
    Write-Host "ERROR Docker not found. Please install Docker Desktop first." -ForegroundColor Red
    Write-Host "Download from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
}

# Check Docker is running
Write-Host "Checking if Docker is running..." -ForegroundColor Yellow
try {
    docker ps | Out-Null
    Write-Host "OK Docker is running" -ForegroundColor Green
} catch {
    Write-Host "ERROR Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    exit 1
}

# Navigate to project directory
$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ProjectDir

Write-Host ""
Write-Host "=== Building Docker Images ===" -ForegroundColor Cyan
Write-Host "This will take 10-30 minutes depending on your internet/CPU..." -ForegroundColor Yellow
Write-Host ""

# Build all images in correct order
Write-Host "Building all images (this creates base, rails, vite, sidekiq)..." -ForegroundColor Yellow
docker-compose build
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR Failed to build images" -ForegroundColor Red
    exit 1
}
Write-Host "OK All images built" -ForegroundColor Green

Write-Host ""
Write-Host "=== Setup Database ===" -ForegroundColor Cyan

# Start postgres and redis first
Write-Host "Starting PostgreSQL and Redis..." -ForegroundColor Yellow
docker-compose up -d postgres redis
Start-Sleep -Seconds 5

# Run database setup
Write-Host "Creating database..." -ForegroundColor Yellow
docker-compose run --rm rails bundle exec rails db:create
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR Failed to create database" -ForegroundColor Red
    exit 1
}

Write-Host "Running migrations..." -ForegroundColor Yellow
docker-compose run --rm rails bundle exec rails db:migrate
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR Failed to run migrations" -ForegroundColor Red
    exit 1
}

Write-Host "OK Database setup complete" -ForegroundColor Green

Write-Host ""
Write-Host "=== Starting Chatwoot ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starting all services..." -ForegroundColor Yellow
docker-compose up

Write-Host ""
Write-Host "=== Chatwoot is running! ===" -ForegroundColor Green
Write-Host "Dashboard: http://localhost:3000" -ForegroundColor Cyan
Write-Host "Mailhog: http://localhost:8025" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press Ctrl+C to stop" -ForegroundColor Yellow
