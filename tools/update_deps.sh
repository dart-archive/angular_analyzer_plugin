echo Updating pub deps
cd deps
pub get
echo done
echo

echo Updating the sdk with depot_tools
gclient sync
echo done
echo

cd ..

echo Copying and transforming sdk .packages to be useful to this repo
cat deps/sdk/.packages | grep -v '^typed_mock' | grep -v '^unittest' | grep -v '^test_reflective_loader' | sed 's/:/:deps\/sdk\//' > .packages
echo done
echo

echo Copying pub .packages to be useful to this repo
cat deps/.packages | grep '# Generated' >> .packages
cat deps/.packages | grep 'angular_ast' >> .packages
cat deps/.packages | grep 'test_reflective_loader' >> .packages
cat deps/.packages | grep 'typed_mock' >> .packages
cat deps/.packages | grep 'unittest' >> .packages
cat deps/.packages | grep 'non_sdk_deps' >> .packages
echo done
echo

echo Adding analyzer plugin to .packages
echo 'angular_analyzer_plugin:analyzer_plugin/lib' >> .packages
echo done
echo

echo Adding server plugin to .packages
echo 'angular_analyzer_server_plugin:server_plugin/lib' >> .packages
echo done
echo

echo Adding new plugin to .packages
echo 'angular_analysis_plugin:new_plugin/lib' >> .packages
echo done
echo

echo Updating new plugin architecture .packages file
cd analyze_angular/tools/analyzer_plugin
pub get
cd ../../..
echo done
echo

