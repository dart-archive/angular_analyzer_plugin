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
cat deps/sdk/.packages | grep -v '^test' | grep -v '^typed_mock' | grep -v '^unittest' | sed 's/:/:deps\/sdk\//' > .packages
echo done
echo

echo Copying pub .packages to be useful to this repo
cat deps/.packages | grep '# Generated' >> .packages
cat deps/.packages | grep 'angular_ast' >> .packages
cat deps/.packages | grep 'quiver_hashcode' >> .packages
cat deps/.packages | grep 'test_reflective_loader' >> .packages
cat deps/.packages | grep 'tuple' >> .packages
cat deps/.packages | grep 'typed_mock' >> .packages
cat deps/.packages | grep 'unittest' >> .packages
cat deps/.packages | grep 'non_sdk_deps' >> .packages
echo done
echo

echo Adding analyzer plugin to .packages
echo 'angular_analyzer_plugin:analyzer_plugin/lib' >> .packages
echo done
echo

echo Adding server to .packages
echo 'angular_analyzer_server_plugin:server_plugin/lib' >> .packages
echo done
echo
