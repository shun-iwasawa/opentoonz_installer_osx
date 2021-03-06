#!/usr/bin/env ruby
# -*- coding: utf-8 -*-
require 'FileUtils'
if ARGV.size != 5 then
  puts "usage: ./app.rb [SRC_BUNDLE_PATH] [STUFF_DIR] [VERSION(float)] [MACDEPLOYQT_PATH] [DELETE_RPATH]"
  exit 1
end

def exec_with_assert(cmd)
    result = `#{cmd}`
    if $? != 0 then
        puts "Execution '#{cmd}' failed."
        exit 1
    end
    puts "Execution '#{cmd}' succeed."
end

# 定数群
SRC_BUNDLE_PATH = ARGV[0][-1] == "/" ? ARGV[0][0, ARGV[0].size-1] : ARGV[0]
VERSION = ARGV[2]
MACDEPLOYQT_PATH = ARGV[3]
DELETE_RPATH = ARGV[4]
VIRTUAL_ROOT = "VirtualRoot"
INSTALL_BUNDLE = "OpenToonz.app"
APP = "Applications"
THIS_DIRECTORY = File.dirname(__FILE__)

PKG_ID = "io.github.opentoonz"
PKG_TMP = "OpenToonzBuild.pkg"
FINAL_PKG = "OpenToonz.pkg"

# カレントへバンドルをコピー
exec_with_assert "cp -r #{SRC_BUNDLE_PATH} #{INSTALL_BUNDLE}"
# deployqt を適用
exec_with_assert "#{MACDEPLOYQT_PATH} #{INSTALL_BUNDLE}"

# VirtualRoot への設置
# 既存を削除して設置
if File.exist? VIRTUAL_ROOT then
    exec_with_assert "rm -rf #{VIRTUAL_ROOT}"
end
exec_with_assert "mkdir -p #{VIRTUAL_ROOT}/#{APP}"
exec_with_assert "mv #{INSTALL_BUNDLE} #{VIRTUAL_ROOT}/#{APP}"

# LC_RPATH から自分の名前を削除
# 削除する RPATH を指定
DELETE_RPATH_TARGET = "#{VIRTUAL_ROOT}/#{APP}/#{INSTALL_BUNDLE}/Contents/MacOS/OpenToonz"
exec_with_assert "install_name_tool -delete_rpath #{DELETE_RPATH} #{DELETE_RPATH_TARGET}"

# Modify OpenCV library paths
puts "Modify OpenCV library paths"
TMP = `for CVLIB in \`find #{VIRTUAL_ROOT}/#{APP}/#{INSTALL_BUNDLE}/Contents -type f -name *.dylib | grep "opencv"\`\n\
do\n\
echo $CVLIB\n\
for FROMPATH in \`otool -L $CVLIB | grep "@rpath/libopencv" | sed -e"s/ (.*$//"\`\n\
  do\n\
     echo $FROMPATH\n\
     LIBNAME=\`basename $FROMPATH\`\n\
     echo "Correcting library path of $LIBNAME in $CVLIB"\n\
     install_name_tool -change $FROMPATH @executable_path/../Frameworks/$LIBNAME $CVLIB\n\
  done\n\
  for RPATH in \`otool -l $CVLIB | grep "/usr/local/Cellar" | sed -e"s/path//" -e"s/ (.*$//"\`\n\
  do\n\
    echo "Deleting rpath $RPATH in $CVLIB"\n\
    install_name_tool -delete_rpath $RPATH $CVLIB\n\
  done\n\
done`
puts "#{TMP}"

# plist が存在しない場合は生成し、必要な変更を適用
PKG_PLIST = "app.plist"
unless File.exist? PKG_PLIST then
    exec_with_assert "pkgbuild --root #{VIRTUAL_ROOT} --analyze #{PKG_PLIST}"
    exec_with_assert "gsed -i -e \"14i <key>BundlePostInstallScriptPath</key>\" #{PKG_PLIST}"
    exec_with_assert "gsed -i -e \"15i <string>pkg-script.sh</string>\" #{PKG_PLIST}"
end

# stuff の準備
unless File.exists? "scripts"
    exec_with_assert "cp -r #{THIS_DIRECTORY}/scripts ."
end

# ライセンス
unless File.exists? "Japanese.lproj"
    FileUtils.cp_r("#{THIS_DIRECTORY}/Japanese.lproj", ".")
end
unless File.exists? "English.lproj"
    FileUtils.cp_r("#{THIS_DIRECTORY}/English.lproj", ".")
end

# 既存のものを削除し tar で固めて scripts に設置
if File.exist? "scripts/stuff.tar.bz2" then
    exec_with_assert "rm scripts/*.tar.bz2"
end
exec_with_assert "cp -r #{ARGV[1]} stuff"
exec_with_assert "tar cjvf stuff.tar.bz2 stuff"
exec_with_assert "mv stuff.tar.bz2 scripts"

# plist を用いた pkg の生成
exec_with_assert "pkgbuild --root #{VIRTUAL_ROOT} --component-plist #{PKG_PLIST} --scripts scripts --identifier #{PKG_ID} --version #{VERSION} #{PKG_TMP}"

# distribution.xml が存在しない場合は生成
DIST_XML = "distribution.xml"
unless File.exists? DIST_XML then
    exec_with_assert "productbuild --synthesize --package #{PKG_TMP} #{DIST_XML}"
    exec_with_assert "gsed -i -e \"3i <title>OpenToonz</title>\" #{DIST_XML}"
    exec_with_assert "gsed -i -e \"6i <license file='License.rtf'></license>\" #{DIST_XML}"
end

# 最終的な pkg を生成
exec_with_assert "productbuild --distribution #{DIST_XML} --package-path #{PKG_TMP} --resources . #{FINAL_PKG}"

# 一時的な生成物を削除
`rm #{PKG_TMP}`
`rm -rf stuff`
`rm app.plist`
