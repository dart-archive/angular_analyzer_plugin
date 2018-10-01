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
echo 'angular_analyzer_plugin:angular_analyzer_plugin/lib' >> .packages
echo done
echo

echo Updating new plugin architecture .packages file
echo Adding self hosting plugin architecture .packages file
cd angular_analyzer_plugin/tools/analyzer_plugin
pub get
cd ../../..
echo done
echo

