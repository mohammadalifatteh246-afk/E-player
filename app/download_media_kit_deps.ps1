$basePath = "d:\E-player\app\build\media_kit_libs_android_video\v1.1.7\"
New-Item -Path $basePath -ItemType Directory -Force | Out-Null
$urls = @{
    "media_kit_libs_android_video-v1.1.7-arm64-v8a.jar" = "https://github.com/media-kit/media-kit/releases/download/media_kit_libs_android_video-v1.1.7/media_kit_libs_android_video-arm64-v8a.jar"
    "media_kit_libs_android_video-v1.1.7-armeabi-v7a.jar" = "https://github.com/media-kit/media-kit/releases/download/media_kit_libs_android_video-v1.1.7/media_kit_libs_android_video-armeabi-v7a.jar"
    "media_kit_libs_android_video-v1.1.7-x86_64.jar" = "https://github.com/media-kit/media-kit/releases/download/media_kit_libs_android_video-v1.1.7/media_kit_libs_android_video-x86_64.jar"
}
foreach ($item in $urls.GetEnumerator()) {
    $outPath = Join-Path $basePath $item.Key
    Write-Host "Downloading $($item.Key)..."
    Invoke-WebRequest -Uri $item.Value -OutFile $outPath
}
Write-Host "Done!"
