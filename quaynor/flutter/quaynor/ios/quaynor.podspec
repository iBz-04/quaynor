# Flutter iOS — resolves vendored quaynor_flutter.xcframework via Dart helper.
require 'yaml'

pubspec_path = File.join(__dir__, '..', 'pubspec.yaml')
pubspec = YAML.load_file(pubspec_path)
plugin_version = pubspec['version'].to_s

framework_name = "quaynor_flutter.xcframework"

script_path = File.join(__dir__, '..', 'tool', 'resolve_binary.dart')
cache_dir = File.join(__dir__, '..', '.dart_tool', 'quaynor_cache')

resolve_output = `dart run "#{script_path}" --platform=ios --build-type=release --cache-dir="#{cache_dir}" 2>&1`
resolve_status = $?.exitstatus

if resolve_status != 0
  raise "Error: Failed to resolve Quaynor xcframework for iOS:\n#{resolve_output}\n" \
        "You can manually set QUAYNOR_FLUTTER_XCFRAMEWORK_PATH to point to your xcframework."
end

xcframework_path = resolve_output.strip.split("\n").last

unless File.exist?(xcframework_path)
  raise "Error: Resolved xcframework path does not exist: #{xcframework_path}"
end

frameworks_dir = File.join(__dir__, 'Frameworks')
%x(mkdir -p "#{frameworks_dir}"
cd "#{frameworks_dir}"
if [ -d "#{framework_name}" ]; then rm -rf "#{framework_name}"; fi
cp -R "#{xcframework_path}" "./#{framework_name}"
)

Pod::Spec.new do |s|
  s.name             = 'quaynor'
  s.version          = plugin_version
  s.summary          = pubspec['description']
  s.description      = pubspec['description']
  s.homepage         = pubspec['homepage'] || pubspec['repository']
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Quaynor' => 'https://quaynor.ooo' }

  s.source           = { :path => '.' }
  s.libraries = 'c++'
  s.frameworks = 'Accelerate'

  s.dependency 'Flutter'

  s.platform = :ios, '13.0'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64'
  }
  s.user_target_xcconfig = {
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386 x86_64'
  }
  s.swift_version = '5.0'

  s.vendored_frameworks = "Frameworks/#{framework_name}"
end
