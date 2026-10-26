$ErrorActionPreference = "Stop"
$files = @(
  "README_MIGRATIONS.md",
  "README_CONTRACT_TESTS.md",
  "README_RELEASE_PIPELINE.md",
  "README_BASELINE.md",
  "README_ARCHITECTURE.md",
  "README_TEST_DATASETS.md",
  "README_ARCH_04_TEST_SUPPORT_FIX.md",
  "README_ARCH04_MAIN_PATCH.md"
)
foreach ($file in $files) {
  if (Test-Path $file) {
    Remove-Item $file -Force
    Write-Host "Removed $file"
  }
}
Write-Host "Root README cleanup complete. README.md is preserved."
