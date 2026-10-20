# Generates WidgetScreens.xcodeproj (a host app and a UI test that drives
# SpringBoard) into the folder given, with the xcodeproj gem that comes with
# CocoaPods. Run by tool/widget_screens.sh.
require 'xcodeproj'
src = File.expand_path(__dir__)
out = ARGV[0] or abort 'Usage: make.rb <out dir>'
proj = Xcodeproj::Project.new("#{out}/WidgetScreens.xcodeproj")
host = proj.new_target(:application, 'Host', :ios, '17.0', nil, :swift)
host.add_file_references([proj.main_group.new_group('Host', "#{src}/Host").new_reference('HostApp.swift')])
tests = proj.new_target(:ui_test_bundle, 'WidgetScreens', :ios, '17.0', nil, :swift)
tests.add_file_references([proj.main_group.new_group('WidgetScreens', "#{src}/WidgetScreens").new_reference('WidgetScreens.swift')])
tests.add_dependency(host)
[host, tests].each do |target|
  target.build_configurations.each do |config|
    s = config.build_settings
    s['PRODUCT_BUNDLE_IDENTIFIER'] = target == host ? 'com.paulblake.momentum.screens.host' : 'com.paulblake.momentum.screens.tests'
    s['GENERATE_INFOPLIST_FILE'] = 'YES'
    s['CODE_SIGNING_ALLOWED'] = 'NO'
    s['SWIFT_VERSION'] = '5.0'
    s['TEST_TARGET_NAME'] = 'Host' if target == tests
    s['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES' if target == host
  end
end
proj.save
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(host)
scheme.add_test_target(tests)
scheme.set_launch_target(host)
scheme.save_as("#{out}/WidgetScreens.xcodeproj", 'WidgetScreens', true)
