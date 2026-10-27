#!/usr/bin/env ruby
# Adds the Apple Watch app (MomentumWatch) and its complications
# (MomentumWatchWidgets) to ios/Runner.xcodeproj, embedded in the iPhone app
# (docs/design/watch.md). Safe to run again: it does nothing once they exist.
#
# Uses the xcodeproj gem that ships with CocoaPods:
#   GEM_HOME=/opt/homebrew/Cellar/cocoapods/1.17.0/libexec ruby tool/add_watch_targets.rb
require 'xcodeproj'

ROOT = File.expand_path('..', __dir__)
project = Xcodeproj::Project.open(File.join(ROOT, 'ios/Runner.xcodeproj'))

if project.targets.any? { |t| t.name == 'MomentumWatch' }
  puts 'The watch targets are already there.'
  exit 0
end

runner = project.targets.find { |t| t.name == 'Runner' }
widgets = project.targets.find { |t| t.name == 'MomentumWidgets' }
TEAM = '9EWP23T2HE'
WATCH_OS = '10.0'

def group_for(project, path)
  project.main_group.find_subpath(path, true).tap { |g| g.set_source_tree('<group>'); g.set_path(path) }
end

# Files already in the project (the widgets' folder), by path
def existing_ref(project, path)
  project.files.find { |f| f.real_path.to_s == File.join(ROOT, 'ios', path) }
end

watch_group = group_for(project, 'MomentumWatch')
watch_widgets_group = group_for(project, 'MomentumWatchWidgets')

# Settings both watch targets share: the version from Flutter
# (Watch.xcconfig), watchOS 10, the paid team, entitlements by setting so
# tool/install_on_iphone.sh can sign without them on a free team
xcconfig = watch_group.new_reference('Watch.xcconfig')

def configure(target, xcconfig, settings)
  # The Runner's three configurations: Debug, Release and Profile
  release = target.build_configurations.find { |c| c.name == 'Release' }
  unless target.build_configurations.any? { |c| c.name == 'Profile' }
    profile = target.project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
    profile.name = 'Profile'
    profile.build_settings = release.build_settings.dup
    target.build_configuration_list.build_configurations << profile
  end
  target.build_configurations.each do |config|
    config.base_configuration_reference = xcconfig
    config.build_settings.merge!(settings)
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['DEVELOPMENT_TEAM'] = TEAM
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings['WATCHOS_DEPLOYMENT_TARGET'] = WATCH_OS
    config.build_settings['SDKROOT'] = 'watchos'
    # Built for watchOS even as the iPhone app's dependency
    config.build_settings['SUPPORTED_PLATFORMS'] = 'watchos watchsimulator'
    config.build_settings['TARGETED_DEVICE_FAMILY'] = '4'
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
    config.build_settings['CURRENT_PROJECT_VERSION'] = '$(FLUTTER_BUILD_NUMBER)'
    config.build_settings['MARKETING_VERSION'] = '$(FLUTTER_BUILD_NAME)'
    config.build_settings.delete('IPHONEOS_DEPLOYMENT_TARGET')
    config.build_settings.delete('ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME')
    if config.name == 'Debug'
      config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG $(inherited)'
      config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
    else
      config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-O'
      config.build_settings['SWIFT_COMPILATION_MODE'] = 'wholemodule'
    end
  end
end

# The watch app: a single-target watchOS app
watch = project.new_target(:application, 'MomentumWatch', :watchos, WATCH_OS)
configure(watch, xcconfig,
          'PRODUCT_BUNDLE_IDENTIFIER' => 'com.paulblake.momentum.watchkitapp',
          'PRODUCT_NAME' => 'MomentumWatch',
          'INFOPLIST_FILE' => 'MomentumWatch/Info.plist',
          'CODE_SIGN_ENTITLEMENTS' => '$(WATCH_ENTITLEMENTS)',
          'WATCH_ENTITLEMENTS' => 'MomentumWatch/MomentumWatch.entitlements',
          'ASSETCATALOG_COMPILER_APPICON_NAME' => 'AppIcon',
          'SKIP_INSTALL' => 'YES',
          'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks')
%w[MomentumWatchApp.swift WatchModel.swift TodayView.swift HabitView.swift MomentumPage.swift].each do |name|
  watch.source_build_phase.add_file_reference(watch_group.new_reference(name))
