platform :macos, '12.0'

use_frameworks!

# 隐藏所有的 pods schemes
install! 'cocoapods',
        :disable_input_output_paths => true,
        :share_schemes_for_development_pods => false

def shared_pods
  pod 'UnrarKit'
  pod 'SSZipArchive'
  pod 'PLzmaSDK'
end

target 'zip' do
  shared_pods
end

target 'zipext' do
 shared_pods
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = '12.0'
      config.build_settings['ENABLE_BITCODE'] = 'NO'
      config.build_settings['CLANG_WARN_DOCUMENTATION_COMMENTS'] = 'NO'
      config.build_settings['SWIFT_VERSION'] = '5.0'
    end
  end
end