end
watch.resources_build_phase.add_file_reference(watch_group.new_reference('Assets.xcassets'))
%w[Info.plist MomentumWatch.entitlements].each { |name| watch_group.new_reference(name) }

# The complications: a WidgetKit extension inside the watch app
complications = project.new_target(:app_extension, 'MomentumWatchWidgets', :watchos, WATCH_OS)
configure(complications, xcconfig,
          'PRODUCT_BUNDLE_IDENTIFIER' => 'com.paulblake.momentum.watchkitapp.widgets',
          'PRODUCT_NAME' => 'MomentumWatchWidgets',
          'INFOPLIST_FILE' => 'MomentumWatchWidgets/Info.plist',
          'CODE_SIGN_ENTITLEMENTS' => '$(WATCH_WIDGETS_ENTITLEMENTS)',
          'WATCH_WIDGETS_ENTITLEMENTS' => 'MomentumWatchWidgets/MomentumWatchWidgets.entitlements',
          'SKIP_INSTALL' => 'YES',
          'APPLICATION_EXTENSION_API_ONLY' => 'YES',
          'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks')
complications.source_build_phase.add_file_reference(watch_widgets_group.new_reference('WatchComplications.swift'))
%w[Info.plist MomentumWatchWidgets.entitlements].each { |name| watch_widgets_group.new_reference(name) }

# Shared with the iPhone's widgets: the snapshot, the App Group store, the
# drawing pieces and the habit entity; the app also bundles Sora
shared = {
  'MomentumWidgets/Snapshot.swift' => [watch, complications],
  'MomentumWidgets/Shared/WidgetStore.swift' => [watch, complications],
  'MomentumWidgets/Pieces.swift' => [watch, complications],
  'MomentumWidgets/Shared/HabitEntity.swift' => [complications],
}
shared.each do |path, targets|
  ref = existing_ref(project, path) or abort("Not in the project: #{path}")
  targets.each { |t| t.source_build_phase.add_file_reference(ref) }
end
%w[MomentumWidgets/Sora-SemiBold.ttf MomentumWidgets/Sora-Bold.ttf].each do |path|
  ref = existing_ref(project, path) or abort("Not in the project: #{path}")
  watch.resources_build_phase.add_file_reference(ref)
end
plist = File.join(ROOT, 'ios/MomentumWatch/Info.plist')
unless File.read(plist).include?('UIAppFonts')
  File.write(plist, File.read(plist).sub("</dict>\n</plist>",
    "\t<key>UIAppFonts</key>\n\t<array>\n\t\t<string>Sora-SemiBold.ttf</string>\n\t\t<string>Sora-Bold.ttf</string>\n\t</array>\n</dict>\n</plist>"))
end

# The phone's side of the link (Runner)
runner_group = project.main_group.find_subpath('Runner', false)
runner.source_build_phase.add_file_reference(runner_group.new_reference('WatchLink.swift'))

# The complications go inside the watch app ...
watch.add_dependency(complications)
embed_extensions = watch.new_copy_files_build_phase('Embed Foundation Extensions')
embed_extensions.symbol_dst_subfolder_spec = :plug_ins
embed_extensions.add_file_reference(complications.product_reference).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# ... and the watch app inside the iPhone app, before Flutter's Thin Binary
# (as the widgets' embed is)
runner.add_dependency(watch)
embed_watch = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed_watch.name = 'Embed Watch Content'
embed_watch.dst_subfolder_spec = '16'
embed_watch.dst_path = '$(CONTENTS_FOLDER_PATH)/Watch'
embed_watch.add_file_reference(watch.product_reference).settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }
thin = runner.build_phases.index { |p| p.respond_to?(:name) && p.name == 'Thin Binary' }
runner.build_phases.insert(thin, embed_watch)

attributes = project.root_object.attributes['TargetAttributes'] ||= {}
[watch, complications].each do |t|
  attributes[t.uuid] = { 'CreatedOnToolsVersion' => '27.1', 'DevelopmentTeam' => TEAM }
end

project.save
puts "Added MomentumWatch and MomentumWatchWidgets (#{widgets ? 'beside' : 'without'} MomentumWidgets)."
